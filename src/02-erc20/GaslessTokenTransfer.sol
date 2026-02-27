// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20Permit} from "./IERC20Permit.sol";

contract GaslessTokenTransfer {
    function send(
        address token,
        address sender,
        address receiver,
        uint256 amount,
        uint256 fee,
        uint256 deadline,
        // Permit signature
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
