// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ECDSA} from "openzeppelin-contracts@5.4.0/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "openzeppelin-contracts@5.4.0/utils/cryptography/MerkleProof.sol";

/// @notice RareSkills: batch delegatecall helper pattern (multidelegatecall sketch).
contract RsgDesign01MultiDelegate {
    function multiDelegatecall(address[] calldata targets, bytes[] calldata data)
        external
        returns (bytes[] memory results)
    {
        require(targets.length == data.length, "len");
        results = new bytes[](data.length);
        for (uint256 i = 0; i < targets.length; i++) {
            (bool ok, bytes memory ret) = targets[i].delegatecall(data[i]);
            require(ok, "dc");
            results[i] = ret;
        }
    }
}

// --- #2 merkle allowlist vs ECDSA allowlist (fixed-size demo) ---

/// @notice A shared Merkle root lets each claimant prove inclusion with hashes instead of paying for signature recovery.
/// @dev Whether this wins depends on proof depth, but short proofs often beat `ecrecover`-based checks.
contract RsgDesign02Merkle {
    bytes32 public root;

    constructor(bytes32 _root) {
        root = _root;
    }

    function isAllowed(bytes32[] calldata proof, bytes32 leaf) external view returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }
}

contract RsgDesign02Ecdsa {
    address public signer;

    constructor(address _signer) {
        signer = _signer;
    }

    function isAllowed(bytes32 digest, bytes calldata sig) external view returns (bool) {
        return ECDSA.recover(digest, sig) == signer;
    }
}
