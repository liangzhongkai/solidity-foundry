// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Historical note: `public` used to be materially more expensive than `external` for some patterns.
/// @dev On modern Solidity versions the delta may be zero — measure locally.
contract RsgOut01Public {
    function f(uint256 x) public pure returns (uint256) {
        return x + 1;
    }
}

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

contract RsgOut02NeZero {
    function nz(uint256 x) external pure returns (bool) {
        return x != 0;
    }
}
