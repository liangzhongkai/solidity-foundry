// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {OnChainBlackjack} from "../../src/17-on-chain-blackjack/OnChainBlackjack.sol";

contract OnChainBlackjackTest is Test {
    OnChainBlackjack internal bj;

    address internal alice = address(0xA1);
    address internal bob = address(0xB2);
    address internal carol = address(0xC3);

    function setUp() public {
        bj = new OnChainBlackjack();
    }

    function test_createGame() public {
        uint256 id = bj.createGame();
        assertEq(id, 1);
        assertEq(bj.gameCount(), 1);

        (OnChainBlackjack.Phase phase,,,) = bj.getGameState(1);
        assertEq(uint256(phase), uint256(OnChainBlackjack.Phase.WaitingForPlayers));
    }

    function test_joinGame() public {
        bj.createGame();
        vm.prank(alice);
        bj.joinGame(1);

        address[] memory players = bj.getPlayers(1);
        assertEq(players.length, 1);
        assertEq(players[0], alice);
    }

    function test_joinGame_alreadyJoined_reverts() public {
        bj.createGame();
        vm.startPrank(alice);
        bj.joinGame(1);
        vm.expectRevert(OnChainBlackjack.AlreadyJoined.selector);
        bj.joinGame(1);
    }

    function test_startGame_dealsCards() public {
        bj.createGame();
        vm.prank(alice);
        bj.joinGame(1);
        bj.startGame(1);

        uint8[] memory dealerHand = bj.getDealerHand(1);
        uint8[] memory aliceHand = bj.getPlayerHand(1, alice);

        assertEq(dealerHand.length, 2);
        assertEq(aliceHand.length, 2);

        (OnChainBlackjack.Phase phase, uint256 idx, address cp,) = bj.getGameState(1);
        assertEq(uint256(phase), uint256(OnChainBlackjack.Phase.PlayerTurns));
        assertEq(idx, 0);
        assertEq(cp, alice);
    }

    function test_startGame_noPlayers_reverts() public {
        bj.createGame();
        vm.expectRevert(OnChainBlackjack.NoPlayers.selector);
        bj.startGame(1);
    }

    function test_hit_and_stand() public {
        bj.createGame();
        vm.prank(alice);
        bj.joinGame(1);
        bj.startGame(1);

        vm.prank(alice);
        bj.stand(1);

        (OnChainBlackjack.Phase phase,,,) = bj.getGameState(1);
        assertEq(uint256(phase), uint256(OnChainBlackjack.Phase.DealerTurn));
    }

    function test_hit_addsCard() public {
        bj.createGame();
        vm.prank(alice);
        bj.joinGame(1);
        bj.startGame(1);

        uint8[] memory before = bj.getPlayerHand(1, alice);
        vm.prank(alice);
        bj.hit(1);
        uint8[] memory after_ = bj.getPlayerHand(1, alice);

        assertEq(after_.length, before.length + 1);
    }

    function test_dealerNextMove_hitsUntil17OrBust() public {
        bj.createGame();
        vm.prank(alice);
        bj.joinGame(1);
        bj.startGame(1);

        vm.prank(alice);
        bj.stand(1);

        while (true) {
            (OnChainBlackjack.Phase phase,,,) = bj.getGameState(1);
            if (phase == OnChainBlackjack.Phase.Finished) break;
            vm.roll(block.number + 1);
            bj.dealerNextMove(1);
        }

        uint8[] memory dealerHand = bj.getDealerHand(1);
        uint256 total = bj.getHandValue(dealerHand);
        assertTrue(total >= 17 || total > 21);
    }

    function test_dealerNextMove_anyoneCanCall() public {
        bj.createGame();
        vm.prank(alice);
        bj.joinGame(1);
        bj.startGame(1);
        vm.prank(alice);
        bj.stand(1);

        vm.prank(bob);
        bj.dealerNextMove(1);
    }

    function test_advanceOnTimeout_after10Blocks() public {
        bj.createGame();
        vm.prank(alice);
        bj.joinGame(1);
        bj.startGame(1);

        vm.roll(block.number + 11);

        vm.prank(bob);
        bj.advanceOnTimeout(1);

        (OnChainBlackjack.Phase phase,,,) = bj.getGameState(1);
        assertEq(uint256(phase), uint256(OnChainBlackjack.Phase.DealerTurn));
    }

    function test_advanceOnTimeout_before10Blocks_reverts() public {
        bj.createGame();
        vm.prank(alice);
        bj.joinGame(1);
        bj.startGame(1);

        vm.roll(block.number + 5);
        vm.prank(bob);
        vm.expectRevert(OnChainBlackjack.NotTimedOut.selector);
        bj.advanceOnTimeout(1);
    }

    function test_hit_afterTimeout_reverts() public {
        bj.createGame();
        vm.prank(alice);
        bj.joinGame(1);
        bj.startGame(1);

        vm.roll(block.number + 11);
        vm.prank(alice);
        vm.expectRevert(OnChainBlackjack.MoveTimedOut.selector);
        bj.hit(1);
    }

    function test_stand_afterTimeout_reverts() public {
        bj.createGame();
        vm.prank(alice);
        bj.joinGame(1);
        bj.startGame(1);

        vm.roll(block.number + 11);
        vm.prank(alice);
        vm.expectRevert(OnChainBlackjack.MoveTimedOut.selector);
        bj.stand(1);
    }

    function test_getHandValue_aceAs11() public {
        uint8[] memory hand = new uint8[](2);
        hand[0] = 1; // Ace
        hand[1] = 10; // 10
        assertEq(bj.getHandValue(hand), 21);
    }

    function test_getHandValue_aceAs1() public {
        uint8[] memory hand = new uint8[](3);
        hand[0] = 1; // Ace
        hand[1] = 10; // 10
        hand[2] = 10; // 10
        assertEq(bj.getHandValue(hand), 21);
    }

    function test_fullGame_flow() public {
        bj.createGame();
        vm.prank(alice);
        bj.joinGame(1);
        vm.prank(bob);
        bj.joinGame(1);

        bj.startGame(1);

        vm.prank(alice);
        bj.stand(1);

        vm.prank(bob);
        bj.stand(1);

        while (true) {
            (OnChainBlackjack.Phase phase,,,) = bj.getGameState(1);
            if (phase == OnChainBlackjack.Phase.Finished) break;
            vm.roll(block.number + 1);
            bj.dealerNextMove(1);
        }

        (OnChainBlackjack.Phase finalPhase,,,) = bj.getGameState(1);
        assertEq(uint256(finalPhase), uint256(OnChainBlackjack.Phase.Finished));
    }

    function test_gameNotFound_reverts() public {
        vm.expectRevert(OnChainBlackjack.GameNotFound.selector);
        bj.joinGame(999);
    }

    function test_hit_wrongPlayer_reverts() public {
        bj.createGame();
        vm.prank(alice);
        bj.joinGame(1);
        bj.startGame(1);

        vm.prank(bob);
        vm.expectRevert(OnChainBlackjack.GameNotPlayerTurn.selector);
        bj.hit(1);
    }
}
