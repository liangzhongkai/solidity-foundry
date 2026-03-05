// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Clones} from "openzeppelin-contracts@5.4.0/proxy/Clones.sol";
import {PatternVault} from "./PatternVault.sol";

/// @title PatternVaultFactory
/// @notice Contract-management pattern using EIP-1167 minimal proxies.
contract PatternVaultFactory {
    error ZeroAddress();
    error InvalidConfig();

    event VaultCreated(address indexed creator, address indexed vault, bytes32 indexed salt);

    address public immutable implementation;

    constructor() {
        implementation = address(new PatternVault());
    }

    function createVault(PatternVault.Config calldata cfg) external returns (address vault) {
        _validateConfig(cfg);

        vault = Clones.clone(implementation);
        PatternVault(payable(vault)).initialize(msg.sender, cfg);

        emit VaultCreated(msg.sender, vault, bytes32(0));
    }

    function createVaultDeterministic(PatternVault.Config calldata cfg, bytes32 salt) external returns (address vault) {
        _validateConfig(cfg);

        // Mix caller into salt to avoid front-running collisions across users.
        bytes32 mixedSalt = keccak256(abi.encode(msg.sender, salt));
        vault = Clones.cloneDeterministic(implementation, mixedSalt);
        PatternVault(payable(vault)).initialize(msg.sender, cfg);

        emit VaultCreated(msg.sender, vault, mixedSalt);
    }

    function predictVaultAddress(address creator, bytes32 salt) external view returns (address predicted) {
        if (creator == address(0)) revert ZeroAddress();
        bytes32 mixedSalt = keccak256(abi.encode(creator, salt));
        predicted = Clones.predictDeterministicAddress(implementation, mixedSalt, address(this));
    }

    function _validateConfig(PatternVault.Config calldata cfg) internal pure {
        if (cfg.maxBalance == 0 || cfg.epochDuration == 0 || cfg.emergencyDelay == 0) {
            revert InvalidConfig();
        }
    }
}
