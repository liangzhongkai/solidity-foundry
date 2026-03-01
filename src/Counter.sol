// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {console} from "forge-std@1.14.0/console.sol";

/// @title Counter
/// @notice Simple counter with increment/decrement
contract Counter {
    uint256 public number;

    /// @dev Fix: Added events (Mistake #13)
    event NumberSet(uint256 oldValue, uint256 newValue);
    event Incremented(uint256 newValue);
    event Decremented(uint256 newValue);

    function setNumber(uint256 newNumber) public {
        emit NumberSet(number, newNumber);
        number = newNumber;
    }

    function increment() public {
        console.log("increment", number);
        number++;
        emit Incremented(number);
    }

    function decrement() public {
        console.log("decrement", number);
        if (number == 0) {
            revert("number cannot go below zero");
        }
        number--;
        emit Decremented(number);
    }
}
