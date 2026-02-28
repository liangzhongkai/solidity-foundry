// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title PackingChallengeOptimized
/// @notice Optimized layout: uint128 a, uint128 c, uint256 b uses 2 slots
contract PackingChallengeOptimized {
    uint128 public a = 1;
    uint128 public c = 3;
    uint256 public b = 2;
}
