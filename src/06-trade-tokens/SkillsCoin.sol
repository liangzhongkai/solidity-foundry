// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "../02-erc20/ERC20.sol";

/// @title SkillsCoin
/// @notice ERC-20 token that can be minted by owner. Used as the source token for trading into RareCoin.
/// @dev Fix: Added access control (Mistake #7)
contract SkillsCoin is ERC20 {
    address public owner;

    constructor() ERC20("SkillsCoin", "SKILL", 18) {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    /// @notice Mint tokens to any address. Only owner can mint.
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "mint to zero address");
        _mint(to, amount);
    }
}
