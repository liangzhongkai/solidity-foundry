# Issue Handoff

## Issue

- Issue: `#7 - task: 新建一个Simple NFT Marketplace`
- Branch: `issue-7-simple-nft-marketplace`
- Base commit: `d5774ac`
- Scope: `新增一个基于授权转移的 ERC721 marketplace，支持 sell、buy、cancel，并将重复 sell 定义为覆盖旧挂单。`
- Non-goals: `不包含版税、手续费、竞价、批量挂单、离线签名、挂单索引优化。`

## Prerequisite Issue Analysis

- Analysis file: `docs/issues/7/issue-analysis.md`
- Confirmation status: `confirmed`
- Key conflict note: `重复挂单策略已确认采用“覆盖旧挂单并更新价格/过期时间”。`

## Changed Behavior

### Before

- 仓库里没有 NFT marketplace 示例。
- NFT 相关示例只有托管式 `NFTSwap` 与独立的 `FoundryNFT`，没有“授权代扣 + ETH 结算”的卖单流程。

### After

- 新增 `SimpleNFTMarketplace`，卖家可在保持 NFT 自托管的前提下创建固定价格挂单。
- 买家在过期前支付精确 `ETH` 后，合约会校验所有权和授权、删除挂单、转 NFT 给买家，再把 `ETH` 打给卖家。
- 同一卖家对同一枚 NFT 重复 `sell()` 时会覆盖旧挂单。
- 卖家可随时 `cancel()`，过期挂单也可取消。

### Why This Approach

- 用 `seller + nft + tokenId` 作为唯一键可以最直接地表达“同一枚 NFT 只有一条活跃挂单”的确认语义。
- `buy()` 先删除状态再做外部调用，能把双花和重入面压到最小。
- 保持设计最小化，便于作为教学示例阅读和测试。

## Files To Read First

1. `test/13-simple-nft-marketplace/SimpleNFTMarketplace.t.sol`
2. `src/13-simple-nft-marketplace/SimpleNFTMarketplace.sol`
3. `docs/issues/7/architecture.md`

## DevAgent

### Summary

- 实现了 `SimpleNFTMarketplace` 合约，包含 `sell()`、`buy()`、`cancel()` 和 `getListing()`。
- 为覆盖挂单、过期、错误支付、撤销授权、卖家转走 NFT、卖家无法收款等边界补充了定向测试与 fuzz 测试。
- 更新了 issue 分析状态，并补齐 issue 级别架构与验证文档。

### Files Changed

- `docs/issues/7/issue-analysis.md`
- `docs/issues/7/architecture.md`
- `docs/issues/7/handoff.md`
- `docs/issues/7/verification.md`
- `src/13-simple-nft-marketplace/SimpleNFTMarketplace.sol`
- `test/13-simple-nft-marketplace/SimpleNFTMarketplace.t.sol`

### Tests Added Or Updated

- `test/13-simple-nft-marketplace/SimpleNFTMarketplace.t.sol`

### Open Questions

- 无额外需求歧义。

## SecurityAgent

### Findings

- `No material findings`

### Why It Matters

- 该合约的主要风险面在非托管挂单的状态漂移，以及 `buy()` 里的 `ERC721`/`ETH` 外部调用顺序。
- 已重点检查“删除挂单先于外部调用”“授权撤销后不可成交”“卖家转走 NFT 后不可成交”“卖家无法收款时整笔回滚”这几类风险。

### Test Or Proof

- `test_Revert_BuyWhenSellerTransferredNftAway`
- `test_Revert_BuyWhenSellerRevokedApproval`
- `test_Revert_BuyWhenSellerCannotReceiveEther`
- `FOUNDRY_FUZZ_RUNS=512 forge test --match-test testFuzz_BuyTransfersExactPrice --match-path test/13-simple-nft-marketplace/SimpleNFTMarketplace.t.sol`
- `slither src/13-simple-nft-marketplace/SimpleNFTMarketplace.sol --config-file slither.config.json --fail-high`

### Residual Risk

- 因为 NFT 不托管，卖家在挂单后转走 NFT 或撤销授权时，旧挂单会保留到卖家取消或覆盖为止，但无法成交。
- 当前模型使用 push payment；若卖家地址拒收 `ETH`，购买会回滚。这是简单实现的有意取舍。

## ReviewAgent

### Findings

- `No material findings`

### Why It Matters

- 本次实现已经满足 issue 的核心行为，并把最关键的覆盖挂单语义和状态漂移场景编码成测试，降低了后续回归风险。

### Test Or Proof

- `forge test --match-path test/13-simple-nft-marketplace/SimpleNFTMarketplace.t.sol`
- `FOUNDRY_PROFILE=ci forge test`
- `forge fmt --check`

### Residual Risk

- 若后续想把该示例扩展为生产级 marketplace，建议改成 pull payment、增加 listing nonce/ids 与更清晰的索引事件。

## DeployAgent

### Release Readiness

- `ready`

### Validation Summary

- 定向测试通过，fuzz 测试通过，`ci` profile 全量测试通过，`forge fmt --check` 通过，Slither 仅报告信息级提示。

### User Test Request

- 请重点确认你预期的“重复 `sell()` 覆盖旧挂单”语义与当前测试一致。
- 如果你希望示例继续演化成更接近生产的 marketplace，请确认是否要改成卖家提取款项的 pull payment 模式。

## Open Risks

- 非托管挂单天然存在链上状态漂移，旧挂单可能因所有权/授权变化而变成不可成交但仍存在。
- 简化实现未处理手续费、版税和离线签名订单。

## Suggested Reading Order

1. `docs/issues/7/issue-analysis.md`
2. `docs/issues/7/architecture.md`
3. `test/13-simple-nft-marketplace/SimpleNFTMarketplace.t.sol`
4. `src/13-simple-nft-marketplace/SimpleNFTMarketplace.sol`
5. `docs/issues/7/verification.md`
