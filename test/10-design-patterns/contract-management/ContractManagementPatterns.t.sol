// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {
    BaseAction,
    Decorator,
    Mediator,
    Satellite,
    MainContract,
    V1Legacy,
    V2Modern,
    Observable,
    Observer
} from "../../../src/10-design-patterns/contract-management/ContractManagementPatterns.sol";

contract ContractManagementPatternsTest is Test {
    function test_Decorator() public {
        BaseAction base = new BaseAction();
        Decorator decorator = new Decorator(address(base));

        assertEq(decorator.executeAction(), 100);
        assertEq(decorator.executionCount(), 1);
    }

    function test_Mediator() public {
        Mediator mediator = new Mediator();
        mediator.registerAndReward();

        assertTrue(mediator.directory().isRegistered(address(this)));
        assertEq(mediator.rewards().rewards(address(this)), mediator.REGISTRATION_REWARD());
    }

    function test_Mediator_CannotRegisterTwice() public {
        Mediator mediator = new Mediator();
        mediator.registerAndReward();

        vm.expectRevert(Mediator.AlreadyRegistered.selector);
        mediator.registerAndReward();
    }

    function test_Satellite() public {
        Satellite sat = new Satellite();
        MainContract main = new MainContract(address(sat));

        assertEq(main.doWork(10, 5), 52); // 50 + 2
    }

    function test_Migration() public {
        V1Legacy v1 = new V1Legacy();
        V2Modern v2 = new V2Modern(address(v1));

        vm.deal(address(this), 1 ether);
        v1.deposit{value: 1 ether}();

        assertEq(v1.balances(address(this)), 1 ether);

        v1.setMigrationTarget(address(v2));

        v2.migrate();

        assertEq(v1.balances(address(this)), 0);
        assertEq(v2.balances(address(this)), 1 ether);
    }

    function test_Migration_FreezesLegacyDeposits() public {
        V1Legacy v1 = new V1Legacy();
        V2Modern v2 = new V2Modern(address(v1));

        v1.setMigrationTarget(address(v2));

        vm.expectRevert(V1Legacy.DepositsFrozen.selector);
        v1.deposit{value: 1 ether}();
    }

    function test_Observer() public {
        Observable observable = new Observable();
        Observer observer = new Observer();

        observable.setValue(42);
        observer.sync(address(observable));

        assertEq(observer.lastSeenValue(), 42);
        assertEq(observer.lastSyncedVersion(), 1);
    }

    function test_Observer_CannotSyncSameVersionTwice() public {
        Observable observable = new Observable();
        Observer observer = new Observer();

        observable.setValue(42);
        observer.sync(address(observable));

        vm.expectRevert(Observer.AlreadySynced.selector);
        observer.sync(address(observable));
    }
}
