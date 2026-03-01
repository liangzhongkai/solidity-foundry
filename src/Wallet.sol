// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title Wallet
/// @notice Simple Ether wallet with owner-controlled withdraw
contract Wallet {
    address payable public owner;

    event Deposit(address account, uint256 amount);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event Withdrawal(address indexed to, uint256 amount);

    constructor() payable {
        owner = payable(msg.sender);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Withdraw Ether to caller (must be owner)
    function withdraw(uint256 _amount) external {
        require(msg.sender == owner, "caller is not owner in withdraw");
        // Fix: Use call instead of transfer (Mistake #3)
        (bool ok,) = msg.sender.call{value: _amount}("");
        require(ok, "transfer failed");
        emit Withdrawal(msg.sender, _amount);
    }

    /// @notice Transfer ownership to new address
    function setOwner(address _owner) external {
        require(msg.sender == owner, "caller is not owner in setOwner");
        // Fix: Check for zero address (Mistake #9)
        require(_owner != address(0), "invalid owner address");
        emit OwnerChanged(owner, _owner);
        owner = payable(_owner);
    }
}
