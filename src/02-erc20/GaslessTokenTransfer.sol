// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20Permit} from "./IERC20Permit.sol";

/// @title GaslessTokenTransfer
/// @notice Enables gasless token transfer via EIP-2612 permit
/// @dev Relayer pays gas; sender signs permit
contract GaslessTokenTransfer {
    /// @notice Execute permit-backed transfer with fee
    /// @param token ERC20 permit token address
    /// @param sender Token owner (signer)
    /// @param receiver Recipient of amount
    /// @param amount Amount to transfer
    /// @param fee Fee to relayer (msg.sender)
    /// @param deadline Permit deadline
    /// @param v,r,s Permit signature
    function send(
        address token,
        address sender,
        address receiver,
        uint256 amount,
        uint256 fee,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Permit
        IERC20Permit(token).permit(sender, address(this), amount + fee, deadline, v, r, s);
        // Send amount to receiver
        require(IERC20Permit(token).transferFrom(sender, receiver, amount), "transfer failed");
        // Take fee - send fee to msg.sender
        require(IERC20Permit(token).transferFrom(sender, msg.sender, fee), "transfer failed");
    }
}
