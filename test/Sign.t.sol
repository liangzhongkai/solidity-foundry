// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";

contract SignTest is Test {
    // private key = 123
    // public key = vm.addr(private key)
    // message = "secret message"
    // message hash = keccak256(message)
    // vm.sign(private key, message hash)
    function test_Signature() public pure {
        uint256 privateKey = 123;
        // Computes the address for a given private key.
        address kevin = vm.addr(privateKey);

        // Test valid signature
        bytes32 messageHash = keccak256("Signed by Kevin");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        address signer = ecrecover(messageHash, v, r, s);

        assertEq(signer, kevin);

        // Test invalid message
        bytes32 invalidHash = keccak256("Not signed by Kevin");
        signer = ecrecover(invalidHash, v, r, s);

        assertTrue(signer != kevin);
    }
}
