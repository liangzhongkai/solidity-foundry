# Issue Handoff

## Issue

- Issue: `#8 - task: 新建一个合约Stake Together`
- Branch: `issue-8-stake-together`
- Base commit: `main`
- Scope: 新建 StakeTogether 合约，用户质押 cloud coin 满 7 天后按份额领取 1M 奖励池。
- Non-goals: 多期质押、可变奖励池、治理、手续费。

## Prerequisite Issue Analysis

- Analysis file: `docs/issues/8/issue-analysis.md`
- Confirmation status: `confirmed`
- Key conflict note: No material conflict detected.

## Changed Behavior

### Before

- 无 StakeTogether 模块。

### After

- CloudCoin ERC20 代币，支持 mint 用于测试/初始分配。
- StakeTogether 合约：从 beginDate 起可质押，质押窗口为 [beginDate, expiration - 7 days)；expiration 后可按份额领取本金 + 奖励；奖励池 1M cloud coins。

### Why This Approach

- 禁止最后 7 天内质押，防止抢份额攻击。
- 首次 withdraw 时快照 totalStaked，奖励按比例向下取整，避免操纵。
- 首次 stake 时检查奖励池是否充足，部署后需先转入 1M 代币。

## Files To Read First

1. `test/14-stake-together/StakeTogether.t.sol`
2. `src/14-stake-together/StakeTogether.sol`
3. `src/14-stake-together/CloudCoin.sol`

## DevAgent

### Summary

- 实现 CloudCoin 与 StakeTogether，包含质押窗口、快照、比例奖励、ReentrancyGuard。
- 测试覆盖正常流程、比例正确性、攻击场景（最后一刻质押、重复领取、奖励池不足）。

### Files Changed

- `src/14-stake-together/CloudCoin.sol` (new)
- `src/14-stake-together/StakeTogether.sol` (new)
- `test/14-stake-together/StakeTogether.t.sol` (new)
- `docs/issues/8/issue-analysis.md` (new)
- `docs/issues/8/architecture.md` (new)
- `docs/issues/8/handoff.md` (new)

### Tests Added Or Updated

- `test/14-stake-together/StakeTogether.t.sol` (17 tests)

### Open Questions

- 无。

## SecurityAgent

### Findings

- No material findings. 最后一刻质押、重复领取、奖励池不足均已通过测试覆盖。

### Why It Matters

- 奖励计算若设计不当易被操纵；当前设计通过窗口限制与快照避免。

### Test Or Proof

- `test_Attack_LastMinuteStake_Blocked`, `test_Attack_StakeExactlyAtDeadline_Blocked`, `test_Withdraw_RevertsDoubleWithdraw`, `test_Stake_RevertsInsufficientRewardPool`.

### Residual Risk

- 仅支持标准 ERC20；fee-on-transfer、rebasing 代币未考虑。

## ReviewAgent

### Findings

- No material findings.

### Why It Matters

- 实现符合 issue 与架构设计。

### Test Or Proof

- 17 tests pass; `forge fmt` applied.

### Residual Risk

- 无。

## DeployAgent

### Release Readiness

- ready

### Validation Summary

- `forge fmt` applied
- `forge build` success
- `forge test --match-path test/14-stake-together/StakeTogether.t.sol` 17 passed
- 全量 `forge test` 中 3 个 FFI 相关测试需 `--ffi`，与本次改动无关

### User Test Request

- 运行 `forge test --match-path test/14-stake-together/StakeTogether.t.sol` 确认通过。
- 手动验证部署流程：部署 CloudCoin → 转入 1M 至 StakeTogether → 设置 beginDate/expiration（间隔 > 7 天）。

## Open Risks

- 无。

## Suggested Reading Order

1. `docs/issues/8/issue-analysis.md`
2. `docs/issues/8/architecture.md`
3. `test/14-stake-together/StakeTogether.t.sol`
4. `src/14-stake-together/StakeTogether.sol`
