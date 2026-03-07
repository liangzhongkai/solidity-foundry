// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

/// @title Crowdfunding
/// @notice Unified crowdfunding contract that supports both Ether and ERC20-token campaigns.
contract Crowdfunding {
    using SafeERC20 for IERC20;

    struct Fundraiser {
        address creator;
        address token;
        uint256 goal;
        uint256 deadline;
        uint256 totalRaised;
        bool creatorWithdrawn;
    }

    uint256 public fundraiserCount;

    mapping(uint256 fundraiserId => Fundraiser fundraiser) public fundraisers;
    mapping(uint256 fundraiserId => mapping(address donor => uint256 amount)) public donations;

    event FundraiserCreated(
        uint256 indexed fundraiserId, address indexed creator, address indexed token, uint256 goal, uint256 deadline
    );
    event Donated(uint256 indexed fundraiserId, address indexed donor, address indexed token, uint256 amount);
    event Withdrawn(uint256 indexed fundraiserId, address indexed creator, address indexed token, uint256 amount);
    event Refunded(uint256 indexed fundraiserId, address indexed donor, address indexed token, uint256 amount);

    error AmountZero();
    error FundraiserNotFound();
    error GoalZero();
    error DeadlineNotInFuture();
    error ZeroToken();
    error FundraiserEnded(uint256 currentTime, uint256 deadline);
    error FundraiserActive(uint256 currentTime, uint256 deadline);
    error GoalNotReached(uint256 totalRaised, uint256 goal);
    error GoalReached(uint256 totalRaised, uint256 goal);
    error Unauthorized();
    error AlreadyWithdrawn();
    error NothingToRefund();
    error TransferFailed();
    error WrongAssetType();

    /// @notice Create an Ether fundraiser.
    /// @param goal Funding target in wei.
    /// @param deadline Timestamp after which donations stop and failed campaigns become refundable.
    /// @return fundraiserId Newly created fundraiser id.
    function createFundraiser(uint256 goal, uint256 deadline) external returns (uint256 fundraiserId) {
        fundraiserId = _createFundraiser(address(0), goal, deadline);
    }

    /// @notice Create an ERC20 fundraiser.
    /// @param token ERC20 token accepted by this fundraiser.
    /// @param goal Funding target in token units.
    /// @param deadline Timestamp after which donations stop and failed campaigns become refundable.
    /// @return fundraiserId Newly created fundraiser id.
    function createFundraiser(address token, uint256 goal, uint256 deadline) external returns (uint256 fundraiserId) {
        if (token == address(0)) revert ZeroToken();
        fundraiserId = _createFundraiser(token, goal, deadline);
    }

    /// @notice Donate Ether to an Ether fundraiser before its deadline.
    /// @param fundraiserId Target fundraiser id.
    function donate(uint256 fundraiserId) external payable {
        if (msg.value == 0) revert AmountZero();

        Fundraiser storage fundraiser = _getFundraiser(fundraiserId);
        if (fundraiser.token != address(0)) revert WrongAssetType();

        _donate(fundraiser, fundraiserId, msg.sender, msg.value);
    }

    /// @notice Donate ERC20 tokens to an ERC20 fundraiser before its deadline.
    /// @param fundraiserId Target fundraiser id.
    /// @param amount Token amount to donate.
    function donate(uint256 fundraiserId, uint256 amount) external {
        if (amount == 0) revert AmountZero();

        Fundraiser storage fundraiser = _getFundraiser(fundraiserId);
        if (fundraiser.token == address(0)) revert WrongAssetType();

        _donate(fundraiser, fundraiserId, msg.sender, amount);
        IERC20(fundraiser.token).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Withdraw the entire raised balance once the fundraiser reaches its goal.
    /// @param fundraiserId Target fundraiser id.
    function withdraw(uint256 fundraiserId) external {
        Fundraiser storage fundraiser = _getFundraiser(fundraiserId);

        if (msg.sender != fundraiser.creator) revert Unauthorized();
        if (fundraiser.creatorWithdrawn) revert AlreadyWithdrawn();
        if (fundraiser.totalRaised < fundraiser.goal) {
            revert GoalNotReached(fundraiser.totalRaised, fundraiser.goal);
        }

        fundraiser.creatorWithdrawn = true;
        uint256 amount = fundraiser.totalRaised;

        if (fundraiser.token == address(0)) {
            (bool ok,) = fundraiser.creator.call{value: amount}("");
            if (!ok) revert TransferFailed();
        } else {
            IERC20(fundraiser.token).safeTransfer(fundraiser.creator, amount);
        }

        emit Withdrawn(fundraiserId, fundraiser.creator, fundraiser.token, amount);
    }

    /// @notice Refund all of the caller's donations for a failed fundraiser.
    /// @param fundraiserId Target fundraiser id.
    function refund(uint256 fundraiserId) external {
        Fundraiser storage fundraiser = _getFundraiser(fundraiserId);

        if (block.timestamp <= fundraiser.deadline) {
            revert FundraiserActive(block.timestamp, fundraiser.deadline);
        }
        if (fundraiser.totalRaised >= fundraiser.goal) {
            revert GoalReached(fundraiser.totalRaised, fundraiser.goal);
        }

        uint256 amount = donations[fundraiserId][msg.sender];
        if (amount == 0) revert NothingToRefund();

        donations[fundraiserId][msg.sender] = 0;

        if (fundraiser.token == address(0)) {
            (bool ok,) = msg.sender.call{value: amount}("");
            if (!ok) revert TransferFailed();
        } else {
            IERC20(fundraiser.token).safeTransfer(msg.sender, amount);
        }

        emit Refunded(fundraiserId, msg.sender, fundraiser.token, amount);
    }

    /// @notice Return a donor's contributed amount for a fundraiser.
    /// @param fundraiserId Target fundraiser id.
    /// @param donor Donor address.
    function donationOf(uint256 fundraiserId, address donor) external view returns (uint256) {
        return donations[fundraiserId][donor];
    }

    function _createFundraiser(address token, uint256 goal, uint256 deadline) internal returns (uint256 fundraiserId) {
        if (goal == 0) revert GoalZero();
        if (deadline <= block.timestamp) revert DeadlineNotInFuture();

        fundraiserId = ++fundraiserCount;
        fundraisers[fundraiserId] = Fundraiser({
            creator: msg.sender, token: token, goal: goal, deadline: deadline, totalRaised: 0, creatorWithdrawn: false
        });

        emit FundraiserCreated(fundraiserId, msg.sender, token, goal, deadline);
    }

    function _donate(Fundraiser storage fundraiser, uint256 fundraiserId, address donor, uint256 amount) internal {
        if (block.timestamp > fundraiser.deadline) {
            revert FundraiserEnded(block.timestamp, fundraiser.deadline);
        }

        fundraiser.totalRaised += amount;
        donations[fundraiserId][donor] += amount;

        emit Donated(fundraiserId, donor, fundraiser.token, amount);
    }

    function _getFundraiser(uint256 fundraiserId) internal view returns (Fundraiser storage fundraiser) {
        fundraiser = fundraisers[fundraiserId];
        if (fundraiser.creator == address(0)) revert FundraiserNotFound();
    }
}
