# Issue #9: Simple Lottery

## Extracted Requirements

- **createLottery**: Any user can call; creates a lottery with:
  - 24-hour ticket purchase window
  - 1-hour delay after purchase closes before lottery ends
  - Winner determined by future blockhash (unpredictable by players)
- **purchaseTicket(lotteryId)**: Users buy tickets until purchase deadline
- **Winner claim**: Winner must claim within 256 blocks (blockhash lookback limit)
- **Refund**: If no winner claims within 256 blocks, everyone can get their tickets back

## Acceptance Criteria

1. createLottery creates a lottery with correct purchase deadline (now + 24h) and draw block (after 25h)
2. purchaseTicket accepts tickets until purchase deadline
3. Winner is selected via blockhash of the committed draw block
4. Winner can claim winnings within 256 blocks of draw block
5. After 256 blocks with no claim, participants can refund

## Design Decisions

- Use ETH for ticket payments (fixed price per ticket, e.g. 0.01 ether)
- Store participants as dynamic array (each ticket = one entry) for fair winner selection
- drawBlock = block.number + ~7500 (25h ≈ 7500 blocks at 12s/block)
- blockhash(drawBlock) used for randomness; claim window = [drawBlock, drawBlock + 256]
