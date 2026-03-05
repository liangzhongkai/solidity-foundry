// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title AutoDeprecation
/// @notice Demonstrates the Auto Deprecation security pattern.
/// The contract automatically disables its core functionality after a certain time,
/// forcing users to migrate to a newer version and reducing the risk of old bugs.
contract AutoDeprecation {
    uint256 public immutable expiresAt;

    error ContractDeprecated();

    modifier notDeprecated() {
        if (block.timestamp >= expiresAt) revert ContractDeprecated();
        _;
    }

    constructor(uint256 _validityDuration) {
        expiresAt = block.timestamp + _validityDuration;
    }

    function doAction() external view notDeprecated returns (bool) {
        return true;
    }
}
