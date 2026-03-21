# Issue #14 Handoff

## Issue

新增一个基于 Foundry 的 Uniswap V2 接口案例；在 issue comment 更新后，范围扩展为流动性增删、代币交换、以及单边加池最优 / 次优对比三类示例。

## Changed Behavior

- 新增 `src/20-uniswap-v2/UniswapV2LiquidityExample.sol`
- 新增 `src/20-uniswap-v2/UniswapV2SwapExample.sol`
- 新增 `src/20-uniswap-v2/UniswapV2OptimalZap.sol`
- 新增 `src/20-uniswap-v2/interfaces/IUniswapV2.sol`
- 新增 `test/20-uniswap-v2/UniswapV2LiquidityExample.t.sol`
- 新增 `test/20-uniswap-v2/UniswapV2SwapExample.t.sol`
- 新增 `test/20-uniswap-v2/UniswapV2OptimalZap.t.sol`
- 测试在主网 fork 环境下验证真实 Uniswap V2 `Router` / `Factory` / `Pair` 接口交互；在非 fork 环境下自动跳过

## Files To Read First

- `docs/issues/14/issue-analysis.md`
- `docs/issues/14/architecture.md`
- `test/20-uniswap-v2/UniswapV2LiquidityExample.t.sol`
- `test/20-uniswap-v2/UniswapV2SwapExample.t.sol`
- `test/20-uniswap-v2/UniswapV2OptimalZap.t.sol`
- `src/20-uniswap-v2/UniswapV2LiquidityExample.sol`
- `src/20-uniswap-v2/UniswapV2SwapExample.sol`
- `src/20-uniswap-v2/UniswapV2OptimalZap.sol`
- `src/20-uniswap-v2/interfaces/IUniswapV2.sol`

## DevAgent

- 新增自包含的 Uniswap V2 流动性示例合约，保留 issue 示例中的主网 `Factory` / `Router` / `WETH` 常量地址
- 新增 swap 示例合约，支持直接两跳与经 `WETH` 的三跳路径，并封装 `getAmountsOut` 报价
- 新增 optimal zap 示例合约，实现 comment 中的一边换币一边加池公式，并与 half-swap 的次优策略做 fork 对比
- 使用 `SafeERC20` 完成代币拉取与授权，并为 pair 不存在、零 LP、非 `WETH` 配对等场景补充显式错误
- Foundry 测试使用 `WETH.deposit()`、DAI whale、WBTC whale 准备 fork 资金，验证 liquidity / swap / zap 三条主流程

## Architecture

- **Status**: required and updated
- **Path**: `docs/issues/14/architecture.md`

## Open Risks

- 该模块是教学示例，流动性与 zap 示例中的 LP 或换回资产保留在示例合约内，未额外实现用户提取逻辑
- fork 测试依赖可访问的主网 RPC；默认非 fork 套件仅会跳过该测试

## SlackMessage

- **IssueAgent start**: `Starting issue #14: 新建使用uniswap V2接口的案例. Breakdown: 1) add a Foundry-based Uniswap V2 demo contract 2) add fork-based tests covering add/remove liquidity flows 3) document the design and verification artifacts` — **fallback recorded**
- **DeployAgent ready**: `Issue #14 ready for review on branch issue-14-uniswap-v2-example. Changes: 1) add a Uniswap V2 liquidity demo contract with router/factory interfaces 2) add mainnet-fork Foundry tests for add/remove liquidity and revert guards 3) add issue analysis, architecture, and verification artifacts` — **fallback recorded**
- **DeployAgent ready (updated scope)**: `Issue #14 ready for review on branch issue-14-uniswap-v2-example. Changes: 1) add Uniswap V2 liquidity, swap, and optimal-zap demo contracts 2) add mainnet-fork Foundry tests for liquidity flows, direct and routed swaps, and zap comparisons 3) update issue analysis, architecture, and verification artifacts for the expanded comment scope` — **fallback recorded**
- **DeployAgent ready (post-review commit, 2026-03-21)**: `Issue #14 ready for review on branch issue-14-uniswap-v2-example. Changes: 1) add Uniswap V2 liquidity, swap, and optimal-zap demo contracts 2) add mainnet-fork Foundry tests for liquidity flows, direct and routed swaps, and zap comparisons 3) add issue analysis, architecture, handoff, and verification artifacts` — **sent via MCP** ([Slack message](https://kleung-workspace.slack.com/archives/C0AK5HY73D0/p1774064162258849))

## Findings (SecurityAgent / ReviewAgent)

### SecurityAgent
- No material findings.
- Residual risk: the liquidity and zap examples are intentionally custodial and have no per-user accounting or authorization, so they demonstrate router integration rather than a production-safe asset management pattern.
- Residual risk: `UniswapV2OptimalZap` hardcodes `amountOutMin = 1` for the internal swap and `amountAMin/amountBMin = 0` for liquidity addition. That is acceptable for a fork-based teaching demo, but if reused with real funds it would leave callers exposed to sandwich and slippage griefing.
- Test or proof caveat: tests now cover liquidity guards, direct and indirect swap routes, and optimal-vs-suboptimal zap behavior on the canonical `DAI/WETH` pair, including the reverse reserve-selection branch where `tokenA == WETH`. Non-standard tokens such as fee-on-transfer, rebasing, or callback-enabled ERC20s remain out of scope for this teaching example.

### ReviewAgent
- **Findings**: No material findings.
- **Why It Matters**: The implementation now matches the expanded issue scope from the latest comments. It covers router/factory/pair interactions for liquidity, swap, and zap flows, while preserving the repository's non-fork test flow by skipping cleanly when forked mainnet contracts are unavailable.
- **Test Or Proof**:
- Reviewed `src/20-uniswap-v2/*.sol`, `src/20-uniswap-v2/interfaces/IUniswapV2.sol`, `test/20-uniswap-v2/*.t.sol`, `docs/issues/14/issue-analysis.md`, and `docs/issues/14/architecture.md` against the issue acceptance criteria.
- Ran `forge test --match-path test/20-uniswap-v2/UniswapV2LiquidityExample.t.sol`, confirming the non-fork skip behavior.
- Ran `forge test --fork-url https://ethereum.publicnode.com --match-path test/20-uniswap-v2/UniswapV2LiquidityExample.t.sol -vv`, confirming 4 passing fork-based tests for add/remove liquidity and the local revert guards.
- Ran `forge test --match-path test/20-uniswap-v2/UniswapV2SwapExample.t.sol`, confirming the non-fork skip behavior.
- Ran `forge test --fork-url https://ethereum.publicnode.com --match-path test/20-uniswap-v2/UniswapV2SwapExample.t.sol -vv`, confirming 4 passing fork-based swap tests including the indirect `WBTC -> WETH -> DAI` route, the direct `WETH -> DAI` route, and the zero-recipient guard.
- Ran `forge test --match-path test/20-uniswap-v2/UniswapV2OptimalZap.t.sol`, confirming the non-fork skip behavior.
- Ran `forge test --fork-url https://ethereum.publicnode.com --match-path test/20-uniswap-v2/UniswapV2OptimalZap.t.sol -vv`, confirming 3 passing fork-based zap tests, including optimal-vs-suboptimal LP output comparison and the `tokenA == WETH` reserve-selection branch.
- **Residual Risk**:
- The example remains intentionally custodial and is only appropriate as a protocol-integration demo, not as a production liquidity manager pattern.
- The suite now proves direct and routed swaps on canonical paths, but it still does not cover non-standard ERC20 behaviors or broader pair compatibility beyond the documented mainnet examples.
