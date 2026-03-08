# Issue #10 Handoff

## Issue

task: 新建合约ERC1155 Bingo

## Changed Behavior

### Before

- No ERC1155 Bingo module

### After

- `ERC1155Bingo` contract in `src/16-erc1155-bingo/ERC1155Bingo.sol`
- `createGame(blocksBetweenDraws)`: Create game
- `joinGame(gameId)`: Get random 5x5 grid, mint ERC1155 tokens 1-25
- `draw(gameId)`: Every n blocks, draw random undrawn number, mark players, check bingo
- First 5-in-row (row/column/diagonal) wins

### Why This Approach

- ERC1155 token IDs 1-25 = card values; grid stored separately for position
- blockhash randomness (SimpleLottery pattern); O(players) per draw

## Files To Read First

1. `test/16-erc1155-bingo/ERC1155Bingo.t.sol`
2. `src/16-erc1155-bingo/ERC1155Bingo.sol`
3. `docs/issues/10/issue-analysis.md`

## DevAgent

### Summary

- Implemented ERC1155Bingo extending OpenZeppelin ERC1155
- createGame, joinGame, draw; Fisher-Yates grid shuffle; bitmap for marked/drawn

### Files Changed

- `src/16-erc1155-bingo/ERC1155Bingo.sol` (new)
- `test/16-erc1155-bingo/ERC1155Bingo.t.sol` (new)
- `docs/issues/10/issue-analysis.md` (new)
- `docs/issues/10/architecture.md` (new)

### Tests Added Or Updated

- `test/16-erc1155-bingo/ERC1155Bingo.t.sol`: 10 tests

### Open Questions

- None

## SecurityAgent

### Findings

- **Fixed**: `_pickUndrawnNumber` could revert despite undrawn numbers (random sampling could miss). Replaced with deterministic collect-undrawn + random index.
- **Known**: blockhash randomness is miner-influenceable; suitable for demos only.
- **Known**: joinGame mints to `msg.sender`; ERC1155 receiver callback possible but no funds at risk.

### Why It Matters

- Prevents incorrect AllNumbersDrawn reverts during draws
- Blockhash documented as low-stakes pattern

### Test Or Proof

- All 10 tests pass; `_pickUndrawnNumber` now iterates undrawn set

### Residual Risk

- O(players) per draw; scale limit for large games

## ReviewAgent

### Findings

- No material findings. NatSpec, custom errors, forge fmt applied.

### Residual Risk

- FFI tests (Differential, Vyper) require `--ffi`; ERC1155Bingo tests pass without it.

## DeployAgent

### SlackMessage (if MCP unavailable)

```
Issue #10 ready for review on branch issue-10-erc1155-bingo. Changes: 1) ERC1155Bingo contract (createGame/joinGame/draw) 2) ERC1155 tokens 1-25, 5x5 grid, 5-in-row win 3) 10 Foundry tests
```

### Release Readiness

- ready

### Validation Summary

- forge fmt, forge build, forge test (ERC1155Bingo suite) pass

### User Test Request

- Run `forge test --match-path test/16-erc1155-bingo/` and confirm all pass

## Open Risks

- Blockhash randomness; O(players) draw cost

## Suggested Reading Order

1. `docs/issues/10/issue-analysis.md`
2. `test/16-erc1155-bingo/ERC1155Bingo.t.sol`
3. `src/16-erc1155-bingo/ERC1155Bingo.sol`
