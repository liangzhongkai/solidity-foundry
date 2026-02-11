// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract Error {
    error NotAuthorized();
    error NotAuthorized_WithMessage(string message);

    function throwError() external pure {
        require(false, "not authorized"); // 消耗大 gas
    }

    function throwCustomError() external pure {
        revert NotAuthorized(); // 消耗小
    }

    function throwCustomError_WithMessage() external pure {
        revert NotAuthorized_WithMessage("not authorized"); // 消耗小
    }
}
