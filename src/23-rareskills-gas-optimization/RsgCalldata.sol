// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Signed integer ABI encoding is wider; prefer unsigned flags when possible.
contract RsgCalldata02Signed {
    function sum(int256 a, int256 b) external pure returns (int256) {
        return a + b;
    }
}

/// @notice Unsigned values avoid the sign-extension semantics that can add extra work in some calldata-heavy paths.
contract RsgCalldata02Unsigned {
    function sum(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }
}

/// @notice Copying dynamic calldata into memory costs extra `CALLDATACOPY`.
contract RsgCalldata03MemoryCopy {
    function hash(bytes memory data) external pure returns (bytes32) {
        return keccak256(data);
    }
}

/// @notice Hash calldata in place so the function avoids allocating memory and copying the payload first.
contract RsgCalldata03CalldataSlice {
    function hash(bytes calldata data) external pure returns (bytes32) {
        return keccak256(data);
    }
}
