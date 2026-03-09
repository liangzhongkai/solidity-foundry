# SecurityAgent Memory

Project-centric state for attack patterns and defensive techniques. Load at start, update at end.

## Attack Patterns

- Reentrancy on ETH transfer (mitigated by ReentrancyGuard in SimpleLottery).
- blockhash manipulation by miner; front-running claim.

## Exploitation Preconditions

- blockhash: miner controls block content; can influence outcome for high-value lotteries.

## Common Defensive Failures

- Forgetting blockhash(block.number) returns 0; claim window must start at drawBlock+1.

## Solidity / Protocol-Level Techniques

- blockhash lookback 256 blocks; claim must occur within [drawBlock+1, drawBlock+256].

## Last Updated

- Issue #11, 2026-03-08
