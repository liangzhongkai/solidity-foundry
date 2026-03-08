// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";

import {SimpleLottery} from "../../src/15-simple-lottery/SimpleLottery.sol";

contract SimpleLotteryTest is Test {
    SimpleLottery internal lottery;

    function _drawBlock(uint256 id) internal view returns (uint64) {
        (, uint64 drawBlock,,,) = lottery.lotteries(id);
        return drawBlock;
    }

    address internal alice = address(0xA1);
    address internal bob = address(0xB2);
    uint256 internal constant TICKET_PRICE = 0.01 ether;

    function setUp() public {
        lottery = new SimpleLottery();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_createLottery() public {
        uint256 id = lottery.createLottery();
        assertEq(id, 1);
        assertEq(lottery.lotteryCount(), 1);

        (uint64 purchaseDeadline, uint64 drawBlock, uint256 ticketCount,,) = lottery.lotteries(1);
        assertEq(purchaseDeadline, block.timestamp + 24 hours);
        assertEq(ticketCount, 0);
        assertEq(drawBlock, block.number + 7500);
    }

    function test_purchaseTicket() public {
        lottery.createLottery();

        vm.prank(alice);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);

        (,, uint256 ticketCount,,) = lottery.lotteries(1);
        assertEq(ticketCount, 1);
        assertEq(lottery.getParticipant(1, 0), alice);
        assertEq(address(lottery).balance, TICKET_PRICE);
    }

    function test_purchaseTicket_wrongPrice_reverts() public {
        lottery.createLottery();

        vm.prank(alice);
        vm.expectRevert(SimpleLottery.WrongTicketPrice.selector);
        lottery.purchaseTicket{value: 0.001 ether}(1);
    }

    function test_purchaseTicket_afterDeadline_reverts() public {
        lottery.createLottery();
        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(alice);
        vm.expectRevert(SimpleLottery.PurchaseWindowClosed.selector);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);
    }

    function test_claimWinnings() public {
        lottery.createLottery();
        vm.prank(alice);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);
        vm.prank(bob);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);

        uint64 drawBlock = _drawBlock(1);
        vm.roll(drawBlock + 1); // blockhash(drawBlock) available only after drawBlock

        // Winner is deterministic from blockhash; we need to find who wins
        bytes32 h = blockhash(drawBlock);
        uint256 winnerIndex = uint256(keccak256(abi.encodePacked(h))) % 2;
        address winner = winnerIndex == 0 ? alice : bob;
        uint256 winnerBalanceBefore = winner.balance;

        vm.prank(winner);
        lottery.claimWinnings(1);

        (,,, address winnerAddr, bool claimed) = lottery.lotteries(1);
        assertEq(claimed, true);
        assertEq(winnerAddr, winner);
        assertEq(winner.balance, winnerBalanceBefore + 2 * TICKET_PRICE); // got full pool
    }

    function test_claimWinnings_notWinner_reverts() public {
        lottery.createLottery();
        vm.prank(alice);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);
        vm.prank(bob);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);

        uint64 drawBlock = _drawBlock(1);
        vm.roll(drawBlock + 1);

        bytes32 h = blockhash(drawBlock);
        uint256 winnerIndex = uint256(keccak256(abi.encodePacked(h))) % 2;
        address loser = winnerIndex == 0 ? bob : alice;

        vm.prank(loser);
        vm.expectRevert(SimpleLottery.NotWinner.selector);
        lottery.claimWinnings(1);
    }

    function test_claimWinnings_beforeDrawBlock_reverts() public {
        lottery.createLottery();
        vm.prank(alice);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);

        uint64 drawBlock = _drawBlock(1);
        vm.roll(drawBlock); // at drawBlock, blockhash(drawBlock) still 0

        vm.prank(alice);
        vm.expectRevert(SimpleLottery.ClaimWindowNotOpen.selector);
        lottery.claimWinnings(1);
    }

    function test_claimWinnings_afterLookback_reverts() public {
        lottery.createLottery();
        vm.prank(alice);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);

        uint64 drawBlock = _drawBlock(1);
        vm.roll(drawBlock + 257); // past 256-block lookback

        vm.prank(alice);
        vm.expectRevert(SimpleLottery.ClaimWindowClosed.selector);
        lottery.claimWinnings(1);
    }

    function test_refund_afterLookback() public {
        lottery.createLottery();
        vm.prank(alice);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);
        vm.prank(bob);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);

        uint64 drawBlock = _drawBlock(1);
        vm.roll(drawBlock + 257);

        uint256 aliceBefore = alice.balance;
        uint256 bobBefore = bob.balance;

        vm.prank(alice);
        lottery.refund(1);
        vm.prank(bob);
        lottery.refund(1);

        assertEq(alice.balance, aliceBefore + TICKET_PRICE);
        assertEq(bob.balance, bobBefore + TICKET_PRICE);
    }

    function test_refund_beforeLookback_reverts() public {
        lottery.createLottery();
        vm.prank(alice);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);

        uint64 drawBlock = _drawBlock(1);
        vm.roll(drawBlock + 256);

        vm.prank(alice);
        vm.expectRevert(SimpleLottery.RefundWindowNotOpen.selector);
        lottery.refund(1);
    }

    function test_refund_afterWinnerClaimed_reverts() public {
        lottery.createLottery();
        vm.prank(alice);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);
        vm.prank(bob);
        lottery.purchaseTicket{value: TICKET_PRICE}(1);

        uint64 drawBlock = _drawBlock(1);
        vm.roll(drawBlock + 1);
        bytes32 h = blockhash(drawBlock);
        uint256 winnerIndex = uint256(keccak256(abi.encodePacked(h))) % 2;
        address winner = winnerIndex == 0 ? alice : bob;

        vm.prank(winner);
        lottery.claimWinnings(1);

        vm.roll(drawBlock + 257);
        vm.prank(alice);
        vm.expectRevert(SimpleLottery.RefundWindowNotOpen.selector);
        lottery.refund(1);
    }

    function test_refund_noTickets_reverts() public {
        lottery.createLottery();

        uint64 drawBlock = _drawBlock(1);
        vm.roll(drawBlock + 257);

        vm.prank(alice);
        vm.expectRevert(SimpleLottery.NothingToRefund.selector);
        lottery.refund(1);
    }

    function test_lotteryNotFound_reverts() public {
        vm.expectRevert(SimpleLottery.LotteryNotFound.selector);
        lottery.purchaseTicket{value: TICKET_PRICE}(999);
    }
}
