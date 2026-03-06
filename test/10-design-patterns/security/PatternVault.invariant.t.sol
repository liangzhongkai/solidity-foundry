// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {CommonBase} from "forge-std@1.14.0/Base.sol";
import {StdCheats} from "forge-std@1.14.0/StdCheats.sol";
import {StdUtils} from "forge-std@1.14.0/StdUtils.sol";
import {PatternVault} from "../../../src/10-design-patterns/security/PatternVault.sol";
import {PatternVaultFactory} from "../../../src/10-design-patterns/contract-management/PatternVaultFactory.sol";

contract PatternVaultHandler is CommonBase, StdCheats, StdUtils {
    PatternVault internal immutable vault;
    address internal immutable owner;
    address internal immutable operator;
    address[] internal recipients;

    constructor(PatternVault vault_, address owner_, address operator_, address[] memory recipients_) {
        vault = vault_;
        owner = owner_;
        operator = operator_;
        recipients = recipients_;
    }

    function deposit(uint256 rawAmount) external {
        uint256 amount = bound(rawAmount, 1, 5 ether);
        hoax(owner, amount);

        try vault.deposit{value: amount}() {} catch {}
    }

    function queue(uint256 recipientSeed, uint256 rawAmount) external {
        address recipient = recipients[bound(recipientSeed, 0, recipients.length - 1)];
        uint256 surplus = address(vault).balance - vault.totalCredits();
        if (surplus == 0) return;

        uint256 amount = bound(rawAmount, 1, _min(surplus, 2 ether));
        vm.prank(operator);
        try vault.queuePayment(recipient, amount) {} catch {}
    }

    function withdraw(uint256 recipientSeed) external {
        address recipient = recipients[bound(recipientSeed, 0, recipients.length - 1)];
        if (vault.credits(recipient) == 0) return;

        vm.prank(recipient);
        try vault.withdraw() {} catch {}
    }

    function setDepositPaused(bool paused_) external {
        vm.prank(owner);
        try vault.setDepositPaused(paused_) {} catch {}
    }

    function setQueuePaused(bool paused_) external {
        vm.prank(owner);
        try vault.setQueuePaused(paused_) {} catch {}
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

contract PatternVaultInvariantTest is Test {
    PatternVaultFactory internal factory;
    PatternVault internal vault;
    PatternVaultHandler internal handler;

    address internal owner = address(0xA11CE);
    address internal operator = address(0xB0B);
    address internal alice = address(0x1111);
    address internal bob = address(0x2222);
    address internal carol = address(0x3333);

    function setUp() public {
        factory = new PatternVaultFactory();

        PatternVault.Config memory cfg = PatternVault.Config({
            maxBalance: uint96(100 ether),
            epochLimit: uint96(10 ether),
            epochDuration: uint32(1 hours),
            emergencyDelay: uint32(1 days)
        });

        vm.prank(owner);
        vault = PatternVault(payable(factory.createVault(cfg)));

        vm.prank(owner);
        vault.setOperator(operator, true);

        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = carol;

        handler = new PatternVaultHandler(vault, owner, operator, recipients);
        targetContract(address(handler));
    }

    function invariant_balance_covers_total_credits() public view {
        assertGe(address(vault).balance, vault.totalCredits());
    }

    function invariant_known_credits_match_total_credits() public view {
        uint256 knownCredits = vault.credits(alice) + vault.credits(bob) + vault.credits(carol);
        assertEq(knownCredits, vault.totalCredits());
    }

    function invariant_owner_and_operator_are_stable() public view {
        assertEq(vault.owner(), owner);
        assertTrue(vault.isOperator(operator));
    }
}
