// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {EfficiencyPatterns} from "../../src/10-design-patterns/EfficiencyPatterns.sol";

contract EfficiencyPatternsTest is Test {
    EfficiencyPatterns internal eff;

    function setUp() public {
        eff = new EfficiencyPatterns();
    }

    function test_SetCID() public {
        string memory cid = "Qm123456";
        eff.setCID(cid);
        assertEq(eff.dataCID(), cid);
    }

    function test_ProcessAndStoreMax() public {
        uint256[] memory data = new uint256[](3);
        data[0] = 5;
        data[1] = 15;
        data[2] = 10;

        eff.processAndStoreMax(data);
        assertEq(eff.accumulatedMax(), 15);

        data[0] = 20;
        eff.processAndStoreMax(data);
        assertEq(eff.accumulatedMax(), 20);
    }

    function test_ProcessEmptyReverts() public {
        uint256[] memory empty = new uint256[](0);
        vm.expectRevert(EfficiencyPatterns.InvalidInput.selector);
        eff.processAndStoreMax(empty);
    }

    function test_ChallengeResponse() public {
        string memory secret = "mySecret";
        bytes32 hash = keccak256(abi.encodePacked(secret));

        eff.setChallenge(hash);
        eff.solveChallenge(secret);

        assertEq(eff.solver(), address(this));
    }
}
