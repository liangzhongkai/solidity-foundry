// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title Error
/// @notice Demo contract comparing require vs custom errors gas cost
contract Error {
    error NotAuthorized();
    error NotAuthorized_WithMessage(string message);

    /// @notice Reverts with string message (higher gas cost)
    function throwError() external pure {
        require(false, "not authorized");
    }

    /// @notice Reverts with custom error (lower gas cost)
    function throwCustomError() external pure {
        revert NotAuthorized();
    }

    /// @notice Reverts with custom error and message (lower gas cost)
    function throwCustomErrorWithMessage() external pure {
        revert NotAuthorized_WithMessage("not authorized");
    }
}
