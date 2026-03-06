// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title HashSecret
/// @notice Production-style commit-reveal pattern with scoped revealer and reveal window.
contract HashSecret {
    address public immutable revealer;
    bytes32 public immutable commitment;
    uint64 public immutable revealAfter;
    uint64 public immutable expiresAt;
    bool public isRevealed;

    error AlreadyRevealed();
    error InvalidReveal();
    error Unauthorized();
    error RevealNotStarted(uint256 currentTime, uint256 revealAfter);
    error RevealExpired(uint256 currentTime, uint256 expiresAt);
    error InvalidConfig();

    event SecretRevealed(address indexed revealer, bytes32 indexed secretHash);

    constructor(address revealer_, bytes32 commitment_, uint64 revealAfter_, uint64 expiresAt_) {
        if (revealer_ == address(0) || commitment_ == bytes32(0) || revealAfter_ >= expiresAt_) revert InvalidConfig();

        revealer = revealer_;
        commitment = commitment_;
        revealAfter = revealAfter_;
        expiresAt = expiresAt_;
    }

    function computeCommitment(address revealer_, bytes32 secretHash, bytes32 salt) public pure returns (bytes32) {
        return keccak256(abi.encode(revealer_, secretHash, salt));
    }

    function reveal(bytes calldata secret, bytes32 salt) external {
        if (msg.sender != revealer) revert Unauthorized();
        if (isRevealed) revert AlreadyRevealed();
        if (block.timestamp < revealAfter) revert RevealNotStarted(block.timestamp, revealAfter);
        if (block.timestamp > expiresAt) revert RevealExpired(block.timestamp, expiresAt);

        bytes32 secretHash = keccak256(secret);
        if (computeCommitment(msg.sender, secretHash, salt) != commitment) revert InvalidReveal();

        isRevealed = true;
        emit SecretRevealed(msg.sender, secretHash);
    }
}
