// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MappingSlot} from "../src/03-mapping-slot/MappingSlot.sol";

contract MappingSlotDemoScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("\n========== Day 2: Mapping Slot Calculation ==========\n");

        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer account:", deployer);

        // Deploy contract
        console.log("\nDeploying MappingSlot contract...");
        MappingSlot mappingSlot = new MappingSlot();
        address contractAddress = address(mappingSlot);
        console.log("Contract address:", contractAddress);

        vm.stopBroadcast();

        // Demo 1: Basic mapping slot calculation
        console.log("\n========== Demo 1: Basic Mapping Slot Calculation ==========");

        uint256 testAmount = 1234567890;
        vm.prank(deployer);
        mappingSlot.setBalance(deployer, testAmount);
        console.log("Set balance:", testAmount);

        uint256 balance = mappingSlot.balances(deployer);
        console.log("Balance via getter:", balance);

        bytes32 calculatedSlot = keccak256(abi.encodePacked(bytes32(uint256(uint160(deployer))), uint256(0)));

        console.log("\nManual calculation:");
        console.log("Calculated slot:", vm.toString(calculatedSlot));

        uint256 storageValue = uint256(vm.load(contractAddress, calculatedSlot));
        console.log("\nDirect storage read:");
        console.log("Storage value:", storageValue);

        console.log("\nVerification:");
        console.log("Getter value:", balance);
        console.log("Storage value:", storageValue);
        console.log("Match?", balance == storageValue);

        console.log("\n========== Key Takeaways ==========");
        console.log("1. Mapping storage location:");
        console.log("   slot = keccak256(abi.encode(key, mapping_slot))");
        console.log("");
        console.log("2. Mapping variable occupies one slot");
        console.log("   Actual data stored in calculated slot");
        console.log("");
        console.log("3. Nested mapping calculation:");
        console.log("   slot = keccak256(abi.encode(key2, keccak256(abi.encode(key1, mapping_slot))))");
        console.log("=====================================\n");
    }
}
