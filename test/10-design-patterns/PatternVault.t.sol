// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {PatternVault} from "../../src/10-design-patterns/PatternVault.sol";
import {PatternVaultFactory} from "../../src/10-design-patterns/PatternVaultFactory.sol";

contract ReentrantWithdrawer {
    PatternVault public immutable vault;

    constructor(PatternVault vault_) {
        vault = vault_;
    }

    function triggerWithdraw() external {
        vault.withdraw();
    }

    receive() external payable {
        // This reentrant call must fail due to nonReentrant guard.
        (bool ok,) = address(vault).call(abi.encodeWithSelector(PatternVault.withdraw.selector));
        ok;
    }
}

contract PatternVaultTest is Test {
    PatternVaultFactory internal factory;
    PatternVault internal vault;

    address internal owner = address(0xA11CE);
    address internal operator = address(0xB0B);
    address internal user = address(0xCAFE);
    address internal other = address(0xD00D);

    function setUp() public {
        factory = new PatternVaultFactory();

        PatternVault.Config memory cfg = PatternVault.Config({
            maxBalance: uint96(100 ether),
            epochLimit: uint96(10 ether),
            epochDuration: uint32(1 hours),
            emergencyDelay: uint32(1 days)
        });

        vm.prank(owner);
        address vaultAddr = factory.createVault(cfg);
        vault = PatternVault(payable(vaultAddr));

        vm.deal(owner, 200 ether);
        vm.deal(operator, 100 ether);
        vm.deal(user, 100 ether);
        vm.deal(other, 100 ether);

        vm.prank(owner);
        vault.setOperator(operator, true);
    }

    function test_FactoryCreateDeterministic() public {
        PatternVault.Config memory cfg = PatternVault.Config({
            maxBalance: uint96(50 ether),
            epochLimit: uint96(5 ether),
            epochDuration: uint32(1 hours),
            emergencyDelay: uint32(1 days)
        });

        bytes32 salt = keccak256("vault-1");
        address predicted = factory.predictVaultAddress(owner, salt);

        vm.prank(owner);
        address created = factory.createVaultDeterministic(cfg, salt);
        assertEq(created, predicted);
    }

    function test_DepositAndBalanceCap() public {
        vm.prank(owner);
        vault.deposit{value: 80 ether}();
        assertEq(address(vault).balance, 80 ether);

        vm.expectRevert(abi.encodeWithSelector(PatternVault.BalanceCapExceeded.selector, 120 ether, 100 ether));
        vm.prank(owner);
        vault.deposit{value: 40 ether}();
    }

    function test_OnlyOperatorCanQueuePayment() public {
        vm.prank(owner);
        vault.deposit{value: 5 ether}();

        vm.expectRevert(PatternVault.Unauthorized.selector);
        vm.prank(user);
        vault.queuePayment(user, 1 ether);
    }

    function test_RateLimitByEpoch() public {
        vm.prank(owner);
        vault.deposit{value: 20 ether}();

        vm.prank(operator);
        vault.queuePayment(user, 6 ether);

        vm.expectRevert(abi.encodeWithSelector(PatternVault.EpochLimitExceeded.selector, 5 ether, 4 ether));
        vm.prank(operator);
        vault.queuePayment(other, 5 ether);

        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(operator);
        vault.queuePayment(other, 5 ether);
    }

    function test_PullPaymentWithdraw() public {
        vm.prank(owner);
        vault.deposit{value: 10 ether}();

        vm.prank(operator);
        vault.queuePayment(user, 3 ether);

        uint256 beforeBal = user.balance;
        vm.prank(user);
        vault.withdraw();

        assertEq(user.balance, beforeBal + 3 ether);
        assertEq(vault.credits(user), 0);
        assertEq(vault.totalCredits(), 0);
    }

    function test_ReentrancyIsBlocked() public {
        vm.prank(owner);
        vault.deposit{value: 10 ether}();

        ReentrantWithdrawer attacker = new ReentrantWithdrawer(vault);
        vm.prank(operator);
        vault.queuePayment(address(attacker), 2 ether);

        uint256 beforeBal = address(attacker).balance;
        attacker.triggerWithdraw();

        assertEq(address(attacker).balance, beforeBal + 2 ether);
        assertEq(vault.credits(address(attacker)), 0);
    }

    function test_PauseBlocksQueueButAllowsWithdraw() public {
        vm.prank(owner);
        vault.deposit{value: 10 ether}();

        vm.prank(operator);
        vault.queuePayment(user, 1 ether);

        vm.prank(owner);
        vault.setPaused(true);

        vm.expectRevert(PatternVault.Paused.selector);
        vm.prank(operator);
        vault.queuePayment(user, 1 ether);

        vm.prank(user);
        vault.withdraw();
    }

    function test_EmergencySweep_OnlySurplusAfterDelay() public {
        vm.prank(owner);
        vault.deposit{value: 10 ether}();

        vm.prank(operator);
        vault.queuePayment(user, 3 ether);

        vm.prank(owner);
        vault.setPaused(true);

        // Cannot sweep before delay.
        vm.expectRevert();
        vm.prank(owner);
        vault.emergencySweep(owner, 1 ether);

        vm.warp(block.timestamp + 1 days + 1);

        // Surplus is 7 ether, liabilities are protected.
        vm.expectRevert(abi.encodeWithSelector(PatternVault.InsufficientSurplus.selector, 8 ether, 7 ether));
        vm.prank(owner);
        vault.emergencySweep(owner, 8 ether);

        uint256 ownerBefore = owner.balance;
        vm.prank(owner);
        vault.emergencySweep(owner, 2 ether);
        assertEq(owner.balance, ownerBefore + 2 ether);
    }
}
