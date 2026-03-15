# Issue #13 Architecture

## Changed Entry Points

- `src/19-reentrancy/` — 新增模块，无修改既有入口

## Affected State / Permission Checks

- 无既有状态或权限变更
- 新模块为独立教学示例

## External Effects / Invariants

- 三组合约均为自包含示例，不依赖其他业务模块
- 攻击合约用于演示漏洞，修复版用于对比

## Diagram

```mermaid
flowchart TB
    subgraph Classic["1. 经典重入"]
        VV[VulnerableVault]
        CA[ClassicAttack]
        SV[SafeVault]
        VV -->|deposit/withdraw 先转后更| CA
        CA -->|receive 重入 withdraw| VV
        SV -->|CEI + nonReentrant| SV
    end

    subgraph ReadOnly["2. Read-only 重入"]
        PO[PriceOracle]
        LP[LendingProtocol]
        ROA[ReadOnlyAttack]
        PO -->|withdraw 先转后更| ROA
        ROA -->|receive 中调用 borrow| LP
        LP -->|getPrice 读到中间态| PO
    end

    subgraph Cross["3. 跨合约重入"]
        TP[TokenPool]
        RD[RewardDistributor]
        CCA[CrossContractAttack]
        TP -->|withdraw 先转后更| CCA
        CCA -->|receive 中 claimReward| RD
        RD -->|shares 未扣减| TP
    end
```

## Reviewer Notes

- 每组示例包含：受害合约、攻击合约、修复版（Classic 有 SafeVault；ReadOnly 有 SafePriceOracle；Cross 有 SafeTokenPool）
- 测试覆盖：攻击成功、修复有效
