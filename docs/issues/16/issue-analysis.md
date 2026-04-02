# Issue #16: task: 新增案例：覆盖测试uniswap V4的接口和使用技巧

## Summary

Add a new standalone Foundry teaching module for Uniswap V4 that is useful from an MEV-bot/searcher perspective, analogous to the existing `20-uniswap-v2` and `21-uniswap-v3` modules. The issue intent is clear at a high level, but the requested scope is ambiguous because "cover all interfaces" for V4 is materially broader than the prior teaching modules and the repository currently has no V4 dependencies.

## Extracted requirements

- Add a new Uniswap V4 example module to this repo.
- Emphasize usage from an MEV-bot / searcher point of view rather than a retail-user point of view.
- Include tests that demonstrate interface usage and practical integration tips.

## Acceptance criteria draft

- New numbered module under `src/` with matching tests under `test/`, following the existing Uniswap teaching pattern.
- Tests explain how the chosen V4 interfaces are used and what a searcher/MEV-style integration must pay attention to.
- Default local test runs should remain reviewable even when live fork infrastructure is unavailable.

## Current repo context

- `src/20-uniswap-v2/` and `src/21-uniswap-v3/` already establish the expected pattern: thin demo wrappers, minimal local interfaces, fork-oriented tests, and docs packets under `docs/issues/<n>/`.
- The repo currently contains no Uniswap V4 module, dependencies, remappings, or prior tests.
- `foundry.toml` is pinned to Solidity `0.8.20`, which may constrain whether we can import V4 packages directly versus defining minimal local interfaces.

## Impacted areas

- New Uniswap V4 teaching module under `src/`.
- Matching Foundry tests under `test/`.
- Issue workflow docs under `docs/issues/16/`.
- Agent memory updates for the workflow.

## Confirmed scope

The user confirmed the following implementation direction:

- **Coverage breadth**: broad on-chain coverage, not a tiny single-flow demo.
- **MEV angle**: on-chain examples plus searcher-style simulation/testing patterns, without building a full off-chain bot framework.
- **Dependency strategy**: choose the best fit after implementation investigation.
- **Test network**: Ethereum mainnet.

## Final implementation decision

- Keep the repository on Solidity `0.8.20` and avoid adding the full official V4 packages, because the canonical V4 core/periphery sources target a newer compiler.
- Implement a minimal local V4 interface bundle plus thin teaching wrappers, mirroring the repo's V2/V3 style.
- Cover the most MEV-relevant on-chain surfaces:
  direct singleton `PoolManager` flows, `StateView` reads, Universal Router exact-input swaps, and PositionManager command encoding / liquidity operations.
- Add two layers of tests:
  default unit-style wrapper tests using mocks, and fork-oriented mainnet suites that cleanly skip when live V4 bytecode is absent.

## Remaining review note

- Live V4 fork execution is still environment-sensitive because `PoolManager.unlock()` depends on transient-storage support. The default suite is green, but the review packet should explicitly call out that real mainnet-fork execution remained unproven in this environment.

## Fast reading order

1. `docs/issues/15/issue-analysis.md`
2. `docs/issues/15/handoff.md`
3. `docs/issues/15/architecture.md`
4. `src/21-uniswap-v3/interfaces/IUniswapV3.sol`
5. `test/21-uniswap-v3/*.t.sol`
