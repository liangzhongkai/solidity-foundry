// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {IncentiveExecution} from "../../../src/10-design-patterns/efficiency/IncentiveExecution.sol";

contract IncentiveExecutionTest is Test {
    IncentiveExecution internal incentiveExecution;
    address internal executor = address(0x1);

    function setUp() public {
        incentiveExecution = new IncentiveExecution{value: 1 ether}();
    }

    function test_ExecuteMaintenance() public {
        vm.warp(block.timestamp + 1 days);

        uint256 executorBalBefore = executor.balance;
        vm.prank(executor);
        incentiveExecution.executeMaintenance();

        assertEq(executor.balance, executorBalBefore + 0.01 ether);
    }

    function test_ExecuteMaintenanceTooEarlyReverts() public {
        vm.expectRevert(IncentiveExecution.TooEarly.selector);
        vm.prank(executor);
        incentiveExecution.executeMaintenance();
    }
}
