# DevAgent Memory

Project-centric state for architecture, design, and implementation. Load at start, update at end.

## Current Architecture

- Modules in `src/<nn>-<name>/`; each folder is self-contained (e.g. 15-simple-lottery).
- Reference: `docs/issues/*/architecture.md` for issue-specific diagrams.

## Module Boundaries

- SimpleLottery: standalone; no cross-module calls. Uses OpenZeppelin ReentrancyGuard.
- ERC1155Bingo: standalone; extends OpenZeppelin ERC1155; no cross-module calls.
- OnChainBlackjack: standalone; no cross-module calls; no ETH/token transfers.

## Design Tradeoffs

- blockhash randomness: simple, no oracle; miner-influenceable. Suitable for low-stakes only (SimpleLottery, ERC1155Bingo).
- participants as address[]: O(n) refund scan; acceptable for demo scale.

## Code Style Expectations

- Reference: CLAUDE.md, .cursor/rules/solidity-architecture-and-design.mdc.
- Custom errors, NatSpec on public/external, forge fmt.

## Extension Seams

- Lottery params (TICKET_PRICE, PURCHASE_WINDOW) could be made configurable per lottery.

## Test Strategy

- Unit tests with vm.warp, vm.roll for time/block manipulation.
- blockhash(drawBlock) available only when block.number > drawBlock; tests must vm.roll(drawBlock+1).

## Performance Constraints

- Refund iterates participants; O(n) per participant. Not suitable for large lotteries.
- ERC1155Bingo draw iterates all players; O(players) per draw.

## Last Updated

- Issue #11, 2026-03-08
