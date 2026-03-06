// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library MathLib {
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }
}

/// @title EfficiencyPatterns
/// @notice Demonstrates modern gas-aware patterns: packed storage, minimal metadata, single-write updates and
///         challenge-response with compact state.
contract EfficiencyPatterns {
    using MathLib for uint256;

    struct PackedState {
        uint128 value1;
        uint64 value2;
        uint64 value3;
    }

    struct ChallengeConfig {
        bytes32 challengeHash;
        uint64 deadline;
        address solver;
    }

    bytes32 public metadataRoot;
    PackedState public packedState;
    ChallengeConfig public challenge;
    uint256 public accumulatedMax;

    error InvalidInput();
    error ChallengeExpired(uint256 currentTime, uint256 deadline);
    error ChallengeAlreadySolved();
    error ChallengeNotSet();

    event MetadataRootUpdated(bytes32 indexed metadataRoot);
    event PackedStateUpdated(uint128 value1, uint64 value2, uint64 value3);
    event ChallengeSet(bytes32 indexed challengeHash, uint64 deadline);
    event ChallengeSolved(address indexed solver, bytes32 indexed challengeHash);

    function setMetadataRoot(bytes32 metadataRoot_) external {
        metadataRoot = metadataRoot_;
        emit MetadataRootUpdated(metadataRoot_);
    }

    function setPackedState(uint128 value1, uint64 value2, uint64 value3) external {
        packedState = PackedState({value1: value1, value2: value2, value3: value3});
        emit PackedStateUpdated(value1, value2, value3);
    }

    function processAndStoreMax(uint256[] calldata inputs) external {
        uint256 len = inputs.length;
        if (len == 0) revert InvalidInput();

        uint256 currentMax = accumulatedMax;
        for (uint256 i = 0; i < len;) {
            currentMax = currentMax.max(inputs[i]);
            unchecked {
                ++i;
            }
        }

        accumulatedMax = currentMax;
    }

    function setChallenge(bytes32 challengeHash, uint64 deadline) external {
        if (challengeHash == bytes32(0) || deadline <= block.timestamp) revert InvalidInput();

        challenge = ChallengeConfig({challengeHash: challengeHash, deadline: deadline, solver: address(0)});
        emit ChallengeSet(challengeHash, deadline);
    }

    function solveChallenge(bytes calldata preImage) external {
        ChallengeConfig memory current = challenge;
        if (current.challengeHash == bytes32(0)) revert ChallengeNotSet();
        if (current.solver != address(0)) revert ChallengeAlreadySolved();
        if (block.timestamp > current.deadline) revert ChallengeExpired(block.timestamp, current.deadline);
        if (keccak256(preImage) != current.challengeHash) revert InvalidInput();

        challenge.solver = msg.sender;
        emit ChallengeSolved(msg.sender, current.challengeHash);
    }
}
