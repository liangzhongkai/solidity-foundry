// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title SecurityPatterns
/// @notice Demonstrates multiple security patterns from the Hedera guidelines.
contract SecurityPatterns {
    // 1. Fork Check Pattern
    // Prevents replay attacks and state confusion if the chain forks.
    uint256 public immutable deploymentChainId;

    // 2. Termination / Exit Strategies Pattern
    // Allows graceful shutdown without using the deprecated selfdestruct.
    bool public isTerminated;
    address public owner;

    error WrongChain();
    error Terminated();
    error Unauthorized();
    error TransferFailed();

    event TerminatedState(address sweptTo, uint256 amount);

    constructor() {
        deploymentChainId = block.chainid;
        owner = msg.sender;
    }

    modifier onlyValidFork() {
        if (block.chainid != deploymentChainId) revert WrongChain();
        _;
    }

    modifier notTerminated() {
        if (isTerminated) revert Terminated();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    receive() external payable {}

    // 3. Secure Ether Transfer Pattern
    // Using call instead of transfer/send to avoid gas limit issues.
    function secureTransfer(address payable to, uint256 amount) internal {
        (bool success,) = to.call{value: amount}("");
        if (!success) revert TransferFailed(); // Fail loud
    }

    // Exit Strategy & Termination
    function terminateAndSweep(address payable to) external onlyOwner {
        isTerminated = true;
        uint256 bal = address(this).balance;
        secureTransfer(to, bal);
        emit TerminatedState(to, bal);
    }

    // 4. Math Pattern
    // Using unchecked for gas savings when overflow is impossible.
    function sumArray(uint256[] calldata data) external view onlyValidFork notTerminated returns (uint256 sum) {
        uint256 len = data.length;
        for (uint256 i = 0; i < len;) {
            sum += data[i]; // Rely on native Solidity safe math 0.8+

            unchecked {
                ++i; // Unchecked increment is safe
            }
        }
    }
}
