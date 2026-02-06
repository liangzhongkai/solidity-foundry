// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Proxy} from "../src/04-proxy/Proxy.sol";
import {CounterV1, CounterV2} from "../src/04-proxy/Counter.sol";

interface ICounterV1 {
    function initialize(address _owner) external;
    function increment() external;
    function incrementBy(uint256 amount) external;
    function getCount() external view returns (uint256);
    function getVersion() external view returns (string memory);
}

interface ICounterV2 {
    function getCount() external view returns (uint256);
    function getVersion() external view returns (string memory);
    function multiply(uint256 factor) external;
    function add(uint256 amount) external;
    function getStats() external view returns (uint256 _count, uint256 _totalOps, uint256 _lastUpdated);
}

contract ProxyDemoScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("\n========== Day 2: Proxy + delegatecall ==========\n");
        console.log("Deployer account:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy logic contract V1
        console.log("\nDeploying CounterV1 (logic contract)...");
        CounterV1 counterV1 = new CounterV1();
        address v1Address = address(counterV1);
        console.log("V1 address:", v1Address);

        // Deploy logic contract V2
        console.log("\nDeploying CounterV2 (upgrade version)...");
        CounterV2 counterV2 = new CounterV2();
        address v2Address = address(counterV2);
        console.log("V2 address:", v2Address);

        // Deploy Proxy pointing to V1
        console.log("\nDeploying Proxy (pointing to V1)...");
        Proxy proxy = new Proxy(v1Address, deployer);
        address proxyAddress = address(proxy);
        console.log("Proxy address:", proxyAddress);

        vm.stopBroadcast();

        // Demo 1: Basic operations
        console.log("\n========== Demo 1: Basic Operations (V1) ==========");

        vm.prank(deployer);
        ICounterV1(proxyAddress).initialize(deployer);
        console.log("Initialized");

        vm.prank(deployer);
        ICounterV1(proxyAddress).increment();
        vm.prank(deployer);
        ICounterV1(proxyAddress).increment();
        vm.prank(deployer);
        ICounterV1(proxyAddress).incrementBy(10);

        uint256 count = ICounterV1(proxyAddress).getCount();
        string memory version = ICounterV1(proxyAddress).getVersion();

        console.log("Count:", count);
        console.log("Version:", version);

        // Demo 3: Upgrade to V2
        console.log("\n========== Demo 3: Upgrade to V2 ==========");

        console.log("\nExecuting upgrade...");
        vm.prank(deployer);
        proxy.upgrade(v2Address);

        console.log("Upgrade completed!");

        count = ICounterV2(proxyAddress).getCount();
        version = ICounterV2(proxyAddress).getVersion();

        console.log("After upgrade Count:", count);
        console.log("Version:", version);
        console.log("Data preserved!");

        // Demo 4: V2 new features
        console.log("\n========== Demo 4: V2 New Features ==========");

        vm.prank(deployer);
        ICounterV2(proxyAddress).multiply(2);
        count = ICounterV2(proxyAddress).getCount();
        console.log("After multiply(2) count:", count);

        (, uint256 _totalOps,) = ICounterV2(proxyAddress).getStats();
        console.log("Total Operations:", _totalOps);

        console.log("\n========== Key Takeaways ==========");
        console.log("1. delegatecall essence:");
        console.log("   - Code executes in impl contract");
        console.log("   - But storage in Proxy contract");
        console.log("   - msg.sender remains as original caller");
        console.log("");
        console.log("2. Upgradeable contract principle:");
        console.log("   - Storage always in Proxy");
        console.log("   - Logic in impl contract");
        console.log("   - Change impl address = upgrade contract");
        console.log("====================================\n");
    }
}
