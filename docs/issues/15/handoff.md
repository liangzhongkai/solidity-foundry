# Issue #15 handoff

## Issue

[GitHub #15](https://github.com/liangzhongkai/solidity-foundry/issues/15): 新建案例展示 uniswap-v3 的接口使用 — cover common Uniswap V3 interfaces with tests that highlight usage patterns and production caveats.

## Changed behavior

- New teaching module `src/21-uniswap-v3/` with minimal interfaces: pool lens; `SwapRouter.exactInputSingle`, packed-path `exactInput` + `encodePath`; NPM `mint`, `decreaseLiquidity`, `collect`, and `burn` (via `burnPositionFully`).
- New fork-oriented tests under `test/21-uniswap-v3/`; non-fork runs skip when bytecode is absent (same pattern as issue #14).

## Architecture digest

- **Status**: `required and updated`
- **Path**: `docs/issues/15/architecture.md`

## Files to read first

1. `docs/issues/15/architecture.md`
2. `src/21-uniswap-v3/interfaces/IUniswapV3.sol`
3. `test/21-uniswap-v3/*.t.sol`
4. `src/21-uniswap-v3/UniswapV3SwapExample.sol`, `UniswapV3LiquidityNftExample.sol`, `UniswapV3PoolLens.sol`

## DevAgent

- Implemented minimal interfaces (no new git submodules) mirroring the V2 module style.
- NPM mainnet address corrected to `0xC36442b4a4522E871399CD717aBDD847Ab11FE88` (previous checksum-colliding literals are easy to mistake).
- `mintPosition` takes explicit `tickLower`/`tickUpper`; tests build a symmetric window via `slot0` + `feeToTickSpacing` / `floorTickToSpacing` to avoid solc “stack too deep” without enabling `via_ir` project-wide.
- Multi-hop fork test uses WBTC→WETH (0.05%)→DAI (0.3%) as a realistic mainnet path encoding example.

## SecurityAgent

### Findings

- None material beyond standard AMM integration risks (sandwich/MEV, stale `slot0`, wrong fee tier, tick spacing).

### Why it matters

- Mis-set `amountOutMinimum` / mint mins or wrong pool parameters lead to failed txs or bad fills — tests document the guardrails.

### Test or proof

- Fork tests assert live pool reads, swap output to recipient, NPM mint produces liquidity, and misaligned ticks revert.
- `forge test --ffi` passes repo-wide; V3 suites skip without fork.

### Residual risk

- Teaching contracts are not audited for production treasury use; they delegate to Uniswap periphery with the usual MEV and oracle assumptions.

## ReviewAgent

### Findings

- NatSpec on public/external ABI-facing functions; custom errors on lens; events on swap and mint for observability.

### Why it matters

- Matches repo Solidity style and supports teaching/debugging.

### Test or proof

- `forge fmt --check`, `forge test --ffi`.

### Residual risk

- Public RPC endpoints for fork tests can intermittently fail (502); use a stable `MAINNET_RPC_URL` locally.

## Open risks

- Fork tests require a reliable Ethereum JSON-RPC URL.

## SlackMessage

- **IssueAgent start**: `Starting issue #15: task: 新建案例展示uniswap-v3的接口使用. Breakdown: 1) Add teaching module covering common Uniswap V3 interfaces (pool, positions, swaps) 2) Foundry tests with fork showing usage patterns and production caveats 3) Align with repo style (src/NN-topic/, interfaces, optional fork skips)` — **sent via MCP** (Slack workspace)
- **DeployAgent ready**: `Issue #15 ready for review on branch issue-15-uniswap-v3-example. Changes: 1) add src/21-uniswap-v3 demos for pool lens, SwapRouter exactInputSingle, and NPM mint with tick helpers 2) add fork-based Foundry tests and issue docs (analysis, architecture, handoff, verification) 3) run forge fmt, forge test --ffi, and targeted Slither on new contracts` — **sent via MCP** (after validation)

