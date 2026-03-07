# Issue Analysis

## Issue Summary

- Issue: `#7 - task: 新建一个Simple NFT Marketplace`
- Branch: `issue-7-simple-nft-marketplace`
- Analyst: `IssueAgent`
- Requested change: `新增一个 NFT Marketplace，卖家通过授权而非托管方式挂单；买家在过期前按标价支付 ETH 后，合约代扣 NFT 给买家并把 ETH 转给卖家；卖家可随时取消挂单。`

## Extracted Requirements

- Marketplace 需要支持 `sell()`，让卖家指定 `NFT`、`tokenId`、价格和过期时间。
- 挂单时 NFT 不转入合约，而是依赖卖家预先对 marketplace 授权。
- Marketplace 需要支持 `buy()`，买家在挂单过期前按指定价格支付 `ETH`。
- 成功购买时，NFT 从卖家转给买家，`ETH` 从合约转给卖家。
- Marketplace 需要支持 `cancel()`，且卖家可以随时取消自己的挂单。
- 需要处理同一卖家对同一枚 NFT 重复 `sell()` 的角落场景。
- 挂单执行前，卖家仍可能转走 NFT、撤销授权、或让挂单过期，合约需要对这些状态变化保持安全行为。

## Acceptance Criteria

- 卖家可以在不托管 NFT 的前提下创建有效挂单，并能在到期前被成功购买。
- `buy()` 只能在挂单未取消、未过期、且付款金额正确时成功。
- 成功购买后，NFT 所有权转移给买家，卖家收到准确的 `ETH`，且挂单不能再次成交。
- 卖家可以取消挂单，取消后该挂单不能再被购买。
- 至少有一个明确且可测试的重复挂单策略。

## Existing System Context

- Impacted modules:
  - `src/07-foundry-nft/FoundryNFT.sol`
  - `test/07-foundry-nft/FoundryNFT.t.sol`
  - `src/09-nft-swap/NFTSwap.sol`
  - `test/09-nft-swap/NFTSwap.t.sol`
- Existing behaviors or constraints:
  - 仓库已有 `ERC721` 示例 `FoundryNFT`，可直接作为 marketplace 集成测试中的 NFT 标的。
  - 仓库已有 `NFTSwap`，展示了 NFT 相关状态建模、事件和测试风格，但它采用托管式交换，不适合直接复用。
  - Foundry 工作流要求补充聚焦测试，并在最终交付前运行 `forge fmt`、定向测试和全量测试。
- Relevant prior decisions:
  - `docs/issues/README.md` 要求 issue 级别 review packet。
  - `.cursor/rules/issue-driven-agent-workflow.mdc` 要求遇到歧义时先停下并向用户确认。

## Conflict Check

### No Conflict

- 需求与当前仓库中已有模块没有直接功能冲突；目前不存在 marketplace 模块。
- 用户已确认重复挂单语义采用“覆盖旧挂单并更新价格/过期时间”。

### Potential Conflicts

- 因为 NFT 不托管到合约，挂单创建后链上真实状态可能变化，若数据结构设计不严谨，可能出现旧挂单仍可见但不可成交的 UX 差异。

## User Confirmation Required

- 无进一步确认项；用户已确认同一枚 NFT 重复 `sell()` 时覆盖旧挂单。

Status:

- `confirmed`

## Recommended Approach

- 在确认重复挂单策略后，实现一个最小 marketplace：按 `seller + nft + tokenId` 建模挂单，`buy()` 时做所有权、授权、过期、价格和活跃状态校验，然后先失效挂单再执行外部转账。
- 非目标：版税、手续费、竞价、批量挂单、部分成交、离线签名、前端索引优化。

## Files To Read First

1. `docs/issues/7/issue-analysis.md`
2. `test/09-nft-swap/NFTSwap.t.sol`
3. `src/09-nft-swap/NFTSwap.sol`
4. `src/07-foundry-nft/FoundryNFT.sol`

## Quick Review Guide

- Start with `Extracted Requirements` to understand what the issue is really asking for.
- Read `Conflict Check` before reviewing any implementation.
- If `User Confirmation Required` is not resolved, do not start development review.
- Use `Files To Read First` to inspect current behavior quickly.

## IssueAgent Summary

### What It Did

- 提取了 issue 的显式需求、隐含安全约束和可验证的验收条件。
- 对照了仓库现有的 `ERC721` 与 `NFTSwap` 示例，识别可复用测试风格与不可复用的托管模型差异。
- 标记了唯一会影响实现策略的需求歧义：重复挂单的预期语义。

### Why It Matters

- 这个 corner case 会直接决定存储键设计、取消逻辑、事件语义和测试断言。
- 先确认可以避免后续实现与用户预期不一致，尤其是在“覆盖旧挂单”与“禁止重复挂单”之间产生行为偏差。

### Residual Uncertainty

- 无额外需求歧义；剩余风险主要在非托管挂单的链上状态漂移，需要通过测试覆盖。
