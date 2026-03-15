# SecurityAgent Memory

Project-centric state for attack patterns and defensive techniques. Load at start, update at end.

## Attack Patterns

- Reentrancy on ETH transfer (mitigated by ReentrancyGuard in SimpleLottery).
- blockhash manipulation by miner; front-running claim.
- Signature replay on permit/delegateBySig (mitigated by nonce increment).

## Exploitation Preconditions

- blockhash: miner controls block content; can influence outcome for high-value lotteries.
- ecrecover: returns address(0) for invalid signatures; must check recovered != address(0).

## Common Defensive Failures

- Forgetting blockhash(block.number) returns 0; claim window must start at drawBlock+1.
- Not checking ecrecover return value against address(0).
- Defining ReentrancyGuard but not applying it to functions.

## Solidity / Protocol-Level Techniques

- blockhash lookback 256 blocks; claim must occur within [drawBlock+1, drawBlock+256].
- EIP-2612 permit: deadline + nonce prevents replay; ecrecover for signature recovery.
- EIP-5805 delegation: same checkpoint update pattern as OpenZeppelin ERC20Votes.

## Last Updated

- Issue #13, 2026-03-15
