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
- Educational AMM integrations that custody LP tokens or redeemed assets without per-user accounting can permit permissionless griefing even when they do not expose a direct theft path; document that tradeoff explicitly and avoid implying production safety.
- Canonical-token fork tests prove router/factory wiring, but they do not establish safety for arbitrary ERC20s; fee-on-transfer, rebasing, and callback-enabled tokens need separate coverage before reuse.
- For router-based swap demos, validate both direct and WETH-routed paths because path-construction mistakes often hide behind passing single-hop tests.
- For one-sided liquidity "optimal zap" demos, compare strategies using relative LP output on the same fork state; leftover dust can be non-deterministically tiny and is a poor security or correctness oracle.
- Teaching-only zap flows that hardcode `amountOutMin` or `amount{A,B}Min` to near-zero are acceptable only when explicitly documented as demo code; otherwise they create avoidable sandwich and slippage-griefing risk if copied into live integrations.
- Reserve-selection logic for AMM pair helpers needs fork coverage for both token orderings; a single canonical pair test can miss the `token0 != tokenIn` branch entirely.
- Uniswap V3 concentrated liquidity: misaligned ticks and wrong fee tiers are the fastest foot-gun; treat `slot0` as non-authoritative for user-facing quotes. NPM address mistakes (40-hex typos) silently break fork tests — verify against official deployment docs.
- Router `exactInputSingle` demos must pair `amountOutMinimum` education with warnings about sandwich risk when mins are loose (tests use permissive floors only to observe live behavior).
- Uniswap V4 singleton wrappers should separate deterministic wrapper logic from environment-sensitive live-core execution; when `PoolManager.unlock()` cannot run because transient storage is unavailable, do not over-claim integration proof.
- Permit2-forwarding demo wrappers should be explicit that they are temporarily custodial: they pull tokens into the wrapper, forward allowance, execute, then refund leftovers.
- Gas optimization teaching code that exposes `delegatecall` batching (`multidelegatecall` style) must be framed as trusted-admin-only; arbitrary targets are full-chain compromise.

## Last Updated

- Issue #17, 2026-04-12: noted delegatecall batching sketch risk in RareSkills gas module; no production integration surface added.
