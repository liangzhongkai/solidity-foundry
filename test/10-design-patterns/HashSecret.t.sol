// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {HashSecret} from "../../src/10-design-patterns/HashSecret.sol";

contract HashSecretTest is Test {
    HashSecret internal hashSecret;
    string internal secret = "my_super_secret";
    bytes32 internal secretHash;

    function setUp() public {
        secretHash = keccak256(abi.encodePacked(secret));
        hashSecret = new HashSecret(secretHash);
    }

    function test_RevealSecret() public {
        hashSecret.revealSecret(secret);
        assertTrue(hashSecret.isRevealed());
    }

    function test_RevealSecretInvalid() public {
        vm.expectRevert(HashSecret.InvalidSecret.selector);
        hashSecret.revealSecret("wrong_secret");
    }

    function test_RevealSecretAlreadyRevealed() public {
        hashSecret.revealSecret(secret);
        vm.expectRevert(HashSecret.AlreadyRevealed.selector);
        hashSecret.revealSecret(secret);
    }
}
