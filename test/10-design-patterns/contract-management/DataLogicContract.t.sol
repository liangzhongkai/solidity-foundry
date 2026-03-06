// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {DataContract, LogicContract} from "../../../src/10-design-patterns/contract-management/DataLogicContract.sol";

contract DataLogicContractTest is Test {
    DataContract internal dataContract;
    LogicContract internal logicContract;

    function setUp() public {
        dataContract = new DataContract();
        logicContract = new LogicContract(address(dataContract));
        dataContract.setLogicContract(address(logicContract));
    }

    function test_ProcessAndSave() public {
        logicContract.processAndSave(5);
        assertEq(dataContract.data(), 10);
    }

    function test_DirectSetDataReverts() public {
        vm.expectRevert(DataContract.Unauthorized.selector);
        dataContract.setData(10);
    }
}
