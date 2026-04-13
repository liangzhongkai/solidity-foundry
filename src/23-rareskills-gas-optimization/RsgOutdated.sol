// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Historical note: `public` used to be materially more expensive than `external` for some patterns.
/// @dev On modern Solidity versions the delta may be zero — measure locally.
contract RsgOut01Public {
    function f(uint256 x) public pure returns (uint256) {
        return x + 1;
    }
}

/// @notice Historically `external` could avoid some wrapper overhead, though modern compilers often erase the gap.
contract RsgOut01External {
    function f(uint256 x) external pure returns (uint256) {
        return x + 1;
    }
}

/// @notice Historical note: `> 0` vs `!= 0` for unsigned integers.
/// @dev Optimizer behavior changes over time — benchmark instead of assuming.
contract RsgOut02GtZero {
    function nz(uint256 x) external pure returns (bool) {
        return x > 0;
    }
}

/// @notice Historical micro-optimization: `!= 0` sometimes compiled to a slightly cheaper unsigned zero check.
contract RsgOut02NeZero {
    function nz(uint256 x) external pure returns (bool) {
        return x != 0;
    }
}
