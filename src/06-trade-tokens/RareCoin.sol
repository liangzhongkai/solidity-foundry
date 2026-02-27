// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "../02-erc20/ERC20.sol";

/// @title RareCoin
/// @notice ERC-20 token obtainable only by trading SkillsCoin. The only way to get RareCoin
///         is to send SkillsCoin to this contract via trade().
contract RareCoin is ERC20 {
    /// @notice The SkillsCoin contract address. RareCoin pulls SkillsCoin from users via transferFrom.
    address public immutable source;

    constructor(address _source) ERC20("RareCoin", "RARE", 18) {
        source = _source;
    }

    /// @notice Trade SkillsCoin for RareCoin. Transfers `amount` SkillsCoin from msg.sender
    ///         to this contract and mints `amount` RareCoin to msg.sender.
    /// @param amount Amount of SkillsCoin to trade (and RareCoin to receive)
    function trade(uint256 amount) external {
        (bool ok,) = source.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount)
        );
        require(ok, "call failed");
        _mint(msg.sender, amount);
    }
}
