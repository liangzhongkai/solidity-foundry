// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {console} from "forge-std@1.14.0/console.sol";
import {exp} from "../src/Exp.sol";
import {Strings} from "openzeppelin-contracts@5.4.0/utils/Strings.sol";

// FOUNDRY_FUZZ_RUNS=100 forge test --match-path test/DifferentialTest.t.sol --ffi -vvv

contract DifferentialTest is Test {
    using Strings for uint256;

    uint256 private constant DELTA = 2 ** 64;

    function setUp() public {}

    function ffi_exp(int128 x) private returns (int128) {
        require(x >= 0, "x < 0");

        string[] memory inputs = new string[](3);
        inputs[0] = "python";
        inputs[1] = "exp.py";
        inputs[2] = uint256(int256(x)).toString();

        bytes memory res = vm.ffi(inputs);
        int128 y = abi.decode(res, (int128));

        return y;
    }

    function test_exp(int128 x) public {
        // 2**64 = 1 (64.64 bit number)
        vm.assume(x >= 2 ** 64);
        vm.assume(x <= 20 * 2 ** 64);

        int128 y0 = ffi_exp(x);
        int128 y1 = exp(x);
        console.log("y0", y0);
        console.log("y1", y1);

        assertApproxEqAbs(uint256(int256(y0)), uint256(int256(y1)), DELTA);
    }
}
