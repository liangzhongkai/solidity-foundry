// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {ContractRegistry} from "../../../src/10-design-patterns/contract-management/ContractRegistry.sol";

contract ContractRegistryTest is Test {
    ContractRegistry internal registry;
    address internal owner = address(0x1);
    address internal nonOwner = address(0x2);
    address internal someContract = address(0x3);

    function setUp() public {
        vm.prank(owner);
        registry = new ContractRegistry(1 days);
    }

    function test_RegisterContract() public {
        vm.prank(owner);
        registry.registerContract("MyContract", someContract);

        vm.warp(block.timestamp + 1 days);
        registry.activateContract("MyContract");

        assertEq(registry.getContract("MyContract"), someContract);
    }

    function test_RegisterContractUnauthorized() public {
        vm.prank(nonOwner);
        vm.expectRevert(ContractRegistry.Unauthorized.selector);
        registry.registerContract("MyContract", someContract);
    }

    function test_RemoveContract() public {
        vm.prank(owner);
        registry.registerContract("MyContract", someContract);

        vm.warp(block.timestamp + 1 days);
        registry.activateContract("MyContract");

        vm.prank(owner);
        registry.removeContract("MyContract");

        vm.expectRevert(ContractRegistry.ContractNotFound.selector);
        registry.getContract("MyContract");
    }

    function test_ActivateTooEarlyReverts() public {
        vm.prank(owner);
        registry.registerContract("MyContract", someContract);

        vm.expectRevert(
            abi.encodeWithSelector(
                ContractRegistry.ActivationNotReady.selector, block.timestamp, block.timestamp + 1 days
            )
        );
        registry.activateContract("MyContract");
    }

    function test_GetNonExistentContractReverts() public {
        vm.expectRevert(ContractRegistry.ContractNotFound.selector);
        registry.getContract("NonExistent");
    }
}
