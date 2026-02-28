// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {console} from "forge-std@1.14.0/console.sol";
import {WETH} from "../src/WETH.sol";

// https://book.getfoundry.sh/forge/invariant-testing?highlight=targetSelector#invariant-targets
// https://mirror.xyz/horsefacts.eth/Jex2YVaO65dda6zEyfM_-DXlXhOWCAoSpOx5PLocYgw

// NOTE: open testing - randomly call all public functions
contract WETH_Open_Invariant_Tests is Test {
    WETH public weth;

    function setUp() public {
        weth = new WETH();
    }

    receive() external payable {}

    // NOTE: - calls = runs x depth, (runs, calls, reverts)
    function invariant_totalSupply_is_always_zero() public view {
        assertEq(0, weth.totalSupply());
    }
}
