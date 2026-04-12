// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title RsgDanger
/// @notice RareSkills “dangerous techniques” section — **documented anti-patterns only**.
/// @dev Never ship these ideas to production; they break composability, safety, or audit expectations.
library RsgDanger {
    /// @notice `tx.gasprice` / `msg.value` as implicit data channels.
    function warnGaspriceMsgValueChannels() internal pure {}

    /// @notice Manipulating `block.coinbase`, `block.number`, etc. when tests allow it.
    function warnEnvManipulation() internal pure {}

    /// @notice Branching on `gasleft()` mid-execution.
    function warnGasleftBranching() internal pure {}

    /// @notice `send` / unchecked low-level ETH transfers.
    function warnUncheckedSend() internal pure {}

    /// @notice Making unrelated functions `payable` to shave opcode checks.
    function warnBlanketPayable() internal pure {}

    /// @notice External library “jumping” tricks that confuse control-flow analysis.
    function warnExternalLibJumping() internal pure {}

    /// @notice Appending bytecode blobs as hand-optimized subroutines.
    function warnAppendedBytecode() internal pure {}
}
