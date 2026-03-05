// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {AutoDeprecation} from "../../src/10-design-patterns/AutoDeprecation.sol";

contract AutoDeprecationTest is Test {
    AutoDeprecation internal autoDeprecation;

    function setUp() public {
        autoDeprecation = new AutoDeprecation(1 days);
    }

    function test_DoAction() public view {
        assertTrue(autoDeprecation.doAction());
    }

    function test_DoActionRevertsAfterDeprecation() public {
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(AutoDeprecation.ContractDeprecated.selector);
        autoDeprecation.doAction();
    }
}
