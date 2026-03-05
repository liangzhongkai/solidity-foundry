// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// 1. Use Libraries Pattern
library MathLib {
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }
}

/// @title EfficiencyPatterns
/// @notice Demonstrates multiple efficiency patterns.
contract EfficiencyPatterns {
    using MathLib for uint256;

    // 2. Minimize on-chain data / Limit storage / Low contract footprint
    // Instead of storing a long JSON string, store an IPFS CID.
    string public dataCID;

    // 3. Tight variable packing
    struct PackedState {
        uint128 value1;
        uint64 value2;
        uint64 value3;
    }
    PackedState public packedState;

    // 4. Short constant strings / Fail early and fail loud
    // Using Custom Errors instead of revert strings saves gas and footprint.
    error InvalidInput();
    error NotParticipant();

    uint256 public accumulatedMax;

    // 5. Avoid redundant operations / Write values
    function processAndStoreMax(uint256[] calldata inputs) external {
        // Fail early
        uint256 len = inputs.length;
        if (len == 0) revert InvalidInput();

        // Avoid redundant operations: read state variable once into memory
        uint256 currentMax = accumulatedMax;

        // 6. Limit modifiers
        // We inline checks instead of creating a modifier if it's only used once, saving jump instructions.

        for (uint256 i = 0; i < len;) {
            // Use Library
            currentMax = currentMax.max(inputs[i]);
            unchecked {
                ++i;
            }
        }

        // Write values: update storage exactly once at the end
        accumulatedMax = currentMax;
    }

    function setCID(string calldata cid) external {
        dataCID = cid;
    }

    // 7. Challenge Response Pattern
    // Simplified example: Prover claims they know a pre-image.
    bytes32 public challengeHash;
    address public solver;

    function setChallenge(bytes32 hash) external {
        challengeHash = hash;
        solver = address(0);
    }

    function solveChallenge(string calldata preImage) external {
        // Fail early and loud
        if (keccak256(abi.encodePacked(preImage)) != challengeHash) revert InvalidInput();
        solver = msg.sender;
    }
}
