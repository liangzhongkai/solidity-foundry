// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20Permit} from "./IERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title GaslessTokenTransfer
/// @notice Enables gasless token transfer via EIP-2612 permit
/// @dev Relayer pays gas; sender signs permit
/// @dev Fix: Using SafeERC20 for token transfers (Mistake #5)
contract GaslessTokenTransfer {
    using SafeERC20 for IERC20;

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
        // Send amount to receiver - Fix: Use safeTransferFrom (Mistake #5)
        IERC20(token).safeTransferFrom(sender, receiver, amount);
        // Take fee - send fee to msg.sender - Fix: Use safeTransferFrom (Mistake #5)
        IERC20(token).safeTransferFrom(sender, msg.sender, fee);
    }
}
