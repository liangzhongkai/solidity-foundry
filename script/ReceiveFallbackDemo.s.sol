// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ReceiveFallbackDemo, OnlyReceive, OnlyFallback} from "../src/05-receive-fallback/ReceiveFallback.sol";

contract ReceiveFallbackDemoScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("\n========== Day 2: receive() vs fallback() ==========\n");
        console.log("Deployer account:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        console.log("\nDeploying contracts...");

        ReceiveFallbackDemo demo = new ReceiveFallbackDemo();
        address demoAddress = address(demo);
        console.log("ReceiveFallbackDemo address:", demoAddress);

        OnlyReceive onlyReceive = new OnlyReceive();
        address onlyReceiveAddress = address(onlyReceive);
        console.log("OnlyReceive address:", onlyReceiveAddress);

        OnlyFallback onlyFallback = new OnlyFallback();
        address onlyFallbackAddress = address(onlyFallback);
        console.log("OnlyFallback address:", onlyFallbackAddress);

        vm.stopBroadcast();

        // Demo 1: Pure ETH transfer triggers receive()
        console.log("\n========== Demo 1: Pure ETH Transfer ==========");
        vm.prank(deployer);
        demo.resetFlags();

        vm.deal(deployer, 10 ether);
        (bool success,) = demoAddress.call{value: 1 ether}("");
        require(success, "Transfer failed");

        bool receiveCalled = demo.receiveCalled();
        bool fallbackCalled = demo.fallbackCalled();

        console.log("receive() called:", receiveCalled);
        console.log("fallback() called:", fallbackCalled);

        // Demo 2: Calling non-existent function triggers fallback()
        console.log("\n========== Demo 2: Call Non-existent Function ==========");
        vm.prank(deployer);
        demo.resetFlags();

        bytes memory fakeSelector = abi.encodeWithSignature("nonExistentFunction(uint256)");
        fakeSelector = abi.encodePacked(bytes4(keccak256("nonExistentFunction(uint256)")));

        (success,) = demoAddress.call(fakeSelector);
        require(success, "Call failed");

        receiveCalled = demo.receiveCalled();
        fallbackCalled = demo.fallbackCalled();

        console.log("receive() called:", receiveCalled);
        console.log("fallback() called:", fallbackCalled);

        console.log("\n========== EVM Call Routing Summary ==========");
        console.log("msg.data empty (pure transfer):");
        console.log("  1. Has receive() -> receive()");
        console.log("  2. No receive() + has fallback() -> fallback()");
        console.log("  3. Neither -> REVERT");
        console.log("");
        console.log("msg.data not empty (function call):");
        console.log("  1. Match function -> Execute function");
        console.log("  2. No match + has fallback() -> fallback()");
        console.log("  3. No match + no fallback() -> REVERT");
        console.log("======================================\n");
    }
}
