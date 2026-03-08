// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {PatternVault} from "../10-design-patterns/security/PatternVault.sol";

/// @notice Echidna harness for core PatternVault invariants.
/// The harness owns the vault, acts as operator, and exercises deposits, queueing and withdrawals.
contract PatternVaultEchidna {
    PatternVault public vault;

    constructor() payable {
        vault = new PatternVault();
        vault.initialize(
            address(this),
            PatternVault.Config({
                maxBalance: uint96(100 ether),
                epochLimit: uint96(10 ether),
                epochDuration: uint32(1 hours),
                emergencyDelay: uint32(1 days)
            })
        );
        vault.setOperator(address(this), true);
    }

    receive() external payable {}

    function deposit() external payable {
        if (msg.value == 0) return;

        try vault.deposit{value: msg.value}() {} catch {}
    }

    function queueSelf(uint96 rawAmount) external {
        uint256 surplus = address(vault).balance - vault.totalCredits();
        // slither-disable-next-line incorrect-equality -- early-exit guard: no surplus to queue
        if (surplus == 0) return;

        uint256 amount = rawAmount;
        if (amount == 0) amount = 1;
        if (amount > surplus) amount = surplus;

        try vault.queuePayment(address(this), amount) {} catch {}
    }

    function withdrawSelf() external {
        try vault.withdraw() {} catch {}
    }

    function setDepositPaused(bool paused_) external {
        try vault.setDepositPaused(paused_) {} catch {}
    }

    function setQueuePaused(bool paused_) external {
        try vault.setQueuePaused(paused_) {} catch {}
    }

    function echidna_balance_covers_liabilities() external view returns (bool) {
        return address(vault).balance >= vault.totalCredits();
    }

    function echidna_total_credits_match_self_credit() external view returns (bool) {
        return vault.totalCredits() == vault.credits(address(this));
    }

    function echidna_owner_is_stable() external view returns (bool) {
        return vault.owner() == address(this);
    }
}
