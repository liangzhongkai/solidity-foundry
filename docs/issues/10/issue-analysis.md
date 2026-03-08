# Issue #10: ERC1155 Bingo

## Issue Summary

- Issue: `#10 - task: 新建合约ERC1155 Bingo`
- Branch: `issue-10-erc1155-bingo`
- Analyst: `IssueAgent`
- Requested change: Build an ERC1155-based Bingo game.

## Extracted Requirements

1. **ERC1155 deck**: Use ERC1155 tokens to simulate a deck of cards with values 1–25 inclusive (token IDs 1–25).
2. **Player grid**: Each player has a 5×5 grid filled with numbers 1–25, randomly arranged.
3. **Periodic draw**: Every n blocks, a new card/number can be drawn (random 1–25).
4. **Win condition**: First player to get 5 in a row (bingo) wins.

## Acceptance Criteria

1. Contract extends ERC1155; token IDs 1–25 represent card values.
2. Players can join a game and receive a random 5×5 grid (1–25, each once).
3. Draw can be triggered every n blocks; draws a random undrawn number 1–25.
4. First player with 5 marked in a row (any row, column, or diagonal) wins.
5. Game emits events for join, draw, and win.

## Design Decisions

- **Single game vs multi-game**: Support multiple games; `createGame(n)` where n = blocks between draws.
- **Randomness**: blockhash-based (same approach as SimpleLottery #9); suitable for demos only.
- **Grid representation**: Store `uint8[5][5]` per player per game; ERC1155 used for deck semantics and optional minting of cards to players.
- **Draw semantics**: "Mint a new card" interpreted as drawing the next number from the deck (global draw, not per-player mint).

## Conflict Check

### No Conflict

- No material conflict with existing modules. New module `16-erc1155-bingo`; standalone like SimpleLottery.

### Potential Conflicts

- None identified.

## User Confirmation Required

- None. Proceed with implementation.

Status: No confirmation needed.

## Recommended Approach

1. Create `src/16-erc1155-bingo/ERC1155Bingo.sol` extending OpenZeppelin ERC1155.
2. `createGame(uint256 blocksBetweenDraws)`: Create game, store n.
3. `joinGame(uint256 gameId)`: Assign random 5×5 grid, mint 1 of each token 1–25 to player.
4. `draw(uint256 gameId)`: Callable every n blocks; pick random undrawn 1–25; mark all players; check win.
5. blockhash for randomness; tests use `vm.roll` to control blocks.

## Files To Read First

1. `src/15-simple-lottery/SimpleLottery.sol` (blockhash pattern)
2. OpenZeppelin ERC1155
3. `docs/memory/dev-agent.md`

## IssueAgent Summary

### What It Did

- Parsed issue requirements; inferred ERC1155 usage and bingo flow.
- Checked module boundaries; no overlap with SimpleLottery or other modules.

### Why It Matters

- Clear scope for DevAgent; ERC1155 + bingo logic in one module.

### Residual Uncertainty

- Prize/reward not specified; emit Winner event only for now.
