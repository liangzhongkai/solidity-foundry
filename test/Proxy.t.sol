// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {console} from "forge-std@1.14.0/console.sol";
import {Proxy, AdminUpgradeabilityProxy} from "../src/04-proxy/Proxy.sol";
import {CounterV1, CounterV2, BrokenCounter} from "../src/04-proxy/Counter.sol";

interface ICounterV1 {
    function initialize(address _owner) external;
    function increment() external;
    function decrement() external;
    function incrementBy(uint256 amount) external;
    function getCount() external view returns (uint256);
    function getOwner() external view returns (address);
    function getLastUpdated() external view returns (uint256);
    function getVersion() external view returns (string memory);
}

interface ICounterV2 {
    function getCount() external view returns (uint256);
    function getOwner() external view returns (address);
    function getLastUpdated() external view returns (uint256);
    function getTotalOperations() external view returns (uint256);
    function getVersion() external view returns (string memory);
    function getStats() external view returns (uint256 _count, uint256 _totalOps, uint256 _lastUpdated);
    function increment() external;
    function decrement() external;
    function incrementBy(uint256 amount) external;
    function add(uint256 amount) external;
    function multiply(uint256 factor) external;
    function reset() external;
}

interface IBrokenCounter {
    function count() external view returns (uint256);
    function owner() external view returns (address);
    function increment() external;
    function getVersion() external pure returns (string memory);
}

