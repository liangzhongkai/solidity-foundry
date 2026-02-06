// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {PackingChallenge} from "../src/01-slot-packing/PackingChallenge.sol";
import {PackingChallengeOptimized} from "../src/01-slot-packing/PackingChallengeOptimized.sol";

contract PackingChallengeTest is Test {
    PackingChallenge public packingChallenge;
    PackingChallengeOptimized public packingOptimized;

    function setUp() public {
        packingChallenge = new PackingChallenge();
        packingOptimized = new PackingChallengeOptimized();
    }

    function test_ShouldShowNonOptimizedSlotUsage() public view {
        console.log("\n=== First order: uint128 a, uint256 b, uint128 c ===");

        uint256 slotCount = 0;

        for (uint256 i = 0; i < 5; i++) {
            bytes32 value = vm.load(address(packingChallenge), bytes32(i));
            if (uint256(value) != 0) {
                slotCount++;
                console.log("Slot");
                console.logUint(i);
                console.log(": USED");
            }
        }

        console.log("Total slots used:");
        console.logUint(slotCount);

        assertEq(packingChallenge.a(), 1);
        assertEq(packingChallenge.b(), 2);
        assertEq(packingChallenge.c(), 3);
    }

    function test_ShouldShowOptimizedSlotUsage() public view {
        console.log("\n=== Second order: uint128 a, uint128 c, uint256 b ===");

        uint256 slotCount = 0;

        for (uint256 i = 0; i < 5; i++) {
            bytes32 value = vm.load(address(packingOptimized), bytes32(i));
            if (uint256(value) != 0) {
                slotCount++;
                console.log("Slot");
                console.logUint(i);
                console.log(": USED");
            }
        }

        console.log("Total slots used:");
        console.logUint(slotCount);

        assertEq(packingOptimized.a(), 1);
        assertEq(packingOptimized.b(), 2);
        assertEq(packingOptimized.c(), 3);
    }

    function test_ShouldCompareTwoOrders() public view {
        console.log("\n=== Direct comparison ===");

        uint256 slots1 = 0;
        for (uint256 i = 0; i < 5; i++) {
            bytes32 value = vm.load(address(packingChallenge), bytes32(i));
            if (uint256(value) != 0) slots1++;
        }

        uint256 slots2 = 0;
        for (uint256 i = 0; i < 5; i++) {
            bytes32 value = vm.load(address(packingOptimized), bytes32(i));
            if (uint256(value) != 0) slots2++;
        }

        console.log("Non-optimized version slots:");
        console.logUint(slots1);
        console.log("Optimized version slots:");
        console.logUint(slots2);
        console.log("Slots saved:");
        console.logUint(slots1 - slots2);
        console.log("Gas saved:");
        console.logUint((slots1 - slots2) * 20000);

        assertEq(slots1, 3);
        assertEq(slots2, 2);
    }
}
