// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MappingSlot} from "../src/03-mapping-slot/MappingSlot.sol";

contract MappingSlotTest is Test {
    MappingSlot public mappingSlot;
    address public user1;
    address public user2;

    function setUp() public {
        mappingSlot = new MappingSlot();
        user1 = address(0x1);
        user2 = address(0x2);
    }

    function test_ShouldDemonstrateBalancesMappingSlot() public {
        address contractAddress = address(mappingSlot);
        uint256 mappingSlotNumber = 0;
        uint256 testAmount = 12345;

        mappingSlot.setBalance(user1, testAmount);

        uint256 balanceViaGetter = mappingSlot.balances(user1);
        assertEq(balanceViaGetter, testAmount);

        bytes32 paddedKey = bytes32(uint256(uint160(user1)));
        bytes32 calculatedSlot = keccak256(abi.encode(paddedKey, mappingSlotNumber));

        console.log("\n========== Mapping Slot Calculation ==========");
        console.log("Contract address:", contractAddress);
        console.log("User address:", user1);
        console.log("Mapping at slot:", mappingSlotNumber);
        console.log("Calculated slot:", vm.toString(calculatedSlot));
        console.log("==========================================\n");

        uint256 storageValue = uint256(vm.load(contractAddress, calculatedSlot));
        assertEq(storageValue, testAmount);
        assertEq(storageValue, balanceViaGetter);

        console.log("Verification successful!");
        console.log("  - Getter returns:", balanceViaGetter);
        console.log("  - Storage reads:", storageValue);
    }

    function test_ShouldDemonstrateGetBalanceSlotFunction() public {
        address contractAddress = address(mappingSlot);

        bytes32 slotFromContract = mappingSlot.getBalanceSlot(user1);

        bytes32 paddedKey = bytes32(uint256(uint160(user1)));
        bytes32 calculatedSlot = keccak256(abi.encode(paddedKey, uint256(0)));

        assertEq(slotFromContract, calculatedSlot);

        console.log("\n========== getBalanceSlot() Test ==========");
        console.log("User address:", user1);
        console.log("Contract calculated slot:", vm.toString(slotFromContract));
        console.log("Manual calculated slot:", vm.toString(calculatedSlot));
        console.log("Match:", slotFromContract == calculatedSlot);
        console.log("===========================================\n");

        uint256 testAmount = 99999;
        mappingSlot.setBalance(user1, testAmount);

        uint256 storageValue = uint256(vm.load(contractAddress, slotFromContract));
        assertEq(storageValue, testAmount);
    }

    function test_ShouldDemonstrateAllowancesMappingSlot() public {
        address contractAddress = address(mappingSlot);
        uint256 mappingSlotNumber = 1;
        uint256 testAmount = 99999;

        mappingSlot.setAllowance(user1, user2, testAmount);

        bytes32 slotFromContract = mappingSlot.getAllowanceSlot(user2);

        bytes32 paddedKey = bytes32(uint256(uint160(user2)));
        bytes32 calculatedSlot = keccak256(abi.encode(paddedKey, mappingSlotNumber));

        assertEq(slotFromContract, calculatedSlot);

        console.log("\n========== Allowances Mapping Slot ==========");
        console.log("Contract calculated slot:", vm.toString(slotFromContract));
        console.log("Manual calculated slot:", vm.toString(calculatedSlot));
        console.log("Match:", slotFromContract == calculatedSlot);
        console.log("=============================================\n");

        uint256 storageValue = uint256(vm.load(contractAddress, calculatedSlot));
        assertEq(storageValue, testAmount);
    }

    function test_ShouldDemonstrateNestedMappingSlot() public {
        address contractAddress = address(mappingSlot);
        uint256 outerMappingSlot = 3;
        uint256 testAmount = 55555;

        mappingSlot.setAllowance(user1, user2, testAmount);

        bytes32 slotFromContract = mappingSlot.getNestedAllowanceSlot(user1, user2);

        bytes32 key1 = bytes32(uint256(uint160(user1)));
        bytes32 key2 = bytes32(uint256(uint160(user2)));

        bytes32 outerSlot = keccak256(abi.encode(key1, outerMappingSlot));
        bytes32 finalSlot = keccak256(abi.encode(key2, outerSlot));

        console.log("\n========== Nested Mapping Slot Calculation ==========");
        console.log("Outer key (owner):", user1);
        console.log("Inner key (spender):", user2);
        console.log("Outer mapping slot:", outerMappingSlot);
        console.log("First keccak256:", vm.toString(outerSlot));
        console.log("Final slot:", vm.toString(finalSlot));
        console.log("Contract result:", vm.toString(slotFromContract));
        console.log("Match:", slotFromContract == finalSlot);
        console.log("================================================\n");

        assertEq(slotFromContract, finalSlot);

        uint256 storageValue = uint256(vm.load(contractAddress, finalSlot));
        assertEq(storageValue, testAmount);
    }

    function test_ShouldDemonstrateDirectStorageOperations() public {
        address contractAddress = address(mappingSlot);

        bytes32 paddedKey = bytes32(uint256(uint160(user1)));
        bytes32 targetSlot = keccak256(abi.encode(paddedKey, uint256(0)));

        uint256 testValue = 88888;

        mappingSlot.writeDirectlyToSlot(uint256(targetSlot), testValue);

        uint256 balance = mappingSlot.balances(user1);
        assertEq(balance, testValue);

        console.log("\n========== Direct Storage Operations ==========");
        console.log("Target slot:", vm.toString(targetSlot));
        console.log("Written value:", testValue);
        console.log("balances[user1]:", balance);
        console.log("======================================\n");

        uint256 directRead = mappingSlot.readDirectlyFromSlot(uint256(targetSlot));
        assertEq(directRead, testValue);

        uint256 providerRead = uint256(vm.load(contractAddress, targetSlot));
        assertEq(providerRead, testValue);
    }

    function test_ShouldDemonstrateSparseStorage() public {
        mappingSlot.setBalance(user1, 1000);
        mappingSlot.setBalance(user2, 2000);

        bytes32 key1 = bytes32(uint256(uint160(user1)));
        bytes32 slot1 = keccak256(abi.encode(key1, uint256(0)));

        bytes32 key2 = bytes32(uint256(uint160(user2)));
        bytes32 slot2 = keccak256(abi.encode(key2, uint256(0)));

        console.log("\n========== Sparse Storage Characteristic ==========");
        console.log("user1 slot:", vm.toString(slot1));
        console.log("user2 slot:", vm.toString(slot2));
        console.log("Adjacent slots?", slot1 == slot2);
        uint256 diff =
            uint256(slot2) > uint256(slot1) ? uint256(slot2) - uint256(slot1) : uint256(slot1) - uint256(slot2);
        console.log("Slot value difference:", diff);
        console.log("================================================\n");

        assertNotEq(slot1, slot2);

        address randomUser = address(0x3);
        bytes32 key3 = bytes32(uint256(uint160(randomUser)));
        bytes32 slot3 = keccak256(abi.encode(key3, uint256(0)));
        uint256 value = uint256(vm.load(address(mappingSlot), slot3));
        assertEq(value, 0);
    }

    function test_GetBalanceSlot() public view {
        bytes32 slot = mappingSlot.getBalanceSlot(user1);
        assertTrue(slot != bytes32(0));
    }

    function test_GetAllowanceSlot() public view {
        bytes32 slot = mappingSlot.getAllowanceSlot(user1);
        assertTrue(slot != bytes32(0));
    }

    function test_GetNestedAllowanceSlot() public view {
        bytes32 slot = mappingSlot.getNestedAllowanceSlot(user1, user2);
        assertTrue(slot != bytes32(0));
    }

    function test_WriteAndReadDirectlyToSlot() public {
        bytes32 paddedKey = bytes32(uint256(uint160(user1)));
        bytes32 targetSlot = keccak256(abi.encode(paddedKey, uint256(0)));
        uint256 testValue = 42;

        mappingSlot.writeDirectlyToSlot(uint256(targetSlot), testValue);
        assertEq(mappingSlot.balances(user1), testValue);
    }

    function test_SetBalance() public {
        uint256 testAmount = 777;
        mappingSlot.setBalance(user1, testAmount);
        assertEq(mappingSlot.balances(user1), testAmount);
    }

    function test_SetAllowance() public {
        uint256 testAmount = 888;
        mappingSlot.setAllowance(user1, user2, testAmount);
        assertEq(mappingSlot.allowances(user2), testAmount);
        assertEq(mappingSlot.nestedAllowances(user1, user2), testAmount);
    }
}
