# Issue #17: RareSkills gas optimization article → code cases

## Summary

[GitHub #17](https://github.com/liangzhongkai/solidity-foundry/issues/17) asks for a new teaching module that turns each gas-optimization bullet from the RareSkills article ([Gas Optimization](https://rareskills.io/post/gas-optimization)) into an identifiable **code case**, preferably with **gas before/after** commentary and measurable comparisons where the EVM and Solidity `0.8.20` toolchain make that meaningful.

## Extracted requirements

- Source article: `https://rareskills.io/post/gas-optimization` (TOC lists the section buckets and numbered tips).
- For each enumerated tip in the article TOC, provide a **code case** (contract, library, or documented harness) tied to that tip.
- Prefer **gas comparisons** (naive vs optimized pattern) and **inline comments** explaining the trade-off.
- Some bullets are **architectural**, **client/transaction**-level (for example ERC-2930 access lists), **deployment-artifact**-level, or **explicitly dangerous / outdated**: those cases are implemented as **documented stubs or warnings** rather than production recommendations.

## Acceptance criteria (implemented interpretation)

- New numbered module `src/23-rareskills-gas-optimization/` plus matching tests under `test/23-rareskills-gas-optimization/`.
- `README.md` in the module maps **every TOC bullet** (introductory bullets + numbered lists per section) to a **symbol name** (contract or library) so reviewers can trace article → code 1:1.
- Foundry tests demonstrate **gas deltas** for the locally measurable patterns; non-measurable items are covered by **NatSpec + README** with rationale.

## Scope notes / ambiguity

- The article itself warns that many micro-optimizations are **context- and compiler-dependent**; tests therefore **log** comparisons and only **assert** ordering when the pattern is stable on `0.8.20` with the repo optimizer settings.
- “Every bullet as a full standalone production system” (for example full L2 bridging, state channels, or bytecode appending tricks) is out of proportion for this repo; the implementation instead provides **minimal teaching surfaces** per bullet.

## Fast reading order

1. `src/23-rareskills-gas-optimization/README.md`
2. `test/23-rareskills-gas-optimization/RareSkillsGasBasics.t.sol`
3. `docs/issues/17/architecture.md`
