// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PackingChallenge} from "../src/01-slot-packing/PackingChallenge.sol";
import {PackingChallengeOptimized} from "../src/01-slot-packing/PackingChallengeOptimized.sol";

contract PackingDemoScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("========== Slot Packing Demo ==========\n");

        // Deploy non-optimized version
        console.log("Deploy non-optimized version: uint128 a, uint256 b, uint128 c");
        PackingChallenge nonOptimized = new PackingChallenge();
        console.log("Non-optimized address:", address(nonOptimized));

        // Deploy optimized version
        console.log("\nDeploy optimized version: uint128 a, uint128 c, uint256 b");
        PackingChallengeOptimized optimized = new PackingChallengeOptimized();
        console.log("Optimized address:", address(optimized));

        vm.stopBroadcast();

        // Comparison summary
        console.log("\n========== Comparison Summary ==========");
        uint256 slots1 = countUsedSlots(address(nonOptimized));
        uint256 slots2 = countUsedSlots(address(optimized));

        console.log("Non-optimized version slots:", slots1);
        console.log("Optimized version slots:", slots2);
        console.log("Slots saved:", slots1 - slots2);
        console.log("Gas saved:", (slots1 - slots2) * 20000);
        console.log("\nDemo completed!");
    }

    function countUsedSlots(address contractAddress) internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < 5; i++) {
            if (uint256(vm.load(contractAddress, bytes32(i))) != 0) {
                count++;
            }
        }
        return count;
    }
}
