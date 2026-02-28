// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {VyperDeployer} from "../lib/utils/VyperDeployer.sol";
import {IVyperStorage} from "../src/IVyperStorage.sol";

// source venv/bin/activate
// forge test --match-path test/Vyper.t.sol --ffi
contract VyperStorageTest is Test {
    VyperDeployer vyperDeployer = new VyperDeployer();

    IVyperStorage vyStorage;

    function setUp() public {
        vyStorage = IVyperStorage(vyperDeployer.deployContract("VyperStorage", abi.encode(1234)));

        targetContract(address(vyStorage));
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
