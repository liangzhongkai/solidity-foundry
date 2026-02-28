// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title PackingChallenge
/// @notice Unoptimized layout: uint128 a, uint256 b, uint128 c uses 3 slots
contract PackingChallenge {
    uint128 public a = 1;
    uint256 public b = 2;
    uint128 public c = 3;
}
