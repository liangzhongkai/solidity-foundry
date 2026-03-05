// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {SecurityPatterns} from "../../src/10-design-patterns/SecurityPatterns.sol";

contract SecurityPatternsTest is Test {
    SecurityPatterns internal sec;
    address internal owner = address(0x1);
    address payable internal sweepTarget = payable(address(0x2));

    function setUp() public {
        vm.prank(owner);
        sec = new SecurityPatterns();
        vm.deal(address(sec), 1 ether);
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

    function test_TerminateAndSweep() public {
        vm.prank(owner);
        sec.terminateAndSweep(sweepTarget);

        assertTrue(sec.isTerminated());
        assertEq(sweepTarget.balance, 1 ether);
        assertEq(address(sec).balance, 0);
    }

    function test_TerminateUnauthorized() public {
        vm.expectRevert(SecurityPatterns.Unauthorized.selector);
        sec.terminateAndSweep(sweepTarget);
    }

    function test_FunctionFailsAfterTermination() public {
        vm.prank(owner);
        sec.terminateAndSweep(sweepTarget);

        uint256[] memory data = new uint256[](1);
        vm.expectRevert(SecurityPatterns.Terminated.selector);
        sec.sumArray(data);
    }
}
