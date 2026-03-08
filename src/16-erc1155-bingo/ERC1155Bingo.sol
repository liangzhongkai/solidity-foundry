// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC1155} from "openzeppelin-contracts@5.4.0/token/ERC1155/ERC1155.sol";

/// @title ERC1155Bingo
/// @notice Bingo game using ERC1155 tokens (1-25) as card values. Each player has a 5x5 grid;
///         every n blocks a number is drawn; first 5-in-row wins.
/// @dev Uses blockhash for randomness; suitable for demos only.
contract ERC1155Bingo is ERC1155 {
    uint256 public constant MIN_CARD = 1;
    uint256 public constant MAX_CARD = 25;
    uint256 public constant GRID_SIZE = 5;

    struct Game {
        uint256 blocksBetweenDraws;
        uint64 blockAtLastDraw;
        uint256 drawnBitmap;
        address[] players;
        address winner;
        bool finished;
    }

    uint256 public gameCount;
    mapping(uint256 gameId => Game) public games;
    mapping(uint256 gameId => mapping(address player => uint8[25])) internal grids;
    mapping(uint256 gameId => mapping(address player => uint256)) internal markedBitmaps;
    mapping(uint256 gameId => mapping(address player => bool)) internal hasJoined;
    uint256 internal _joinNonce;

    event GameCreated(uint256 indexed gameId, uint256 blocksBetweenDraws);
    event PlayerJoined(uint256 indexed gameId, address indexed player, uint8[25] grid);
    event NumberDrawn(uint256 indexed gameId, uint8 number);
    event Bingo(uint256 indexed gameId, address indexed winner);

    error GameNotFound();
    error GameFinished();
    error AlreadyJoined();
    error NotEnoughBlocks();
    error AllNumbersDrawn();
    error NoPlayers();

    constructor() ERC1155("https://bingo.example/api/card/{id}.json") {}

    /// @notice Create a new bingo game.
    /// @param blocksBetweenDraws Number of blocks between each draw.
    /// @return gameId The new game id.
    function createGame(uint256 blocksBetweenDraws) external returns (uint256 gameId) {
        gameId = ++gameCount;
        games[gameId] = Game({
            blocksBetweenDraws: blocksBetweenDraws,
            blockAtLastDraw: 0,
            drawnBitmap: 0,
            players: new address[](0),
            winner: address(0),
            finished: false
        });
        emit GameCreated(gameId, blocksBetweenDraws);
    }

    /// @notice Join a game. Receives a random 5x5 grid and ERC1155 tokens 1-25.
    /// @param gameId The game to join.
    function joinGame(uint256 gameId) external {
        Game storage game = _getGame(gameId);
        if (game.finished) revert GameFinished();
        if (hasJoined[gameId][msg.sender]) revert AlreadyJoined();

        uint8[25] memory grid = _generateGrid(gameId);
        grids[gameId][msg.sender] = grid;
        markedBitmaps[gameId][msg.sender] = 0;
        hasJoined[gameId][msg.sender] = true;
        game.players.push(msg.sender);

        uint256[] memory ids = new uint256[](25);
        uint256[] memory values = new uint256[](25);
        for (uint256 i = 0; i < 25; i++) {
            ids[i] = uint256(grid[i]);
            values[i] = 1;
        }
        _mintBatch(msg.sender, ids, values, "");

        emit PlayerJoined(gameId, msg.sender, grid);
    }

    /// @notice Trigger a draw. Callable every blocksBetweenDraws.
    /// @param gameId The game to draw for.
    function draw(uint256 gameId) external {
        Game storage game = _getGame(gameId);
        if (game.finished) revert GameFinished();
        if (game.players.length == 0) revert NoPlayers();

        uint256 n = game.blocksBetweenDraws;
        uint64 last = game.blockAtLastDraw;
        if (last != 0 && block.number < last + n) revert NotEnoughBlocks();
        if (game.drawnBitmap == _fullBitmap()) revert AllNumbersDrawn();

        uint8 num = _pickUndrawnNumber(game.drawnBitmap);
        game.drawnBitmap |= uint256(1) << (num - 1);
        game.blockAtLastDraw = uint64(block.number);

        for (uint256 i = 0; i < game.players.length; i++) {
            address p = game.players[i];
            _markIfPresent(gameId, p, num);
            if (game.winner == address(0) && _hasBingo(gameId, p)) {
                game.winner = p;
                game.finished = true;
                emit Bingo(gameId, p);
                break;
            }
        }

        emit NumberDrawn(gameId, num);
    }

    /// @notice Get a player's grid.
    function getGrid(uint256 gameId, address player) external view returns (uint8[25] memory) {
        return grids[gameId][player];
    }

    /// @notice Get a player's marked bitmap (bit i set = position i marked).
    function getMarkedBitmap(uint256 gameId, address player) external view returns (uint256) {
        return markedBitmaps[gameId][player];
    }

    function _getGame(uint256 gameId) internal view returns (Game storage) {
        Game storage game = games[gameId];
        if (game.blocksBetweenDraws == 0) revert GameNotFound();
        return game;
    }

    function _fullBitmap() internal pure returns (uint256) {
        return (uint256(1) << 25) - 1;
    }

    function _generateGrid(uint256 gameId) internal returns (uint8[25] memory) {
        uint8[25] memory arr;
        for (uint256 i = 0; i < 25; i++) {
            arr[i] = uint8(i + 1);
        }

        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number > 0 ? block.number - 1 : block.number),
                    gameId,
                    msg.sender,
                    block.number,
                    _joinNonce++
                )
            )
        );

        for (uint256 i = 24; i > 0; i--) {
            uint256 j = seed % (i + 1);
            seed = uint256(keccak256(abi.encodePacked(seed)));
            (arr[i], arr[j]) = (arr[j], arr[i]);
        }

        return arr;
    }

    function _pickUndrawnNumber(uint256 drawnBitmap) internal view returns (uint8) {
        uint8[25] memory undrawn;
        uint256 count;
        for (uint8 i = 1; i <= 25; i++) {
            if ((drawnBitmap & (uint256(1) << (i - 1))) == 0) {
                undrawn[count++] = i;
            }
        }
        if (count == 0) revert AllNumbersDrawn();
        bytes32 h = blockhash(block.number > 0 ? block.number - 1 : block.number);
        uint256 r = uint256(keccak256(abi.encodePacked(h, block.timestamp)));
        return undrawn[r % count];
    }

    function _markIfPresent(uint256 gameId, address player, uint8 num) internal {
        uint8[25] storage grid = grids[gameId][player];
        for (uint256 i = 0; i < 25; i++) {
            if (grid[i] == num) {
                markedBitmaps[gameId][player] |= uint256(1) << i;
                return;
            }
        }
    }

    function _hasBingo(uint256 gameId, address player) internal view returns (bool) {
        uint256 marked = markedBitmaps[gameId][player];
        for (uint256 r = 0; r < 5; r++) {
            uint256 rowMask = (uint256(31) << (r * 5));
            if ((marked & rowMask) == rowMask) return true;
        }
        for (uint256 c = 0; c < 5; c++) {
            uint256 colMask = (uint256(1) << c) | (uint256(1) << (c + 5)) | (uint256(1) << (c + 10))
                | (uint256(1) << (c + 15)) | (uint256(1) << (c + 20));
            if ((marked & colMask) == colMask) return true;
        }
        uint256 d1 = (1 << 0) | (1 << 6) | (1 << 12) | (1 << 18) | (1 << 24);
        if ((marked & d1) == d1) return true;
        uint256 d2 = (1 << 4) | (1 << 8) | (1 << 12) | (1 << 16) | (1 << 20);
        return (marked & d2) == d2;
    }
}
