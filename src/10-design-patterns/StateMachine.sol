// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title StateMachine
/// @notice Demonstrates the State Machine design pattern for managing contract life cycles.
contract StateMachine {
    enum State {
        Pending,
        Active,
        Completed,
        Canceled
    }
    State public currentState;

    address public owner;

    error InvalidStateTransition(State current, State required);
    error Unauthorized();

    event StateChanged(State oldState, State newState);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier inState(State required) {
        if (currentState != required) revert InvalidStateTransition(currentState, required);
        _;
    }

    constructor() {
        owner = msg.sender;
        currentState = State.Pending;
    }

    function activate() external onlyOwner inState(State.Pending) {
        _transitionTo(State.Active);
    }

    function complete() external onlyOwner inState(State.Active) {
        _transitionTo(State.Completed);
    }

    function cancel() external onlyOwner {
        if (currentState == State.Completed) revert InvalidStateTransition(currentState, State.Completed);
        _transitionTo(State.Canceled);
    }

    function _transitionTo(State newState) internal {
        emit StateChanged(currentState, newState);
        currentState = newState;
    }
}
