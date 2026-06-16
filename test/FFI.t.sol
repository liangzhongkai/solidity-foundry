// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {console} from "forge-std@1.14.0/console.sol";

// RUN_FFI_TESTS=true forge test --match-path test/FFI.t.sol --ffi -vvvv

contract FFITest is Test {
    function testFFI() public {
        if (!vm.envOr("RUN_FFI_TESTS", false)) return;

        string memory path = string.concat(vm.projectRoot(), "/remappings.txt");
        string[] memory cmds = new string[](2);
        cmds[0] = "cat";
        cmds[1] = path;
        bytes memory res = vm.ffi(cmds);
        console.log(string(res));
    }
}
