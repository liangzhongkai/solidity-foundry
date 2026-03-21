# Issue #14: 新建使用uniswap V2接口的案例

## Issue Intent

基于 issue 正文与后续 comment 中给出的三组示例代码，新增一个 Foundry 版的 Uniswap V2 教学模块，覆盖：

1. `addLiquidity` / `removeLiquidity`
2. `swap` 与 `getAmountsOut`
3. `optimal zap` 与 `sub-optimal zap` 对比

## Acceptance Criteria

- 新增一个自包含的 Uniswap V2 教学模块
- 合约通过真实 Uniswap V2 `Router`、`Factory`、`Pair` 接口完成流动性、交换、单边加池等示例
- Foundry 测试覆盖三类主流程，并验证与真实主网协议状态的交互结果
- 测试在主网 fork 环境下可执行，同时不破坏默认非 fork 测试流程

## Current Behavior

- 仓库已有基础 fork 测试示例（如 `test/Fork.t.sol`、`test/Whale.t.sol`）
- 在本 issue 开始前，仓库中尚无专门演示 Uniswap V2 `Router` / `Factory` / `Pair` 接口调用的教学模块

## Impacted Modules

- 新增 `src/20-uniswap-v2/` 模块
- 新增 `test/20-uniswap-v2/` fork 测试
- 更新 `docs/issues/14/` 评审与验证文档

## Architecture Constraints

- 示例应保持自包含，不影响现有模块
- 使用 Solidity `0.8.20`
- 使用主网 Uniswap V2 `Factory`、`Router`、`WETH` 常量地址
- 通过低侵入方式兼容默认测试：未提供 fork 环境时自动跳过相关测试

## Security Assumptions

- 该模块用于教学和接口示例，不作为生产级路由器封装或流动性管理器
- 与真实 Uniswap V2 合约交互仅在测试 fork 环境下验证
- 示例合约保留 LP 或换回资产，便于观察结果，不实现完整的多用户归属与提取流程

## Conflicts / Ambiguities

- issue 未明确要求本地 mock 还是真实协议交互；基于正文和 comment 中均使用主网地址，本次按“主网 fork + 真实接口交互”实现
- issue 示例给出的是 Truffle 风格测试；本次统一转换为 Foundry 风格
- 资金准备方式从 comment 中的 whale 直调迁移到 Foundry 可稳定复现的模式：
- `WETH/DAI` 相关测试使用 `WETH.deposit()` 与 DAI whale 转账
- `WBTC/DAI` swap 测试使用 WBTC whale 授权与真实三跳路径报价

## Recommended Review Order

1. `docs/issues/14/issue-analysis.md`
2. `docs/issues/14/handoff.md`
3. `docs/issues/14/architecture.md`
4. `test/20-uniswap-v2/UniswapV2LiquidityExample.t.sol`
5. `test/20-uniswap-v2/UniswapV2SwapExample.t.sol`
6. `test/20-uniswap-v2/UniswapV2OptimalZap.t.sol`
7. `src/20-uniswap-v2/UniswapV2LiquidityExample.sol`
8. `src/20-uniswap-v2/UniswapV2SwapExample.sol`
9. `src/20-uniswap-v2/UniswapV2OptimalZap.sol`
10. `src/20-uniswap-v2/interfaces/IUniswapV2.sol`
11. `docs/issues/14/verification.md`
