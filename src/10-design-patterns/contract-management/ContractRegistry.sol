// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title ContractRegistry
/// @notice Delayed-activation registry for safer address rotations.
contract ContractRegistry {
    struct Entry {
        address current;
        address pending;
        uint64 activateAfter;
        uint64 version;
    }

    mapping(bytes32 => Entry) private _entries;
    address public immutable owner;
    uint64 public immutable activationDelay;

    error Unauthorized();
    error ContractNotFound();
    error ZeroAddress();
    error ActivationNotReady(uint256 currentTime, uint256 activateAfter);

    event ContractRegistrationScheduled(bytes32 indexed name, address indexed contractAddress, uint64 activateAfter);
    event ContractActivated(bytes32 indexed name, address indexed contractAddress, uint64 version);
    event ContractRemoved(bytes32 indexed name, uint64 version);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(uint64 activationDelay_) {
        owner = msg.sender;
        activationDelay = activationDelay_;
    }

    function registerContract(bytes32 name, address contractAddress) external onlyOwner {
        if (contractAddress == address(0)) revert ZeroAddress();

        uint64 activateAfter = uint64(block.timestamp) + activationDelay;
        Entry storage entry = _entries[name];
        entry.pending = contractAddress;
        entry.activateAfter = activateAfter;

        emit ContractRegistrationScheduled(name, contractAddress, activateAfter);
    }

    function activateContract(bytes32 name) external {
        Entry storage entry = _entries[name];
        if (entry.pending == address(0)) revert ContractNotFound();
        if (block.timestamp < entry.activateAfter) {
            revert ActivationNotReady(block.timestamp, entry.activateAfter);
        }

        entry.current = entry.pending;
        entry.pending = address(0);
        entry.activateAfter = 0;
        entry.version += 1;

        emit ContractActivated(name, entry.current, entry.version);
    }

    function removeContract(bytes32 name) external onlyOwner {
        Entry storage entry = _entries[name];
        if (entry.current == address(0) && entry.pending == address(0)) revert ContractNotFound();

        uint64 version = entry.version;
        delete _entries[name];
        emit ContractRemoved(name, version);
    }

    function getContract(bytes32 name) external view returns (address) {
        address contractAddress = _entries[name].current;
        if (contractAddress == address(0)) revert ContractNotFound();
        return contractAddress;
    }

    function getEntry(bytes32 name) external view returns (Entry memory) {
        return _entries[name];
    }
}
