# Issue Analysis

## Issue Summary

- Issue: `#8 - task: 新建一个合约Stake Together`
- Branch: `issue-8-stake-together`
- Analyst: `IssueAgent`
- Requested change: 新建 Stake Together 合约：合约持有 1,000,000 cloud coins 作为奖励池；用户从 beginDate 起可质押 cloud coin，持有满 7 天后在 expiration 时按质押份额比例领取奖励。

## Extracted Requirements

- 合约持有 1,000,000 cloud coins 作为奖励池。
- 从 beginDate 起用户可质押 cloud coin。
- 用户必须持有质押满 7 天才能在 expiration 时领取奖励。
- 奖励按 expiration 时用户质押占总质押的比例分配（例：Alice 质押 5,000，总质押 25,000 → Alice 得 20% = 200,000 奖励）。
- 需防范恶意利用奖励计算逻辑的攻击（issue 明确警告）。

## Acceptance Criteria

- 合约初始化时持有 1M cloud coins，并设置 beginDate、expiration。
- 用户在 [beginDate, expiration - 7 days] 内可质押，且不能晚于 expiration - 7 days 质押（防止最后一刻抢份额）。
- 在 expiration 之后用户可提取：本金 + 按份额计算的奖励。
- 奖励计算使用 expiration 时的快照（totalStaked、各用户 stake），避免操纵。
- 测试覆盖正常流程、比例正确性、以及典型攻击场景（如最后一刻质押、重复领取）。

## Existing System Context

- Impacted modules:
  - 新建 `src/14-stake-together/`（StakeTogether + CloudCoin）
  - 新建 `test/14-stake-together/StakeTogether.t.sol`
- Existing behaviors or constraints:
  - 仓库已有 ERC20、Crowdfunding、TokenVesting 等模式，可复用 SafeERC20、ReentrancyGuard。
  - 需支持标准 ERC20（非 fee-on-transfer、非 rebasing）。
- Relevant prior decisions:
  - `docs/issues/README.md` 要求 issue 级别 review packet。
  - `.cursor/rules/solidity-architecture-and-design.mdc` 要求架构图与设计说明。

## Conflict Check

### No Conflict

- 新建模块，无与现有合约的功能冲突。

### Potential Conflicts

- 无。

## User Confirmation Required

- 无进一步确认项。需求明确，安全约束已在 issue 中强调。

Status:

- `confirmed`

## Recommended Approach

- 实现 CloudCoin ERC20（或测试用 Mock）和 StakeTogether 合约。
- 安全设计：
  1. 质押窗口 [beginDate, expiration - 7 days]，禁止在最后 7 天内质押。
  2. 在 expiration 时快照 totalStaked 和各用户 stake，奖励按 `rewardPool * userStake / totalStaked` 计算，向下取整。
  3. 提取时先更新状态再转账，使用 ReentrancyGuard。
  4. 每人仅可领取一次，领取后清零其 stake 记录。
- 非目标：多期质押、可变奖励池、治理、手续费。

## Files To Read First

1. `docs/issues/8/issue-analysis.md`
2. `src/11-crowdfunding/Crowdfunding.sol`
3. `src/08-vesting/TokenVesting.sol`
4. `test/11-crowdfunding/Crowdfunding.t.sol`

## Quick Review Guide

- Start with `Extracted Requirements` to understand what the issue is really asking for.
- Read `Conflict Check` before reviewing any implementation.
- Use `Files To Read First` to inspect current behavior quickly.

## IssueAgent Summary

### What It Did

- 提取了奖励池规模、质押窗口、7 天持有期、比例分配等显式需求。
- 识别了“最后一刻质押”等攻击向量，并纳入设计约束。
- 明确了 expiration 快照和单次领取的验收条件。

### Why It Matters

- 奖励计算若设计不当，易被操纵；先固化安全约束可避免实现偏差。

### Residual Uncertainty

- 无额外需求歧义；剩余风险通过测试覆盖验证。
