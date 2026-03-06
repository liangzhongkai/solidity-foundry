// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {SecurityPatterns} from "../../../src/10-design-patterns/security/SecurityPatterns.sol";

contract SecurityPatternsFuzzTest is Test {
    uint256 internal constant BALANCE_CAP = 100 ether;
    uint256 internal constant EPOCH_LIMIT = 25 ether;

    SecurityPatterns internal sec;
    address internal owner = address(0x1);
    address internal guardian = address(0x2);
    address internal recipient = address(0x3);

    function setUp() public {
        SecurityPatterns.Config memory cfg = SecurityPatterns.Config({
            balanceCap: uint96(BALANCE_CAP),
            epochLimit: uint96(EPOCH_LIMIT),
            epochDuration: uint64(1 hours),
            withdrawalDelay: uint64(1 days),
            terminateDelay: uint64(2 days),
            deprecationTime: uint64(block.timestamp + 30 days)
        });

        vm.prank(owner);
        sec = new SecurityPatterns(guardian, cfg);
        vm.deal(owner, 200 ether);
    }

    function testFuzz_DepositRespectsBalanceCap(uint96 rawAmount) public {
        uint256 amount = bound(uint256(rawAmount), 1, 120 ether);

        vm.prank(owner);
        if (amount > BALANCE_CAP) {
            vm.expectRevert();
            sec.deposit{value: amount}();
            return;
        }

        sec.deposit{value: amount}();
        assertEq(address(sec).balance, amount);
    }

    function testFuzz_QueuedWithdrawalPreservesAccounting(uint96 rawDeposit, uint96 rawQueue) public {
        uint256 depositAmount = bound(uint256(rawDeposit), 1 ether, 50 ether);
        uint256 queueAmount = bound(uint256(rawQueue), 1, depositAmount);

        vm.prank(owner);
        sec.deposit{value: depositAmount}();

        vm.prank(guardian);
        if (queueAmount > EPOCH_LIMIT) {
            vm.expectRevert();
            sec.queueWithdrawal(recipient, queueAmount);
            return;
        }

        sec.queueWithdrawal(recipient, queueAmount);
        assertEq(sec.totalLiabilities(), queueAmount);
        assertEq(sec.pendingWithdrawals(recipient), queueAmount);

        vm.warp(block.timestamp + 1 days);
        vm.prank(recipient);
        sec.withdraw();

        assertEq(sec.totalLiabilities(), 0);
        assertEq(sec.pendingWithdrawals(recipient), 0);
        assertEq(address(sec).balance, depositAmount - queueAmount);
    }

    function testFuzz_DeprecatedBlocksNewQueue(uint32 rawWarp) public {
        uint256 warpBy = bound(uint256(rawWarp), 30 days, 45 days);

        vm.prank(owner);
        sec.deposit{value: 5 ether}();

        vm.warp(block.timestamp + warpBy);
        vm.expectRevert(SecurityPatterns.Deprecated.selector);
        vm.prank(guardian);
        sec.queueWithdrawal(recipient, 1 ether);
    }
}
