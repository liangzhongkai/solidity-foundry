# Issue #13: 新增重入攻击案例

## Issue Intent

补充完善三个重入攻击教学案例：

1. **经典重入**：VulnerableVault（受害）+ ClassicAttack（攻击）+ SafeVault（修复）
2. **Read-only 重入**：PriceOracle + LendingProtocol（信任 oracle）+ ReadOnlyAttack
3. **跨合约重入**：TokenPool + RewardDistributor + CrossContractAttack

## Acceptance Criteria

- 三个案例的合约代码完整可编译
- 每个案例包含：受害合约、攻击合约、修复方案
- 配套 Foundry 测试验证攻击可行性与修复有效性

## Current Behavior

- 项目已有 `src/10-design-patterns/security/` 下的 SecurityPatterns、PatternVault 等安全模式
- 尚无专门的重入攻击教学示例（vulnerable + attack + fixed 三件套）

## Impacted Modules

- 新增 `src/19-reentrancy/` 模块
- 新增 `test/19-reentrancy/` 测试

## Architecture Constraints

- 每个案例自包含，不依赖其他业务模块
- 使用 Solidity 0.8.20（与 foundry.toml 一致）
- 遵循 CEI、nonReentrant 等既有安全模式

## Security Assumptions

- 教学用途，合约部署于测试网或本地
- 攻击合约用于演示漏洞，修复版用于对比

## Conflicts / Ambiguities

- 无冲突
- Read-only 案例中价格公式与攻击方向需与 issue 描述一致；若公式导致攻击难以复现，以演示「view 在中间态被调用」为核心目标

## Recommended Review Order

1. `issue-analysis.md`（本文件）
2. `handoff.md`
3. `architecture.md`
4. `src/19-reentrancy/*.sol`
5. `test/19-reentrancy/*.t.sol`
6. `verification.md`
