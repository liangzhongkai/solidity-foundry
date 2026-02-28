// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {console} from "forge-std@1.14.0/console.sol";

/// @title Counter
/// @notice Simple counter with increment/decrement
contract Counter {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        console.log("increment", number);
        number++;
    }

    function decrement() public {
        console.log("decrement", number);
        if (number == 0) {
            revert("number cannot go below zero");
        }
        number--;
    }
}
