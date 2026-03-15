# Issue #13 Handoff

## Issue

新增重入攻击案例：经典重入、read-only 重入、跨合约重入。

## Changed Behavior

- 新增 `src/19-reentrancy/` 模块，包含三组合约：
  1. **ClassicReentrancy.sol**: VulnerableVault, ClassicAttack, SafeVault
  2. **ReadOnlyReentrancy.sol**: PriceOracle, LendingProtocol, ReadOnlyAttack, SafePriceOracle
  3. **CrossContractReentrancy.sol**: TokenPool, RewardDistributor, CrossContractAttack, SafeTokenPool
- 新增 `test/19-reentrancy/Reentrancy.t.sol`，4 个测试覆盖攻击与修复。

## Files To Read First

- `src/19-reentrancy/ClassicReentrancy.sol`
- `src/19-reentrancy/ReadOnlyReentrancy.sol`
- `src/19-reentrancy/CrossContractReentrancy.sol`
- `test/19-reentrancy/Reentrancy.t.sol`

## DevAgent

- 实现与 issue 描述一致
- 测试验证攻击可行性与 SafeVault 修复有效

## Architecture

- **Status**: required and updated
- **Path**: `docs/issues/13/architecture.md`

## Open Risks

- 教学用途，合约仅用于演示，不用于生产

## SlackMessage

- **IssueAgent start**: `Starting issue #13: 新增重入攻击案例. Breakdown: 1) 经典重入 VulnerableVault/ClassicAttack/SafeVault 2) read-only重入 PriceOracle/LendingProtocol/ReadOnlyAttack 3) 跨合约重入 TokenPool/RewardDistributor/CrossContractAttack` — **sent via MCP**
- **DeployAgent ready**: `Issue #13 ready for review on branch issue-13-reentrancy-cases. Changes: 1) 经典重入 VulnerableVault/ClassicAttack/SafeVault 2) read-only重入 PriceOracle/LendingProtocol/ReadOnlyAttack 3) 跨合约重入 TokenPool/RewardDistributor/CrossContractAttack` — **sent via MCP**

## Findings (SecurityAgent / ReviewAgent)

### SecurityAgent
- **No material findings**: 受害合约为教学用途故意保留漏洞；修复版遵循 CEI 与 nonReentrant，未见可利用缺陷。

### ReviewAgent
- **No material findings**: NatSpec 完整，测试覆盖攻击与修复，forge fmt 通过；FFI 测试需 --ffi，与本次改动无关。
