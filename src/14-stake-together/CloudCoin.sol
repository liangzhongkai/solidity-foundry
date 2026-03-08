// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/ERC20.sol";

/// @title CloudCoin
/// @notice ERC20 token used for StakeTogether staking and rewards.
contract CloudCoin is ERC20 {
    constructor() ERC20("Cloud Coin", "CLOUD") {
        _mint(msg.sender, 10_000_000 * 10 ** 18);
    }

    /// @notice Mint tokens for testing or initial distribution.
    /// @param to Recipient address.
    /// @param amount Amount to mint.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
