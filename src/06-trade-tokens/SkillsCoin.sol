// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "../02-erc20/ERC20.sol";

/// @title SkillsCoin
/// @notice ERC-20 token that anyone can mint. Used as the source token for trading into RareCoin.
contract SkillsCoin is ERC20 {
    constructor() ERC20("SkillsCoin", "SKILL", 18) {}

    /// @notice Mint tokens to any address. No access control - anyone can mint.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
