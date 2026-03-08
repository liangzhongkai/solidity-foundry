# Issue #11: On-chain Blackjack

## Issue

- Issue: `#11 - task: 新建合约On-chain blackjack`
- Branch: `issue-11-on-chain-blackjack`
- Base commit: main
- Scope: New OnChainBlackjack contract with open hands, correct card probabilities, dealer rules, move timeout.
- Non-goals: Staking, rewards, multi-deck simulation beyond RNG probabilities.

## Prerequisite Issue Analysis

- Analysis file: `docs/issues/11/issue-analysis.md`
- Confirmation status: No confirmation needed
- Key conflict note: No material conflict detected

## Changed Behavior

### Before

- No blackjack module.

### After

- New `OnChainBlackjack` in `src/17-on-chain-blackjack/`. Create game, join, start, hit/stand, dealerNextMove, advanceOnTimeout. Open hands, RNG with 2-9: 1/13 each, 10: 4/13, Ace: 1/13. Dealer hits until 17. Player move timeout 10 blocks.

### Why This Approach

- blockhash RNG (consistent with #9, #10); standalone module; anyone can advance dealer or timeout.

## Files To Read First

1. `test/17-on-chain-blackjack/OnChainBlackjack.t.sol`
2. `src/17-on-chain-blackjack/OnChainBlackjack.sol`
3. `docs/issues/11/architecture.md`

## DevAgent

### Summary

- Implemented OnChainBlackjack with createGame, joinGame, startGame, hit, stand, dealerNextMove, advanceOnTimeout. Card draw uses blockhash with correct probabilities. Ace 1 or 11. Dealer stands at 17. 10-block move timeout with advanceOnTimeout for anyone to unblock.

### Files Changed

- `src/17-on-chain-blackjack/OnChainBlackjack.sol` (new)
- `test/17-on-chain-blackjack/OnChainBlackjack.t.sol` (new)

### Tests Added Or Updated

- `test/17-on-chain-blackjack/OnChainBlackjack.t.sol` — 18 tests

### Open Questions

- None.

## SecurityAgent

### Findings

- No material findings. No funds at risk; blockhash RNG documented as demo-only; no reentrancy surface.

### Why It Matters

- Game is informational only; no ETH or token transfers.

### Test Or Proof

- 18 unit tests pass; no reentrancy; no external calls.

### Residual Risk

- blockhash manipulable by miner; acceptable for demo per project pattern.

## ReviewAgent

### Findings

- No material findings. NatSpec, custom errors, forge fmt applied.

### Why It Matters

- Code quality and consistency.

### Test Or Proof

- forge fmt --check; forge test --match-path test/17-on-chain-blackjack/*

### Residual Risk

- None identified.

## DeployAgent

### SlackMessage (if MCP unavailable)

- Issue #11 ready for review on branch issue-11-on-chain-blackjack. Changes: 1) New OnChainBlackjack contract 2) Open hands, correct card probabilities, dealer hits until 17 3) 10-block move timeout, anyone can call dealerNextMove/advanceOnTimeout

### Release Readiness

- ready

### Validation Summary

- forge build: pass; forge fmt --check: pass; forge test --match-path test/17-on-chain-blackjack/*: 18 passed

### User Test Request

- Run `forge test --match-path test/17-on-chain-blackjack/*` and verify full game flow.

## Open Risks

- None.

## Suggested Reading Order

1. `docs/issues/11/issue-analysis.md`
2. `test/17-on-chain-blackjack/OnChainBlackjack.t.sol`
3. `src/17-on-chain-blackjack/OnChainBlackjack.sol`
4. `docs/issues/11/architecture.md`
