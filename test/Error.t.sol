// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Error} from "../src/Error.sol";

contract ErrorTest is Test {
    Error public err;

    function setUp() public {
        err = new Error();
    }

    function test_Revert_ThrowError() public {
        vm.expectRevert();
        err.throwError();
    }

    function test_Revert_ThrowError_WithMessage() public {
        vm.expectRevert(bytes("not authorized"));
        err.throwError();
    }

    function test_Revert_ThrowCustomError() public {
        vm.expectRevert(Error.NotAuthorized.selector);
        err.throwCustomError();
    }

    function test_Revert_ThrowCustomError_WithMessage() public {
        vm.expectRevert(abi.encodeWithSelector(Error.NotAuthorized_WithMessage.selector, "not authorized"));
        err.throwCustomError_WithMessage();
    }

    // Add label to assertions
    function test_ErrorLabel() public pure {
        assertEq(uint256(1), uint256(1), "test 1");
        assertEq(uint256(1), uint256(1), "test 2");
        assertEq(uint256(1), uint256(1), "test 3");
        assertEq(uint256(1), uint256(1), "test 4");
        assertEq(uint256(1), uint256(1), "test 5");
    }
}
