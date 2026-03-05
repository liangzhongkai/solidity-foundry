// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {StateMachine} from "../../src/10-design-patterns/StateMachine.sol";

contract StateMachineTest is Test {
    StateMachine internal stateMachine;
    address internal owner = address(0x1);
    address internal user = address(0x2);

    function setUp() public {
        vm.prank(owner);
        stateMachine = new StateMachine();
    }

    function test_InitialState() public view {
        assertEq(uint256(stateMachine.currentState()), uint256(StateMachine.State.Pending));
    }

    function test_Activate() public {
        vm.prank(owner);
        stateMachine.activate();
        assertEq(uint256(stateMachine.currentState()), uint256(StateMachine.State.Active));
    }

    function test_ActivateUnauthorized() public {
        vm.prank(user);
        vm.expectRevert(StateMachine.Unauthorized.selector);
        stateMachine.activate();
    }

    function test_Complete() public {
        vm.prank(owner);
        stateMachine.activate();

        vm.prank(owner);
        stateMachine.complete();
        assertEq(uint256(stateMachine.currentState()), uint256(StateMachine.State.Completed));
    }

    function test_CompleteFromPendingReverts() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                StateMachine.InvalidStateTransition.selector, StateMachine.State.Pending, StateMachine.State.Active
            )
        );
        stateMachine.complete();
    }

    function test_Cancel() public {
        vm.prank(owner);
        stateMachine.cancel();
        assertEq(uint256(stateMachine.currentState()), uint256(StateMachine.State.Canceled));
    }

    function test_CancelCompletedReverts() public {
        vm.prank(owner);
        stateMachine.activate();

        vm.prank(owner);
        stateMachine.complete();

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                StateMachine.InvalidStateTransition.selector, StateMachine.State.Completed, StateMachine.State.Completed
            )
        );
        stateMachine.cancel();
    }
}
