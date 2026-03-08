// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts@5.4.0/utils/ReentrancyGuard.sol";

/// @title StakeTogether
/// @notice Staking contract: users stake cloud coins from beginDate, hold for 7 days, and receive
///         proportional rewards at expiration from a 1M reward pool.
/// @dev Staking is only allowed until (expiration - 7 days) to prevent last-minute stake attacks.
contract StakeTogether is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant REWARD_POOL = 1_000_000 * 10 ** 18;
    uint256 public constant STAKING_PERIOD = 7 days;

    IERC20 public immutable token;
    uint64 public immutable beginDate;
    uint64 public immutable expiration;

    uint256 public totalStaked;
    mapping(address user => uint256 amount) public stakeOf;

    bool private _snapshotTaken;
    uint256 private _totalStakedAtExpiration;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 stake, uint256 reward);

    error StakingNotOpen();
    error StakingWindowClosed();
    error ZeroAmount();
    error InsufficientRewardPool();
    error NotExpired();
    error NothingToWithdraw();
    error ZeroAddress();

    /// @param _token Cloud coin ERC20 address.
    /// @param _beginDate Unix timestamp when staking opens.
    /// @param _expiration Unix timestamp when staking closes and rewards are finalized.
    constructor(IERC20 _token, uint64 _beginDate, uint64 _expiration) {
        if (address(_token) == address(0)) revert ZeroAddress();
        if (_expiration <= _beginDate) revert StakingNotOpen();
        if (_expiration - _beginDate <= STAKING_PERIOD) revert StakingNotOpen();

        token = _token;
        beginDate = _beginDate;
        expiration = _expiration;
    }

    /// @notice Stake cloud coins. Only allowed from beginDate until (expiration - 7 days).
    /// @param amount Amount to stake.
    function stake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (block.timestamp < beginDate) revert StakingNotOpen();
        if (block.timestamp >= expiration - STAKING_PERIOD) revert StakingWindowClosed();
        if (totalStaked == 0 && token.balanceOf(address(this)) < REWARD_POOL) revert InsufficientRewardPool();

        stakeOf[msg.sender] += amount;
        totalStaked += amount;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    /// @notice Withdraw stake and proportional reward after expiration.
    function withdraw() external nonReentrant {
        if (block.timestamp < expiration) revert NotExpired();

        _takeSnapshotIfNeeded();

        uint256 userStake = stakeOf[msg.sender];
        if (userStake == 0) revert NothingToWithdraw();

        uint256 reward = _computeReward(userStake);
        stakeOf[msg.sender] = 0;

        uint256 total = userStake + reward;
        token.safeTransfer(msg.sender, total);

        emit Withdrawn(msg.sender, userStake, reward);
    }

    /// @notice Compute reward for a given stake amount based on snapshot.
    /// @param userStake User's staked amount at expiration.
    function _computeReward(uint256 userStake) internal view returns (uint256) {
        if (_totalStakedAtExpiration == 0) return 0;
        return (REWARD_POOL * userStake) / _totalStakedAtExpiration;
    }

    /// @notice Take snapshot of totalStaked at expiration (once).
    function _takeSnapshotIfNeeded() internal {
        if (!_snapshotTaken) {
            _totalStakedAtExpiration = totalStaked;
            _snapshotTaken = true;
        }
    }

    /// @notice Preview reward for a user (requires snapshot to be taken).
    function previewReward(address user) external view returns (uint256) {
        if (block.timestamp < expiration) return 0;
        uint256 totalAtExpiration = _snapshotTaken ? _totalStakedAtExpiration : totalStaked;
        if (totalAtExpiration == 0) return 0;
        return (REWARD_POOL * stakeOf[user]) / totalAtExpiration;
    }
}
