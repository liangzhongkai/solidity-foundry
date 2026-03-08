// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

/// @title TokenVesting
/// @notice Time-locked ERC20 vesting: payer deposits tokens, receiver can withdraw 1/n over n days.
/// @dev Linear vesting: vestedAmount = totalAmount * elapsed / duration
contract TokenVesting {
    using SafeERC20 for IERC20;

    event Deposited(address indexed payer, address indexed receiver, uint256 amount, uint256 vestingDays);
    event Withdrawn(address indexed receiver, uint256 amount);

    error Unauthorized();
    error AlreadyDeposited();

    IERC20 public immutable token;
    address public immutable receiver;
    uint256 public immutable vestingDays;

    uint256 public totalAmount;
    uint256 public startTime;
    uint256 public released;

    /// @param _token ERC20 token address
    /// @param _receiver Address that can withdraw vested tokens
    /// @param _vestingDays Number of days over which vesting occurs (1/n per day)
    constructor(IERC20 _token, address _receiver, uint256 _vestingDays) {
        require(_receiver != address(0), "receiver zero");
        require(_vestingDays > 0, "vestingDays zero");

        token = _token;
        receiver = _receiver;
        vestingDays = _vestingDays;
    }

    /// @notice Payer deposits tokens to start vesting. Call once after deployment.
    /// @param amount Token amount to vest
    function deposit(uint256 amount) external {
        if (totalAmount > 0) revert AlreadyDeposited();
        require(amount > 0, "amount zero");

        totalAmount = amount;
        startTime = block.timestamp;

        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, receiver, amount, vestingDays);
    }

    /// @notice Amount of tokens vested up to current timestamp
    function vestedAmount() public view returns (uint256) {
        return _vestedAmount(block.timestamp);
    }

    /// @notice Amount of tokens vested at a given timestamp
    function vestedAmountAt(uint256 timestamp) public view returns (uint256) {
        return _vestedAmount(timestamp);
    }

    /// @notice Amount currently available to withdraw
    function releasable() public view returns (uint256) {
        return vestedAmount() - released;
    }

    /// @notice Withdraw all vested tokens to receiver
    function withdraw() external {
        if (msg.sender != receiver) revert Unauthorized();

        uint256 amount = releasable();
        require(amount > 0, "nothing to release");

        released += amount;
        token.safeTransfer(receiver, amount);
        emit Withdrawn(receiver, amount);
    }

    function _vestedAmount(uint256 timestamp) internal view returns (uint256) {
        if (totalAmount == 0 || timestamp < startTime) return 0;

        // Discrete vesting: unlock 1/n per day (integer days elapsed)
        // slither-disable-next-line divide-before-multiply -- intentional: discrete per-day unlock
        uint256 elapsedDays = (timestamp - startTime) / 1 days;
        if (elapsedDays >= vestingDays) return totalAmount;
        return (totalAmount * elapsedDays) / vestingDays;
    }
}
