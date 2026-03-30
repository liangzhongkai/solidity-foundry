# Issue #15: 新建案例展示 uniswap-v3 的接口使用

## Summary

Add a standalone Foundry teaching module under `src/21-uniswap-v3/` that exercises common Uniswap V3 interfaces (factory/pool state, swap router, NFT position manager), with tests that highlight integration techniques and production caveats. Mirror the issue #14 pattern: minimal local interfaces, mainnet addresses, fork tests that skip when contracts are absent.

## Acceptance criteria

- Cover commonly used V3 entry points: pool discovery and `slot0`, `SwapRouter.exactInputSingle`, `NonfungiblePositionManager.mint` / `collect` (and related params).
- Tests emphasize usage tips: token ordering, fee tier must match an existing pool, deadlines, `amountOutMinimum`, `sqrtPriceLimitX96`, tick spacing alignment for positions, and why Quoter-style calls are usually `eth_call` / off-chain.
- Default `forge test` stays green without an RPC URL (skip when fork contracts missing).

## Impacted areas

- New module `src/21-uniswap-v3/` and `test/21-uniswap-v3/`.
- Docs under `docs/issues/15/`.
- Agent memory updates for coordination.

## Conflicts / confirmations

- None: scope matches a new demo module analogous to `20-uniswap-v2`.

## Fast reading order

1. `docs/issues/15/architecture.md`
2. `src/21-uniswap-v3/interfaces/IUniswapV3.sol`
3. `test/21-uniswap-v3/*.t.sol` (comments + assertions)
4. Demo contracts in `src/21-uniswap-v3/`
