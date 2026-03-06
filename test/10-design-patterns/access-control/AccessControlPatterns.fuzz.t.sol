// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {EmbeddedPermission} from "../../../src/10-design-patterns/access-control/AccessControlPatterns.sol";

contract ERC1271FuzzSigner {
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    address public immutable owner;

    constructor(address owner_) {
        owner = owner_;
    }

    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4) {
        if (signature.length != 65) {
            return bytes4(0);
        }

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        return ecrecover(hash, v, r, s) == owner ? MAGICVALUE : bytes4(0);
    }
}

contract AccessControlPatternsFuzzTest is Test {
    EmbeddedPermission internal perm;
    ERC1271FuzzSigner internal contractSigner;
    address internal signerOwner;
    uint256 internal signerOwnerPk;

    function setUp() public {
        perm = new EmbeddedPermission();
        (signerOwner, signerOwnerPk) = makeAddrAndKey("erc1271-fuzz-owner");
        contractSigner = new ERC1271FuzzSigner(signerOwner);
    }

    function testFuzz_EmbeddedPermission_ERC1271AcceptsValidSignature(bytes32 actionHash, uint32 ttl) public {
        uint256 deadline = block.timestamp + bound(uint256(ttl), 1, 30 days);
        uint256 nonce = perm.nonces(address(contractSigner));
        bytes32 digest = perm.permissionDigest(address(contractSigner), actionHash, nonce, deadline);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerOwnerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        perm.executeWithSignature(address(contractSigner), actionHash, deadline, signature);

        assertEq(perm.nonces(address(contractSigner)), nonce + 1);
    }

    function testFuzz_EmbeddedPermission_ERC1271RejectsTamperedAction(
        bytes32 actionHash,
        bytes32 otherActionHash,
        uint32 ttl
    ) public {
        vm.assume(actionHash != otherActionHash);

        uint256 deadline = block.timestamp + bound(uint256(ttl), 1, 30 days);
        uint256 nonce = perm.nonces(address(contractSigner));
        bytes32 digest = perm.permissionDigest(address(contractSigner), actionHash, nonce, deadline);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerOwnerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(EmbeddedPermission.InvalidSignature.selector);
        perm.executeWithSignature(address(contractSigner), otherActionHash, deadline, signature);
    }
}
