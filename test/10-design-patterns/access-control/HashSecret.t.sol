// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {HashSecret} from "../../../src/10-design-patterns/access-control/HashSecret.sol";

contract HashSecretTest is Test {
    HashSecret internal hashSecret;
    address internal revealer = address(0xBEEF);
    bytes internal secret = bytes("my_super_secret");
    bytes32 internal salt = keccak256("salt");
    bytes32 internal secretHash;

    function setUp() public {
        secretHash = keccak256(secret);
        uint64 revealAfter = uint64(block.timestamp + 1 hours);
        uint64 expiresAt = uint64(block.timestamp + 1 days);
        bytes32 commitment = keccak256(abi.encode(revealer, secretHash, salt));
        hashSecret = new HashSecret(revealer, commitment, revealAfter, expiresAt);
    }

    function test_RevealSecret() public {
        vm.warp(block.timestamp + 1 hours);
        vm.prank(revealer);
        hashSecret.reveal(secret, salt);
        assertTrue(hashSecret.isRevealed());
    }

    function test_RevealSecretInvalid() public {
        vm.warp(block.timestamp + 1 hours);
        vm.expectRevert(HashSecret.InvalidReveal.selector);
        vm.prank(revealer);
        hashSecret.reveal(bytes("wrong_secret"), salt);
    }

    function test_RevealSecretAlreadyRevealed() public {
        vm.warp(block.timestamp + 1 hours);
        vm.prank(revealer);
        hashSecret.reveal(secret, salt);

        vm.expectRevert(HashSecret.AlreadyRevealed.selector);
        vm.prank(revealer);
        hashSecret.reveal(secret, salt);
    }

    function test_RevealSecretTooEarly() public {
        vm.expectRevert(
            abi.encodeWithSelector(HashSecret.RevealNotStarted.selector, block.timestamp, block.timestamp + 1 hours)
        );
        vm.prank(revealer);
        hashSecret.reveal(secret, salt);
    }
}
