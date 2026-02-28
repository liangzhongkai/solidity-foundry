// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title Auction
/// @notice Simple time-bounded auction contract
/// @dev Uses block.timestamp for start/end boundaries
contract Auction {
    uint256 private constant AUCTION_DURATION = 1 days;
    uint256 private constant TOTAL_DURATION = 2 days;

    uint256 public startAt = block.timestamp + AUCTION_DURATION;
    uint256 public endAt = block.timestamp + TOTAL_DURATION;

    function bid() external view {
        require(block.timestamp >= startAt && block.timestamp < endAt, "cannot bid");
    }

    function end() external view {
        require(block.timestamp >= endAt, "cannot end");
    }
}
