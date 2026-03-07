// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

/// @title Crowdfunding
/// @notice Unified crowdfunding contract that supports both Ether and standard ERC20-token campaigns.
/// @dev ERC20 fundraisers support plain non-deflationary, non-rebasing tokens only.
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
    error UnsupportedTokenTransfer(uint256 expectedAmount, uint256 receivedAmount);
    error FundraiserClosed();

    /// @notice Create an Ether fundraiser.
    /// @param goal Funding target in wei.
    /// @param deadline Timestamp at which donations stop and failed campaigns become refundable if the goal was not met.
    /// @return fundraiserId Newly created fundraiser id.
    function createFundraiser(uint256 goal, uint256 deadline) external returns (uint256 fundraiserId) {
        fundraiserId = _createFundraiser(address(0), goal, deadline);
    }

    /// @notice Create an ERC20 fundraiser for a standard token.
    /// @dev Fee-on-transfer and rebasing tokens are unsupported.
    /// @param token ERC20 token accepted by this fundraiser.
    /// @param goal Funding target in token units.
    /// @param deadline Timestamp at which donations stop and failed campaigns become refundable if the goal was not met.
    /// @return fundraiserId Newly created fundraiser id.
    function createFundraiser(address token, uint256 goal, uint256 deadline) external returns (uint256 fundraiserId) {
        if (token == address(0)) revert ZeroToken();
        fundraiserId = _createFundraiser(token, goal, deadline);
    }

    /// @notice Donate Ether to an Ether fundraiser before its deadline timestamp.
    /// @param fundraiserId Target fundraiser id.
    function donate(uint256 fundraiserId) external payable {
        if (msg.value == 0) revert AmountZero();

        Fundraiser storage fundraiser = _getFundraiser(fundraiserId);
        if (fundraiser.token != address(0)) revert WrongAssetType();

        _requireFundraiserOpen(fundraiser);
        _recordDonation(fundraiser, fundraiserId, msg.sender, msg.value);
    }

    /// @notice Donate ERC20 tokens to an ERC20 fundraiser before its deadline timestamp.
    /// @dev Reverts for fee-on-transfer and rebasing tokens.
    /// @param fundraiserId Target fundraiser id.
    /// @param amount Token amount to donate.
    function donate(uint256 fundraiserId, uint256 amount) external {
        if (amount == 0) revert AmountZero();

        Fundraiser storage fundraiser = _getFundraiser(fundraiserId);
        if (fundraiser.token == address(0)) revert WrongAssetType();

        _requireFundraiserOpen(fundraiser);

        IERC20 token = IERC20(fundraiser.token);
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 receivedAmount = token.balanceOf(address(this)) - balanceBefore;
        if (receivedAmount != amount) revert UnsupportedTokenTransfer(amount, receivedAmount);

        _recordDonation(fundraiser, fundraiserId, msg.sender, amount);
    }

    /// @notice Withdraw the entire raised balance once the fundraiser reaches its goal.
    /// @dev The creator can withdraw immediately after the goal is reached, even before the deadline. Withdrawing closes the fundraiser.
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
            _safeTransferExact(IERC20(fundraiser.token), fundraiser.creator, amount);
        }

        emit Withdrawn(fundraiserId, fundraiser.creator, fundraiser.token, amount);
    }

    /// @notice Refund all of the caller's donations for a failed fundraiser.
    /// @param fundraiserId Target fundraiser id.
    function refund(uint256 fundraiserId) external {
        Fundraiser storage fundraiser = _getFundraiser(fundraiserId);

        if (block.timestamp < fundraiser.deadline) {
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
            _safeTransferExact(IERC20(fundraiser.token), msg.sender, amount);
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

    function _requireFundraiserOpen(Fundraiser storage fundraiser) internal view {
        if (fundraiser.creatorWithdrawn) revert FundraiserClosed();
        if (block.timestamp >= fundraiser.deadline) {
            revert FundraiserEnded(block.timestamp, fundraiser.deadline);
        }
    }

    function _recordDonation(Fundraiser storage fundraiser, uint256 fundraiserId, address donor, uint256 amount)
        internal
    {
        fundraiser.totalRaised += amount;
        donations[fundraiserId][donor] += amount;

        emit Donated(fundraiserId, donor, fundraiser.token, amount);
    }

    function _safeTransferExact(IERC20 token, address to, uint256 amount) internal {
        uint256 balanceBefore = token.balanceOf(to);
        token.safeTransfer(to, amount);
        uint256 receivedAmount = token.balanceOf(to) - balanceBefore;
        if (receivedAmount != amount) revert UnsupportedTokenTransfer(amount, receivedAmount);
    }

    function _getFundraiser(uint256 fundraiserId) internal view returns (Fundraiser storage fundraiser) {
        fundraiser = fundraisers[fundraiserId];
        if (fundraiser.creator == address(0)) revert FundraiserNotFound();
    }
}
