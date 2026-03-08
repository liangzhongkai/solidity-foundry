// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ReentrancyGuard} from "openzeppelin-contracts@5.4.0/utils/ReentrancyGuard.sol";

/// @title SimpleLottery
/// @notice Lottery where any user can create a lottery; participants buy tickets for 24h, then a winner
///         is chosen via future blockhash after a 1h delay. Winner must claim within 256 blocks or
///         everyone can refund.
/// @dev Uses blockhash for randomness; suitable for low-stakes only. See RareSkills article on
///      blockchain randomness.
contract SimpleLottery is ReentrancyGuard {
    uint256 public constant TICKET_PRICE = 0.01 ether;
    uint256 public constant PURCHASE_WINDOW = 24 hours;
    uint256 public constant DRAW_DELAY = 1 hours;
    uint256 public constant BLOCKHASH_LOOKBACK = 256;

    struct Lottery {
        uint64 purchaseDeadline;
        uint64 drawBlock;
        uint256 ticketCount;
        address[] participants;
        address winner;
        bool winnerClaimed;
    }

    uint256 public lotteryCount;
    mapping(uint256 lotteryId => Lottery) public lotteries;

    event LotteryCreated(uint256 indexed lotteryId, uint64 purchaseDeadline, uint64 drawBlock);
    event TicketPurchased(uint256 indexed lotteryId, address indexed buyer, uint256 ticketIndex);
    event WinnerClaimed(uint256 indexed lotteryId, address indexed winner, uint256 amount);
    event Refunded(uint256 indexed lotteryId, address indexed participant, uint256 amount);

    error LotteryNotFound();
    error PurchaseWindowClosed();
    error NotWinner();
    error AlreadyClaimed();
    error ClaimWindowClosed();
    error ClaimWindowNotOpen();
    error NoTickets();
    error RefundWindowNotOpen();
    error NothingToRefund();
    error WrongTicketPrice();
    error TransferFailed();

    /// @notice Create a new lottery. Purchase window is 24h; draw block is ~25h from now.
    /// @return lotteryId The new lottery id.
    function createLottery() external returns (uint256 lotteryId) {
        uint64 purchaseDeadline = uint64(block.timestamp + PURCHASE_WINDOW);
        uint64 drawBlock = uint64(block.number + (PURCHASE_WINDOW + DRAW_DELAY) / 12); // ~25h in blocks

        lotteryId = ++lotteryCount;
        lotteries[lotteryId] = Lottery({
            purchaseDeadline: purchaseDeadline,
            drawBlock: drawBlock,
            ticketCount: 0,
            participants: new address[](0),
            winner: address(0),
            winnerClaimed: false
        });

        emit LotteryCreated(lotteryId, purchaseDeadline, drawBlock);
    }

    /// @notice Purchase a ticket for a lottery. Must be before purchase deadline; costs TICKET_PRICE.
    /// @param lotteryId The lottery to buy a ticket for.
    function purchaseTicket(uint256 lotteryId) external payable {
        if (msg.value != TICKET_PRICE) revert WrongTicketPrice();

        Lottery storage lottery = _getLottery(lotteryId);
        if (block.timestamp >= lottery.purchaseDeadline) revert PurchaseWindowClosed();

        lottery.participants.push(msg.sender);
        lottery.ticketCount++;

        emit TicketPurchased(lotteryId, msg.sender, lottery.ticketCount - 1);
    }

    /// @notice Claim winnings as the winner. Must be called within 256 blocks of the draw block.
    function claimWinnings(uint256 lotteryId) external nonReentrant {
        Lottery storage lottery = _getLottery(lotteryId);

        if (lottery.ticketCount == 0) revert NoTickets();
        if (block.number <= lottery.drawBlock) revert ClaimWindowNotOpen(); // blockhash(drawBlock) needs block > drawBlock
        if (block.number > lottery.drawBlock + BLOCKHASH_LOOKBACK) revert ClaimWindowClosed();
        if (lottery.winnerClaimed) revert AlreadyClaimed();

        if (lottery.winner == address(0)) {
            bytes32 h = blockhash(lottery.drawBlock);
            if (h == bytes32(0)) revert ClaimWindowClosed(); // block too old
            // slither-disable-next-line weak-prng -- blockhash-based RNG; documented as low-stakes only; use Chainlink VRF for production
            uint256 winnerIndex = uint256(keccak256(abi.encodePacked(h))) % lottery.ticketCount;
            lottery.winner = lottery.participants[winnerIndex];
        }

        if (msg.sender != lottery.winner) revert NotWinner();

        lottery.winnerClaimed = true;
        uint256 amount = lottery.ticketCount * TICKET_PRICE;

        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit WinnerClaimed(lotteryId, msg.sender, amount);
    }

    /// @notice Refund ticket cost. Only after 256 blocks past draw block with no winner claim.
    /// @param lotteryId The lottery to refund from.
    function refund(uint256 lotteryId) external nonReentrant {
        Lottery storage lottery = _getLottery(lotteryId);

        if (block.number <= lottery.drawBlock + BLOCKHASH_LOOKBACK) revert RefundWindowNotOpen();
        if (lottery.winnerClaimed) revert RefundWindowNotOpen();

        uint256 count = 0;
        for (uint256 i = 0; i < lottery.participants.length; i++) {
            if (lottery.participants[i] == msg.sender) count++;
        }
        if (count == 0) revert NothingToRefund();

        lottery.ticketCount -= count;
        // Remove caller's entries (swap-with-last to avoid shifting)
        _removeParticipant(lottery, msg.sender);

        uint256 amount = count * TICKET_PRICE;
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Refunded(lotteryId, msg.sender, amount);
    }

    /// @notice Get participant at index for a lottery.
    function getParticipant(uint256 lotteryId, uint256 index) external view returns (address) {
        return _getLottery(lotteryId).participants[index];
    }

    function _getLottery(uint256 lotteryId) internal view returns (Lottery storage) {
        Lottery storage lottery = lotteries[lotteryId];
        if (lottery.drawBlock == 0) revert LotteryNotFound();
        return lottery;
    }

    function _removeParticipant(Lottery storage lottery, address participant) internal {
        address[] storage arr = lottery.participants;
        for (uint256 i = 0; i < arr.length;) {
            if (arr[i] == participant) {
                arr[i] = arr[arr.length - 1];
                arr.pop();
                // Don't increment - check same index again (new element)
            } else {
                i++;
            }
        }
    }
}