contract ProxyTest is Test {
    Proxy public proxy;
    CounterV1 public counterV1;
    CounterV2 public counterV2;
    BrokenCounter public brokenCounter;
    AdminUpgradeabilityProxy public adminProxy;

    address public owner;
    address public user1;

    event Upgraded(address indexed oldImpl, address indexed newImpl);

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);

        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);

        counterV1 = new CounterV1();
        counterV2 = new CounterV2();
        brokenCounter = new BrokenCounter();

        proxy = new Proxy(address(counterV1), owner);
        adminProxy = new AdminUpgradeabilityProxy(address(counterV1), owner);
    }

    function test_ShouldDemonstrateStorageAndCodeSeparation() public {
        address proxyAddress = address(proxy);
        address v1Address = address(counterV1);

        console.log("\n========== Storage vs Code Separation ==========");
        console.log("Proxy address (storage here):", proxyAddress);
        console.log("Impl address (code here):", v1Address);
        console.log("=========================================\n");

        ICounterV1(proxyAddress).initialize(owner);

        uint256 slot2 = uint256(vm.load(proxyAddress, bytes32(uint256(2))));
        uint256 slot3 = uint256(vm.load(proxyAddress, bytes32(uint256(3))));
        uint256 slot4 = uint256(vm.load(proxyAddress, bytes32(uint256(4))));

        console.log("Proxy Storage direct read:");
        console.log("  Slot 2 (count):", slot2);
        // forge-lint: disable-next-line(unsafe-typecast)
        address ownerFromSlot = address(uint160(uint256(slot3)));
        console.log("  Slot 3 (owner):", ownerFromSlot);
        console.log("  Slot 4 (lastUpdated):", slot4);

        uint256 count = ICounterV1(proxyAddress).getCount();
        address contractOwner = ICounterV1(proxyAddress).getOwner();
        string memory version = ICounterV1(proxyAddress).getVersion();

        console.log("\nVia interface call:");
        console.log("  count:", count);
        console.log("  owner:", contractOwner);
        console.log("  version:", version);

        assertEq(count, 0);
        assertEq(contractOwner, owner);
        assertEq(version, "V1");
    }

    function test_ShouldDemonstrateDelegatecallKeepsMsgSender() public {
        ICounterV1(address(proxy)).initialize(owner);

        vm.prank(user1);
        ICounterV1(address(proxy)).increment();

        uint256 count = ICounterV1(address(proxy)).getCount();
        assertEq(count, 1);

        uint256 v1Count = counterV1.getCount();
        assertEq(v1Count, 0);

        console.log("\n========== delegatecall Semantics ==========");
        console.log("After Proxy.increment():");
        console.log("  Count on Proxy:", count);
        console.log("  Count on V1 contract:", v1Count);
        console.log("Conclusion: Code executes in V1, but storage in Proxy!");
        console.log("===========================================\n");
    }

    function test_ShouldDemonstrateMultipleProxiesShareImpl() public {
        Proxy proxy2 = new Proxy(address(counterV1), owner);

        ICounterV1(address(proxy)).initialize(owner);
        ICounterV1(address(proxy2)).initialize(owner);

        for (uint256 i = 0; i < 5; i++) {
            ICounterV1(address(proxy)).increment();
        }

        for (uint256 i = 0; i < 3; i++) {
            ICounterV1(address(proxy2)).increment();
        }

        uint256 count1 = ICounterV1(address(proxy)).getCount();
        uint256 count2 = ICounterV1(address(proxy2)).getCount();

        console.log("\n========== Shared Impl Example ==========");
        console.log("Impl address:", address(counterV1));
        console.log("Proxy1 count:", count1);
        console.log("Proxy2 count:", count2);
        console.log("\nTwo Proxies use same code, but have independent storage!");
        console.log("===================================\n");

        assertEq(count1, 5);
        assertEq(count2, 3);
    }

    function test_ShouldDemonstrateUpgradeFromV1ToV2() public {
        Proxy upgradeProxy = new Proxy(address(counterV1), owner);

        ICounterV1(address(upgradeProxy)).initialize(owner);

        ICounterV1(address(upgradeProxy)).increment();
        ICounterV1(address(upgradeProxy)).increment();
        ICounterV1(address(upgradeProxy)).incrementBy(10);

        uint256 count = ICounterV1(address(upgradeProxy)).getCount();
        string memory version = ICounterV1(address(upgradeProxy)).getVersion();

        console.log("\n========== Before Upgrade (V1) ==========");
        console.log("Count:", count);
        console.log("Version:", version);
        console.log("Impl:", address(counterV1));
        console.log("===============================\n");

        assertEq(count, 12);
        assertEq(version, "V1");

        vm.expectEmit(false, false, false, true);
        emit Upgraded(address(counterV1), address(counterV2));
        upgradeProxy.upgrade(address(counterV2));

        count = ICounterV2(address(upgradeProxy)).getCount();
        version = ICounterV2(address(upgradeProxy)).getVersion();
        address impl = upgradeProxy.impl();

        console.log("\n========== After Upgrade (V2) ==========");
        console.log("Count:", count);
        console.log("Version:", version);
        console.log("Impl:", impl);
        console.log("Storage data preserved!", count == 12);
        console.log("===============================\n");

        assertEq(count, 12);
        assertEq(version, "V2");
        assertEq(impl, address(counterV2));

        ICounterV2(address(upgradeProxy)).multiply(2);
        count = ICounterV2(address(upgradeProxy)).getCount();
        assertEq(count, 24);

        (uint256 _count, uint256 _totalOps,) = ICounterV2(address(upgradeProxy)).getStats();
        assertEq(_count, 24);
        assertEq(_totalOps, 1);

        console.log("\n========== V2 New Features ==========");
        console.log("After multiply(2) count:", count);
        console.log("totalOperations:", _totalOps);
        console.log("===================================\n");
    }

    function test_ShouldDemonstrateCorrectStorageLayoutUpgrade() public {
        Proxy storageProxy = new Proxy(address(counterV1), owner);

        ICounterV1(address(storageProxy)).initialize(owner);
        ICounterV1(address(storageProxy)).increment();

        address proxyAddress = address(storageProxy);
        uint256 slot2 = uint256(vm.load(proxyAddress, bytes32(uint256(2))));
        uint256 slot3 = uint256(vm.load(proxyAddress, bytes32(uint256(3))));
        uint256 slot4 = uint256(vm.load(proxyAddress, bytes32(uint256(4))));

        console.log("\n========== V1 Storage Layout ==========");
        console.log("Slot 2 (count):", slot2);
        // forge-lint: disable-next-line(unsafe-typecast)
        console.log("Slot 3 (owner):", address(uint160(uint256(slot3))));
        console.log("Slot 4 (lastUpdated):", slot4);
        console.log("===================================\n");

        storageProxy.upgrade(address(counterV2));

        uint256 newSlot2 = uint256(vm.load(proxyAddress, bytes32(uint256(2))));
        uint256 newSlot3 = uint256(vm.load(proxyAddress, bytes32(uint256(3))));
        uint256 newSlot4 = uint256(vm.load(proxyAddress, bytes32(uint256(4))));
        uint256 slot5 = uint256(vm.load(proxyAddress, bytes32(uint256(5))));

        console.log("\n========== V2 Storage Layout ==========");
        console.log("Slot 2 (count):", newSlot2);
        // forge-lint: disable-next-line(unsafe-typecast)
        console.log("Slot 3 (owner):", address(uint160(uint256(newSlot3))));
        console.log("Slot 4 (lastUpdated):", newSlot4);
        console.log("Slot 5 (totalOperations):", slot5);
        console.log("===================================\n");

        assertEq(slot2, newSlot2);
        assertEq(slot3, newSlot3);
        assertEq(slot4, newSlot4);

        uint256 count = ICounterV2(address(storageProxy)).getCount();
        assertEq(count, 1);

        ICounterV2(address(storageProxy)).increment();
        uint256 newCount = ICounterV2(address(storageProxy)).getCount();
        assertEq(newCount, 2);

        uint256 totalOps = ICounterV2(address(storageProxy)).getTotalOperations();
        assertEq(totalOps, 1);
    }

    function test_ShouldDemonstrateBrokenStorageLayout() public {
        Proxy brokenProxy = new Proxy(address(counterV1), owner);

        ICounterV1(address(brokenProxy)).initialize(owner);
        ICounterV1(address(brokenProxy)).increment();

        uint256 countBefore = ICounterV1(address(brokenProxy)).getCount();
        address ownerBefore = ICounterV1(address(brokenProxy)).getOwner();

        console.log("\n========== Before Upgrade ==========");
        console.log("Count:", countBefore);
        console.log("Owner:", ownerBefore);
        console.log("============================\n");

        brokenProxy.upgrade(address(brokenCounter));

        uint256 countAfter = IBrokenCounter(address(brokenProxy)).count();
        address ownerAfter = IBrokenCounter(address(brokenProxy)).owner();

        console.log("\n========== After Upgrade (Wrong Layout) ==========");
        console.log("Count (actually Proxy slot 0/impl value):", countAfter);
        console.log("Owner (actually Proxy slot 1/admin):", ownerAfter);
        console.log("\nData corrupted!");
        console.log("===============================================\n");

        assertNotEq(countAfter, 1);
    }

    function test_CounterV1_Decrement() public {
        Proxy testProxy = new Proxy(address(counterV1), owner);
        ICounterV1(address(testProxy)).initialize(owner);

        ICounterV1(address(testProxy)).increment();
        ICounterV1(address(testProxy)).increment();

        uint256 count = ICounterV1(address(testProxy)).getCount();
        assertEq(count, 2);

        ICounterV1(address(testProxy)).decrement();
        count = ICounterV1(address(testProxy)).getCount();
        assertEq(count, 1);

        ICounterV1(address(testProxy)).decrement();
        count = ICounterV1(address(testProxy)).getCount();
        assertEq(count, 0);

        vm.expectRevert("count cannot go below zero");
        ICounterV1(address(testProxy)).decrement();

        console.log("\n========== CounterV1 decrement() Test ==========");
        console.log("increment x2, decrement x2, decrement failed");
        console.log("count:", count);
        console.log("==================================================\n");
    }

    function test_AdminUpgradeabilityProxy_UpgradeTo() public {
        ICounterV1(address(adminProxy)).initialize(owner);
        ICounterV1(address(adminProxy)).increment();

        adminProxy.upgradeTo(address(counterV2));

        string memory version = ICounterV2(address(adminProxy)).getVersion();
        assertEq(version, "V2");

        uint256 count = ICounterV2(address(adminProxy)).getCount();
        assertEq(count, 1);

        console.log("\n========== upgradeTo() Success ==========");
        console.log("Version:", version);
        console.log("Count preserved:", count);
        console.log("=====================================\n");
    }
}
