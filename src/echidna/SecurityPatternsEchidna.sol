// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SecurityPatterns} from "../10-design-patterns/security/SecurityPatterns.sol";

/// @notice Echidna harness for core SecurityPatterns invariants.
/// The harness is both owner and guardian to explore pause/queue/termination paths.
contract SecurityPatternsEchidna {
    SecurityPatterns public sec;

    constructor() payable {
        sec = new SecurityPatterns(
            address(this),
            SecurityPatterns.Config({
                balanceCap: uint96(100 ether),
                epochLimit: uint96(10 ether),
                epochDuration: uint64(1 hours),
                withdrawalDelay: uint64(1 days),
                terminateDelay: uint64(2 days),
                deprecationTime: uint64(block.timestamp + 365 days)
            })
        );
    }

    receive() external payable {}

    function deposit() external payable {
        if (msg.value == 0) return;
        try sec.deposit{value: msg.value}() {} catch {}
    }

    function queueSelf(uint96 rawAmount) external {
        uint256 surplus = address(sec).balance - sec.totalLiabilities();
        // slither-disable-next-line incorrect-equality -- early-exit guard: no surplus
        if (surplus == 0) return;

        uint256 amount = rawAmount;
        if (amount == 0) amount = 1;
        if (amount > surplus) amount = surplus;

        try sec.queueWithdrawal(address(this), amount) {} catch {}
    }

    function withdrawSelf() external {
        try sec.withdraw() {} catch {}
    }

    function setPauseFlags(uint8 flags) external {
        try sec.setPauseFlags(flags % 4) {} catch {}
    }

    function scheduleTermination() external {
        try sec.scheduleTermination() {} catch {}
    }

    function terminate(uint96 rawAmount) external {
        uint256 surplus = address(sec).balance - sec.totalLiabilities();
        // slither-disable-next-line incorrect-equality -- early-exit guard: no surplus
        if (surplus == 0) return;

        uint256 amount = rawAmount;
        if (amount == 0) amount = 1;
        if (amount > surplus) amount = surplus;

        try sec.terminateAndSweep(payable(address(this)), amount) {} catch {}
    }

    function echidna_balance_covers_liabilities() external view returns (bool) {
        return address(sec).balance >= sec.totalLiabilities();
    }

    function echidna_terminated_has_no_liabilities() external view returns (bool) {
        // slither-disable-next-line incorrect-equality -- invariant: terminated implies zero liabilities
        return !sec.isTerminated() || sec.totalLiabilities() == 0;
    }

    function echidna_owner_and_guardian_are_stable() external view returns (bool) {
        return sec.owner() == address(this) && sec.guardian() == address(this);
    }
}
