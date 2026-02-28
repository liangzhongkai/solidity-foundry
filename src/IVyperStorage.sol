// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title IVyperStorage
/// @notice Interface for Vyper storage contract compatibility
interface IVyperStorage {
    function store(uint256 val) external;
    function get() external returns (uint256);
}
