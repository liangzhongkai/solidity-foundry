// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {SecurityPatterns} from "../../../src/10-design-patterns/security/SecurityPatterns.sol";

contract SecurityPatternsTest is Test {
    SecurityPatterns internal sec;
    address internal owner = address(0x1);
    address internal guardian = address(0xBEEF);
    address internal recipient = address(0xCAFE);
    address payable internal sweepTarget = payable(address(0x2));

    function setUp() public {
        SecurityPatterns.Config memory cfg = SecurityPatterns.Config({
            balanceCap: uint96(100 ether),
            epochLimit: uint96(10 ether),
            epochDuration: uint64(1 hours),
            withdrawalDelay: uint64(1 days),
            terminateDelay: uint64(2 days),
            deprecationTime: uint64(block.timestamp + 30 days)
        });

        vm.prank(owner);
        sec = new SecurityPatterns(guardian, cfg);

        vm.deal(owner, 25 ether);
        vm.deal(guardian, 10 ether);
        vm.deal(recipient, 10 ether);
    }

    function test_ForkCheck() public view {
        assertEq(sec.deploymentChainId(), block.chainid);
    }

    function test_SumArray() public view {
        uint256[] memory data = new uint256[](3);
        data[0] = 10;
        data[1] = 20;
        data[2] = 30;
        assertEq(sec.sumArray(data), 60);
    }

    function test_DepositAndQueueWithdraw() public {
        vm.prank(owner);
        sec.deposit{value: 5 ether}();

        vm.prank(guardian);
        sec.queueWithdrawal(recipient, 2 ether);

        vm.warp(block.timestamp + 1 days);
        uint256 recipientBefore = recipient.balance;
        vm.prank(recipient);
        sec.withdraw();

        assertEq(recipient.balance, recipientBefore + 2 ether);
        assertEq(sec.totalLiabilities(), 0);
    }

    function test_QueueRateLimit() public {
        vm.prank(owner);
        sec.deposit{value: 20 ether}();

        vm.prank(guardian);
        sec.queueWithdrawal(recipient, 6 ether);

        vm.expectRevert(abi.encodeWithSelector(SecurityPatterns.EpochLimitExceeded.selector, 5 ether, 4 ether));
        vm.prank(guardian);
        sec.queueWithdrawal(sweepTarget, 5 ether);
    }

    function test_DepositPaused() public {
        vm.prank(guardian);
        sec.setPauseFlags(1);

        vm.expectRevert(SecurityPatterns.Paused.selector);
        vm.prank(owner);
        sec.deposit{value: 1 ether}();
    }

    function test_QueuePaused() public {
        vm.prank(owner);
        sec.deposit{value: 5 ether}();

        vm.prank(guardian);
        sec.setPauseFlags(2);

        vm.expectRevert(SecurityPatterns.Paused.selector);
        vm.prank(owner);
        sec.queueWithdrawal(recipient, 1 ether);
    }

    function test_TerminateUnauthorized() public {
        vm.expectRevert(SecurityPatterns.Unauthorized.selector);
        sec.scheduleTermination();
    }

    function test_TerminateAndSweep() public {
        vm.prank(owner);
        sec.deposit{value: 5 ether}();

        vm.prank(guardian);
        sec.setPauseFlags(3);

        vm.prank(owner);
        sec.scheduleTermination();

        vm.warp(block.timestamp + 2 days);
        vm.prank(owner);
        sec.terminateAndSweep(sweepTarget, 5 ether);

        assertTrue(sec.isTerminated());
        assertEq(sweepTarget.balance, 5 ether);
    }

    function test_TerminateWithOutstandingLiabilitiesReverts() public {
        vm.prank(owner);
        sec.deposit{value: 5 ether}();

        vm.prank(owner);
        sec.queueWithdrawal(recipient, 1 ether);

        vm.prank(guardian);
        sec.setPauseFlags(3);

        vm.prank(owner);
        sec.scheduleTermination();

        vm.warp(block.timestamp + 2 days);
        vm.expectRevert(abi.encodeWithSelector(SecurityPatterns.OutstandingLiabilities.selector, 1 ether));
        vm.prank(owner);
        sec.terminateAndSweep(sweepTarget, 4 ether);
    }

    function test_FunctionFailsAfterTermination() public {
        vm.prank(owner);
        sec.deposit{value: 1 ether}();

        vm.prank(guardian);
        sec.setPauseFlags(3);

        vm.prank(owner);
        sec.scheduleTermination();

        vm.warp(block.timestamp + 2 days);
        vm.prank(owner);
        sec.terminateAndSweep(sweepTarget, 1 ether);

        uint256[] memory data = new uint256[](1);
        vm.expectRevert(SecurityPatterns.Terminated.selector);
        sec.sumArray(data);
    }

    function test_WithdrawRequiresDelay() public {
        vm.prank(owner);
        sec.deposit{value: 5 ether}();

        vm.prank(owner);
        sec.queueWithdrawal(recipient, 1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                SecurityPatterns.WithdrawalNotReady.selector, block.timestamp, block.timestamp + 1 days
            )
        );
        vm.prank(recipient);
        sec.withdraw();
    }
}
