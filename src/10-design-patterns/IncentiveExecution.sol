// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title IncentiveExecution
/// @notice Demonstrates the Incentive Execution efficiency pattern.
/// Rewards external callers for executing routine maintenance tasks,
/// saving the protocol from having to run centralized cron jobs.
contract IncentiveExecution {
    uint256 public lastExecutionTime;
    uint256 public constant EXECUTION_INTERVAL = 1 days;
    uint256 public constant REWARD_AMOUNT = 0.01 ether;

    error TooEarly();
    error TransferFailed();

    event MaintenanceExecuted(address indexed executor, uint256 reward);

    constructor() payable {
        lastExecutionTime = block.timestamp;
    }

    receive() external payable {}

    function executeMaintenance() external {
        if (block.timestamp < lastExecutionTime + EXECUTION_INTERVAL) revert TooEarly();

        lastExecutionTime = block.timestamp;

        // Perform maintenance tasks here...

        // Reward the caller
        if (address(this).balance >= REWARD_AMOUNT) {
            (bool success,) = msg.sender.call{value: REWARD_AMOUNT}("");
            if (!success) revert TransferFailed();
            emit MaintenanceExecuted(msg.sender, REWARD_AMOUNT);
        } else {
            emit MaintenanceExecuted(msg.sender, 0);
        }
    }
}
