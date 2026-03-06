// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {EfficiencyPatterns} from "../../../src/10-design-patterns/efficiency/EfficiencyPatterns.sol";

contract EfficiencyPatternsTest is Test {
    EfficiencyPatterns internal eff;

    function setUp() public {
        eff = new EfficiencyPatterns();
    }

    function test_SetMetadataRoot() public {
        bytes32 root = keccak256("ipfs://metadata-root");
        eff.setMetadataRoot(root);
        assertEq(eff.metadataRoot(), root);
    }

    function test_SetPackedState() public {
        eff.setPackedState(11, 22, 33);

        (uint128 value1, uint64 value2, uint64 value3) = eff.packedState();
        assertEq(value1, 11);
        assertEq(value2, 22);
        assertEq(value3, 33);
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
        bytes memory secret = bytes("mySecret");
        bytes32 hash = keccak256(secret);
        uint64 deadline = uint64(block.timestamp + 1 hours);

        eff.setChallenge(hash, deadline);
        eff.solveChallenge(secret);

        (, uint64 storedDeadline, address solver) = eff.challenge();
        assertEq(storedDeadline, deadline);
        assertEq(solver, address(this));
    }

    function test_ChallengeResponse_ExpiredReverts() public {
        bytes memory secret = bytes("mySecret");
        uint64 deadline = uint64(block.timestamp + 10);
        eff.setChallenge(keccak256(secret), deadline);

        vm.warp(deadline + 1);
        vm.expectRevert(abi.encodeWithSelector(EfficiencyPatterns.ChallengeExpired.selector, deadline + 1, deadline));
        eff.solveChallenge(secret);
    }
}
