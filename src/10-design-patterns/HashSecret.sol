// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title HashSecret
/// @notice Demonstrates the Hash Secret (Commit-Reveal) access control pattern.
/// Users commit to a hash off-chain and reveal the secret on-chain later.
contract HashSecret {
    bytes32 public secretHash;
    bool public isRevealed;

    error AlreadyRevealed();
    error InvalidSecret();

    event SecretRevealed(string secret);

    constructor(bytes32 _secretHash) {
        secretHash = _secretHash;
    }

    function revealSecret(string calldata secret) external {
        if (isRevealed) revert AlreadyRevealed();
        if (keccak256(abi.encodePacked(secret)) != secretHash) revert InvalidSecret();

        isRevealed = true;
        emit SecretRevealed(secret);
    }
}
