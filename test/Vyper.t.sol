// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {VyperDeployer} from "../lib/utils/VyperDeployer.sol";
import {IVyperStorage} from "../src/IVyperStorage.sol";

// source venv/bin/activate
// RUN_FFI_TESTS=true forge test --match-path test/Vyper.t.sol --ffi
contract VyperStorageTest is Test {
    VyperDeployer vyperDeployer = new VyperDeployer();

    IVyperStorage vyStorage;

    function setUp() public {
        if (!shouldRunFfiTests()) {
            vm.skip(true);
        }

        vyStorage = IVyperStorage(vyperDeployer.deployContract("VyperStorage", abi.encode(1234)));

        targetContract(address(vyStorage));
    }

    function shouldRunFfiTests() private view returns (bool) {
        bool runFfiTests = vm.envOr("RUN_FFI_TESTS", false);
        string memory profile = vm.envOr("FOUNDRY_PROFILE", string(""));
        return runFfiTests || keccak256(bytes(profile)) == keccak256(bytes("ci"));
    }

    function testGet() public {
        uint256 val = vyStorage.get();
        assertEq(val, 1234);
    }

    function testStore(uint256 val) public {
        vyStorage.store(val);
        assertEq(vyStorage.get(), val);
    }
}
