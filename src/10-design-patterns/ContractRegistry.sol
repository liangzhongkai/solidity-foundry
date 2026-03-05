// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title ContractRegistry
/// @notice Demonstrates the Contract Registry pattern for managing multiple contracts.
contract ContractRegistry {
    mapping(bytes32 => address) private _contracts;
    address public owner;

    error Unauthorized();
    error ContractNotFound();
    error ZeroAddress();

    event ContractRegistered(bytes32 indexed name, address indexed contractAddress);
    event ContractRemoved(bytes32 indexed name);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerContract(bytes32 name, address contractAddress) external onlyOwner {
        if (contractAddress == address(0)) revert ZeroAddress();
        _contracts[name] = contractAddress;
        emit ContractRegistered(name, contractAddress);
    }

    function removeContract(bytes32 name) external onlyOwner {
        if (_contracts[name] == address(0)) revert ContractNotFound();
        delete _contracts[name];
        emit ContractRemoved(name);
    }

    function getContract(bytes32 name) external view returns (address) {
        address contractAddress = _contracts[name];
        if (contractAddress == address(0)) revert ContractNotFound();
        return contractAddress;
    }
}
