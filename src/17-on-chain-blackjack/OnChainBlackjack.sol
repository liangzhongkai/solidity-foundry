// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title OnChainBlackjack
/// @notice On-chain blackjack with open hands. All hands visible; RNG with correct card probabilities;
///         dealer hits until 17; anyone can call dealerNextMove(); players must act within 10 blocks.
/// @dev Uses blockhash for randomness; suitable for demos only.
contract OnChainBlackjack {
    uint256 public constant MOVE_TIMEOUT_BLOCKS = 10;
    uint256 public constant DEALER_STAND = 17;

    enum Phase {
        WaitingForPlayers,
        PlayerTurns,
        DealerTurn,
        Finished
    }

    struct Game {
        Phase phase;
        uint8[] dealerHand;
        address[] players;
        mapping(address => uint8[]) playerHands;
        mapping(address => bool) hasStood;
        mapping(address => bool) hasBusted;
        uint256 currentPlayerIndex;
        uint64 blockAtTurnStart;
        uint256 drawNonce;
    }

    uint256 public gameCount;
    mapping(uint256 gameId => Game) internal games;

    event GameCreated(uint256 indexed gameId);
    event PlayerJoined(uint256 indexed gameId, address indexed player);
    event GameStarted(uint256 indexed gameId);
    event CardDealt(uint256 indexed gameId, address indexed recipient, uint8 card, bool isDealer);
    event PlayerHit(uint256 indexed gameId, address indexed player, uint8 card);
    event PlayerStood(uint256 indexed gameId, address indexed player);
    event PlayerTimedOut(uint256 indexed gameId, address indexed player);
    event DealerHit(uint256 indexed gameId, uint8 card);
    event DealerStood(uint256 indexed gameId, uint256 total);
    event GameFinished(uint256 indexed gameId);

    error GameNotFound();
    error GameNotWaiting();
    error GameNotStarted();
    error GameNotPlayerTurn();
    error GameNotDealerTurn();
    error GameAlreadyFinished();
    error AlreadyJoined();
    error NoPlayers();
    error NotInGame();
    error PlayerAlreadyActed();
    error NotTimedOut();
    error MoveTimedOut();

    /// @notice Create a new blackjack game.
    /// @return gameId The new game id.
    function createGame() external returns (uint256 gameId) {
        gameId = ++gameCount;
        Game storage g = games[gameId];
        g.phase = Phase.WaitingForPlayers;
        emit GameCreated(gameId);
    }

    /// @notice Join a game. Must be in WaitingForPlayers phase.
    /// @param gameId The game to join.
    function joinGame(uint256 gameId) external {
        Game storage g = _getGame(gameId);
        if (g.phase == Phase.Finished) revert GameAlreadyFinished();
        if (g.phase != Phase.WaitingForPlayers) revert GameNotWaiting();
        if (_hasJoined(g, msg.sender)) revert AlreadyJoined();

        g.players.push(msg.sender);
        emit PlayerJoined(gameId, msg.sender);
    }

    /// @notice Start the game: deal 2 cards to each player and 2 to dealer.
    /// @param gameId The game to start.
    function startGame(uint256 gameId) external {
        Game storage g = _getGame(gameId);
        if (g.phase == Phase.Finished) revert GameAlreadyFinished();
        if (g.phase != Phase.WaitingForPlayers) revert GameNotWaiting();
        if (g.players.length == 0) revert NoPlayers();

        g.phase = Phase.PlayerTurns;
        g.currentPlayerIndex = 0;
        g.blockAtTurnStart = uint64(block.number);

        for (uint256 i = 0; i < g.players.length; i++) {
            _dealCard(g, gameId, g.players[i], false);
            _dealCard(g, gameId, g.players[i], false);
        }
        _dealCard(g, gameId, address(0), true);
        _dealCard(g, gameId, address(0), true);

        emit GameStarted(gameId);
    }

    /// @notice Player hits (draws a card).
    /// @param gameId The game.
    function hit(uint256 gameId) external {
        Game storage g = _getGame(gameId);
        if (g.phase == Phase.Finished) revert GameAlreadyFinished();
        if (g.phase != Phase.PlayerTurns) revert GameNotStarted();
        address player = g.players[g.currentPlayerIndex];
        if (msg.sender != player) revert GameNotPlayerTurn();
        if (g.hasStood[player] || g.hasBusted[player]) revert PlayerAlreadyActed();
        if (block.number > g.blockAtTurnStart + MOVE_TIMEOUT_BLOCKS) revert MoveTimedOut();

        uint8 card = _drawCard(g, gameId);
        g.playerHands[player].push(card);
        emit PlayerHit(gameId, player, card);

        if (_handValue(g.playerHands[player]) > 21) {
            g.hasBusted[player] = true;
        }
        _advancePlayerTurn(g, gameId);
    }

    /// @notice Player stands (ends their turn).
    /// @param gameId The game.
    function stand(uint256 gameId) external {
        Game storage g = _getGame(gameId);
        if (g.phase == Phase.Finished) revert GameAlreadyFinished();
        if (g.phase != Phase.PlayerTurns) revert GameNotStarted();
        address player = g.players[g.currentPlayerIndex];
        if (msg.sender != player) revert GameNotPlayerTurn();
        if (g.hasStood[player] || g.hasBusted[player]) revert PlayerAlreadyActed();
        if (block.number > g.blockAtTurnStart + MOVE_TIMEOUT_BLOCKS) revert MoveTimedOut();

        g.hasStood[player] = true;
        emit PlayerStood(gameId, player);
        _advancePlayerTurn(g, gameId);
    }

    /// @notice Advance when current player has timed out (10 blocks). Anyone can call.
    /// @param gameId The game.
    function advanceOnTimeout(uint256 gameId) external {
        Game storage g = _getGame(gameId);
        if (g.phase == Phase.Finished) revert GameAlreadyFinished();
        if (g.phase != Phase.PlayerTurns) revert GameNotStarted();
        address player = g.players[g.currentPlayerIndex];
        if (block.number <= g.blockAtTurnStart + MOVE_TIMEOUT_BLOCKS) revert NotTimedOut();

        g.hasStood[player] = true;
        emit PlayerTimedOut(gameId, player);
        _advancePlayerTurn(g, gameId);
    }

    /// @notice Advance dealer's turn. Anyone can call when it's dealer's turn.
    /// @param gameId The game.
    function dealerNextMove(uint256 gameId) external {
        Game storage g = _getGame(gameId);
        if (g.phase == Phase.Finished) revert GameAlreadyFinished();
        if (g.phase != Phase.DealerTurn) revert GameNotDealerTurn();

        uint256 total = _handValue(g.dealerHand);
        if (total >= DEALER_STAND) {
            g.phase = Phase.Finished;
            emit DealerStood(gameId, total);
            emit GameFinished(gameId);
            return;
        }

        uint8 card = _drawCard(g, gameId);
        g.dealerHand.push(card);
        emit DealerHit(gameId, card);

        if (_handValue(g.dealerHand) > 21) {
            g.phase = Phase.Finished;
            emit GameFinished(gameId);
        }
    }

    /// @notice Get dealer's hand.
    function getDealerHand(uint256 gameId) external view returns (uint8[] memory) {
        return games[gameId].dealerHand;
    }

    /// @notice Get a player's hand.
    function getPlayerHand(uint256 gameId, address player) external view returns (uint8[] memory) {
        return games[gameId].playerHands[player];
    }

    /// @notice Get hand value (best value for Aces).
    function getHandValue(uint8[] memory hand) external pure returns (uint256) {
        return _handValuePure(hand);
    }

    /// @notice Get game phase and current player.
    function getGameState(uint256 gameId)
        external
        view
        returns (Phase phase, uint256 currentPlayerIndex, address currentPlayer, uint64 blockAtTurnStart)
    {
        Game storage g = games[gameId];
        if (g.players.length == 0 && g.phase == Phase.WaitingForPlayers) {
            return (g.phase, 0, address(0), 0);
        }
        address cp = g.currentPlayerIndex < g.players.length ? g.players[g.currentPlayerIndex] : address(0);
        return (g.phase, g.currentPlayerIndex, cp, g.blockAtTurnStart);
    }

    /// @notice Get players in a game.
    function getPlayers(uint256 gameId) external view returns (address[] memory) {
        return games[gameId].players;
    }

    function _getGame(uint256 gameId) internal view returns (Game storage) {
        if (gameId == 0 || gameId > gameCount) revert GameNotFound();
        return games[gameId];
    }

    function _hasJoined(Game storage g, address player) internal view returns (bool) {
        for (uint256 i = 0; i < g.players.length; i++) {
            if (g.players[i] == player) return true;
        }
        return false;
    }

    function _dealCard(Game storage g, uint256 gameId, address player, bool isDealer) internal {
        uint8 card = _drawCard(g, gameId);
        if (isDealer) {
            g.dealerHand.push(card);
            emit CardDealt(gameId, address(0), card, true);
        } else {
            g.playerHands[player].push(card);
            emit CardDealt(gameId, player, card, false);
        }
    }

    /// @dev Draw a card with correct probabilities: 2-9 each 1/13, 10 (J/Q/K) 4/13, Ace 1/13.
    function _drawCard(Game storage g, uint256 gameId) internal returns (uint8) {
        bytes32 h = blockhash(block.number > 0 ? block.number - 1 : block.number);
        // slither-disable-next-line weak-prng -- blockhash-based RNG; documented as demo only; use Chainlink VRF for production
        uint256 r = uint256(keccak256(abi.encodePacked(h, gameId, block.number, g.drawNonce++))) % 13;
        if (r < 8) return uint8(r + 2); // 2-9
        if (r < 12) return 10; // 10, J, Q, K
        return 1; // Ace
    }

    function _handValue(uint8[] storage hand) internal view returns (uint256) {
        uint256 sum = 0;
        uint256 aces = 0;
        for (uint256 i = 0; i < hand.length; i++) {
            if (hand[i] == 1) {
                aces++;
            } else {
                sum += hand[i];
            }
        }
        for (uint256 j = 0; j < aces; j++) {
            if (sum + 11 <= 21) {
                sum += 11;
            } else {
                sum += 1;
            }
        }
        return sum;
    }

    function _handValuePure(uint8[] memory hand) internal pure returns (uint256) {
        uint256 sum = 0;
        uint256 aces = 0;
        for (uint256 i = 0; i < hand.length; i++) {
            if (hand[i] == 1) {
                aces++;
            } else {
                sum += hand[i];
            }
        }
        for (uint256 j = 0; j < aces; j++) {
            if (sum + 11 <= 21) {
                sum += 11;
            } else {
                sum += 1;
            }
        }
        return sum;
    }

    function _advancePlayerTurn(Game storage g, uint256 gameId) internal {
        if (g.hasStood[g.players[g.currentPlayerIndex]] || g.hasBusted[g.players[g.currentPlayerIndex]]) {
            g.currentPlayerIndex++;
            g.blockAtTurnStart = uint64(block.number);
        }

        while (g.currentPlayerIndex < g.players.length) {
            address p = g.players[g.currentPlayerIndex];
            if (!g.hasStood[p] && !g.hasBusted[p]) break;
            g.currentPlayerIndex++;
            g.blockAtTurnStart = uint64(block.number);
        }

        if (g.currentPlayerIndex >= g.players.length) {
            g.phase = Phase.DealerTurn;
        }
    }
}
