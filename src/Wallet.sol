// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title Wallet
/// @notice Simple Ether wallet with owner-controlled withdraw
contract Wallet {
    address payable public owner;

    event Deposit(address account, uint256 amount);

    constructor() payable {
        owner = payable(msg.sender);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Withdraw Ether to caller (must be owner)
    function withdraw(uint256 _amount) external {
        require(msg.sender == owner, "caller is not owner in withdraw");
        payable(msg.sender).transfer(_amount);
    }

    /// @notice Transfer ownership to new address
    function setOwner(address _owner) external {
        require(msg.sender == owner, "caller is not owner in setOwner");
        owner = payable(_owner);
    }
}
