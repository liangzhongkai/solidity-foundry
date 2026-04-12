// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title RsgMeta
/// @notice Introductory themes from RareSkills “Book of Gas Optimization” (before numbered tips).
/// @dev These are not gas-benchmarked: they frame *when* micro-optimizations are worth measuring.
library RsgMeta {
    /// @notice “Gas optimization tricks do not always work” — measure both variants locally.
    function noteContextDependence() internal pure {}

    /// @notice “Beware of complexity and readability” — prefer clarity unless hot path proves otherwise.
    function noteReadabilityTradeoff() internal pure {}

    /// @notice “Comprehensive treatment isn’t possible here” — this repo encodes teachable surfaces only.
    function noteScopeLimit() internal pure {}

    /// @notice “Application-specific tricks” are intentionally excluded from this module.
    function noteNoAppSpecific() internal pure {}
}
