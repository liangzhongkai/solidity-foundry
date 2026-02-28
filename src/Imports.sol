// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "solmate@6.8.0/tokens/ERC20.sol";
import {Ownable} from "openzeppelin-contracts@5.4.0/access/Ownable.sol";

/// @title MyERC20 - Demo ERC20 token
/// @notice Mints INITIAL_SUPPLY tokens to deployer on construction
contract MyERC20 is ERC20 {
    uint256 private constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    constructor() ERC20("MyERC20", "MYE", 18) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}

/// @title TestOwnable - Demo Ownable contract
/// @notice Simple wrapper for testing Ownable functionality
contract TestOwnable is Ownable {
    constructor() Ownable(msg.sender) {}
}
