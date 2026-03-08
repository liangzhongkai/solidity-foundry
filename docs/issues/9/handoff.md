# Issue #9 Handoff

## Issue

新建合约 Simple lottery

## Changed Behavior

- Added `SimpleLottery` contract in `src/15-simple-lottery/SimpleLottery.sol`
- `createLottery()`: Any user creates a lottery with 24h purchase window and ~25h draw block
- `purchaseTicket(lotteryId)`: Buy ticket for 0.01 ether until purchase deadline
- `claimWinnings(lotteryId)`: Winner claims pool within 256 blocks of draw block (blockhash-based randomness)
- `refund(lotteryId)`: After 256 blocks with no claim, participants can refund

## Files To Read First

1. `src/15-simple-lottery/SimpleLottery.sol`
2. `test/15-simple-lottery/SimpleLottery.t.sol`

## DevAgent

Implemented per issue-analysis.md. Uses blockhash for randomness (RareSkills pattern); ReentrancyGuard for safety.

## Open Risks

- Blockhash randomness is miner-influenceable; suitable for low-stakes only
- FFI tests (Vyper, DifferentialTest) require `--ffi`; SimpleLottery tests pass without it

## SlackMessage (Manual Post if MCP Unavailable)

**IssueAgent (start):**
```
Starting issue #9: Simple lottery. Breakdown: 1) createLottery with 24h purchase window 2) purchaseTicket, claimWinnings via blockhash 3) refund after 256 blocks if no claim
```

**DeployAgent (ready for review):**
```
Issue #9 ready for review on branch issue-9-simple-lottery. Changes: 1) SimpleLottery contract (create/purchase/claim/refund) 2) blockhash-based winner selection 3) 13 Foundry tests
```

