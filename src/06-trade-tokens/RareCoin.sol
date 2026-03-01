// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "../02-erc20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title RareCoin
/// @notice ERC-20 token obtainable only by trading SkillsCoin. The only way to get RareCoin
///         is to send SkillsCoin to this contract via trade().
/// @dev Fix: Using SafeERC20 for token transfers (Mistake #5)
contract RareCoin is ERC20 {
    using SafeERC20 for IERC20;

    /// @notice The SkillsCoin contract address. RareCoin pulls SkillsCoin from users via transferFrom.
    IERC20 public immutable source;

    constructor(address _source) ERC20("RareCoin", "RARE", 18) {
        source = IERC20(_source);
    }

    /// @notice Trade SkillsCoin for RareCoin. Transfers `amount` SkillsCoin from msg.sender
    ///         to this contract and mints `amount` RareCoin to msg.sender.
    /// @param amount Amount of SkillsCoin to trade (and RareCoin to receive)
    function trade(uint256 amount) external {
        // Fix: Use safeTransferFrom instead of low-level call (Mistake #5)
        source.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }
}
