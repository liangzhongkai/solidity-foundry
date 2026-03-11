---
description: 
alwaysApply: true
---

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build, Test, and Lint Commands

```bash
forge build                          # Compile contracts
forge test                           # Run all tests
forge test --match-path test/Counter.t.sol -vvvvv  # Run specific test file with verbose output
forge test --match-test test_Increment  # Run tests matching a pattern
forge fmt                            # Format Solidity files
forge fmt --check                    # Check formatting (CI uses this)
forge snapshot                       # Generate gas snapshots
```

### Special Test Modes

```bash
# Fork tests (require RPC URL)
forge test --fork-url $MAINNET_FORK_URL --fork-block-number 21000000 --match-path test/Fork.t.sol

# FFI tests (differential testing with Python)
forge test --match-path test/DifferentialTest.t.sol --ffi

# Fuzz tests with more runs
FOUNDRY_FUZZ_RUNS=1000 forge test --match-path test/Fuzz.t.sol
```

### Deploy Commands

```bash
# Simulate deployment
forge script script/Counter.s.sol:CounterScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Deploy to network
forge script script/Counter.s.sol:CounterScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# Deploy and verify on Etherscan
forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/Storage.sol:Storage --broadcast --verify
```

### Pre-commit

```bash
pre-commit install   # Install git hooks (runs fmt check, build, test, slither, echidna, manticore)
```

## Project Structure

- `src/` - Solidity contracts organized by topic:
  - `01-slot-packing/` - Storage slot optimization examples
  - `02-erc20/` - ERC20 implementations including permit and gasless transfers
  - `03-mapping-slot/` - Mapping storage slot calculations
  - `04-proxy/` - Proxy contract patterns
  - `05-receive-fallback/` - receive() and fallback() function examples
  - `06-trade-tokens/` - Token exchange contracts (RareCoin, SkillsCoin)
  - `07-foundry-nft/` - NFT implementation
  - `08-vesting/` - Time-locked ERC20 vesting (1/n tokens over n days)
  - `echidna/` - Contracts for Echidna fuzzing
  - `manticore/` - Contracts for Manticore symbolic execution
- `test/` - Foundry test files (`.t.sol` suffix)
- `script/` - Deployment scripts (`.s.sol` suffix)
- `lib/` - Dependencies (forge-std, solmate, openzeppelin-contracts)

## Testing Patterns

This project demonstrates several Foundry testing patterns:

1. **Unit tests** - Standard tests with `setUp()` and `test_*` functions
2. **Fuzz tests** - Parameterized tests using `testFuzz_*` or parameters with `vm.assume()` and `bound()`
3. **Invariant tests** - Functions named `invariant_*` that run after random sequences of calls
4. **Fork tests** - Tests that fork mainnet state using `--fork-url`
5. **Differential tests** - Compare Solidity vs Python via `vm.ffi()`

## Dependencies

Import paths use versioned remappings:
- `forge-std@1.14.0/Test.sol` - Foundry test utilities
- `openzeppelin-contracts@5.4.0/` - OpenZeppelin contracts
- `solmate@6.8.0/` - Solmate contracts

## Configuration

- Solidity version: `0.8.20` (set in `foundry.toml`)
- Optimizer: enabled with 200 runs
- Fuzz runs: 256 (default)
- CI profile enables FFI for differential tests

## Security Tools

The CI pipeline and pre-commit hooks run:
- **Slither** - Static analysis (`slither . --config-file slither.config.json --fail-high`)
- **Echidna** - Fuzzing (`echidna-test . --contract CounterEchidna --config echidna.yaml`)
- **Manticore** - Symbolic execution (`manticore-verifier src/manticore/CounterManticore.sol`)

## Solidity Style Guide (Condensed)

Follow project consistency first; when unsure, follow Solidity style guide defaults:

- **Formatting**: 4 spaces, no tabs, max line length 120, UTF-8/ASCII source files.
- **Top-level order**: `pragma` -> `import` -> events/errors/interfaces/libraries/contracts.
- **In-contract order**: types -> state vars -> events -> errors -> modifiers -> functions.
- **Function order**: constructor -> `receive` -> `fallback` -> `external` -> `public` -> `internal` -> `private` (`view`/`pure` last within a visibility group).
- **Function modifiers order**: visibility -> mutability -> `virtual` -> `override` -> custom modifiers.
- **Naming**:
  - Contracts/Libraries/Structs/Events/Enums: `CapWords`
  - Functions/Variables/Arguments/Modifiers: `mixedCase`
  - Constants: `UPPER_CASE_WITH_UNDERSCORES`
  - Internal/private helpers may use leading underscore (`_helper`).
- **Whitespace and layout**:
  - One space around operators; no extra spaces inside `()`, `[]`, `{}`.
  - Opening brace on declaration line; closing brace on its own line.
  - `else`/`else if` on same line as prior closing brace.
  - `mapping` has no space before `(`, and array types use `uint[]` (not `uint []`).
- **Strings**: prefer double quotes.
- **Docs**: add NatSpec for public/external ABI-facing functions.
- **Practical rule**: run `forge fmt` before commit; keep style consistent within each file/module.

Reference: https://docs.soliditylang.org/en/latest/style-guide.html

## Cursor Workflow Port

This repository ports the Cursor issue workflow into Claude Code. When the user asks to "solve", "fix", or "implement" a GitHub issue, run the full workflow below instead of treating the request as a simple coding task.

### Required Agent Order

1. `IssueAgent`
2. `DevAgent`
3. `SecurityAgent`
4. `ReviewAgent`
5. `DeployAgent`

If one Claude Code session handles the entire issue, it must execute all five roles in sequence and preserve the same artifacts and decision gates.

### Required Per-Issue Artifacts

Create or update these files under `docs/issues/<issue-number>/`:

- `issue-analysis.md`
- `handoff.md`
- `verification.md`
- `architecture.md` when behavior, state flow, permissions, module boundaries, or external interactions change

In `handoff.md`, always record:

- explicit architecture status: `required and updated` or `not needed`
- the architecture file path or `not needed`
- both Slack message audit entries:
  - `IssueAgent` start message
  - `DeployAgent` ready-for-review message

Review order for humans:

1. `docs/issues/<n>/issue-analysis.md`
2. `docs/issues/<n>/handoff.md`
3. `docs/issues/<n>/architecture.md` when present
4. changed tests
5. changed implementation files
6. `docs/issues/<n>/verification.md`

### Required Per-Agent Memory

Each role must load and update its repo-backed memory file:

- `docs/memory/issue-agent.md`
- `docs/memory/dev-agent.md`
- `docs/memory/security-agent.md`
- `docs/memory/review-agent.md`
- `docs/memory/deploy-agent.md`

If a memory file is missing, create it from `docs/templates/memory-<agent>.md`.

Do not replace this repo-backed memory with Claude Code's built-in agent memory if the goal is parity with the Cursor workflow. The committed markdown files are the source of truth.
Each memory file's current update should explicitly mention the active `Issue #<number>` in `Last Updated` or equivalent current-entry text so hooks can verify the workflow really touched repo memory.

### IssueAgent

- Start from a GitHub issue.
- Create or switch to an issue branch from `main` or a user-specified base.
- Prefer branch name `issue-<number>-<short-slug>`.
- As the first step before analysis, send a Slack message to channel `C0AK5HY73D0` with this exact format:
  `Starting issue #<number>: <short title>. Breakdown: 1) <point> 2) <point> 3) <point>`
- Analyze acceptance criteria, current behavior, impacted modules, prior issue decisions, security assumptions, and architecture constraints.
- Create or update `docs/issues/<issue-number>/issue-analysis.md`.
- Stop and ask the user for confirmation when you detect ambiguity, requirement drift, or conflict.

### DevAgent

- Implement the issue from the current repo state.
- Add or update focused Foundry tests.
- Follow the architecture and design rules in `.cursor/rules/solidity-architecture-and-design.mdc`.
- Create or update `docs/issues/<issue-number>/handoff.md` with `Issue`, `Changed Behavior`, `Files To Read First`, `DevAgent`, and `Open Risks`.
- Create or update `docs/issues/<issue-number>/architecture.md` when required.
- In `handoff.md`, record architecture status explicitly as `required and updated` or `not needed`.

### SecurityAgent

- Review the branch adversarially.
- When a bug is found, encode it as a regression test first, then fix it through the dev flow, and re-check until no material findings remain.
- Record results in `handoff.md` under `Findings`, `Why It Matters`, `Test Or Proof`, and `Residual Risk`.

### ReviewAgent

- Perform the final quality gate against issue intent, modern Solidity and Foundry practices, edge cases, NatSpec expectations, and code quality.
- Fix gaps and rerun validation as needed.
- Record results in `handoff.md` under `Findings`, `Why It Matters`, `Test Or Proof`, and `Residual Risk`.

### DeployAgent

- Run formatting and validation.
- Summarize what changed.
- Commit the issue branch only after validation passes.
- Before prompting the user to test, send a Slack message to channel `C0AK5HY73D0` with this exact format:
  `Issue #<number> ready for review on branch <branch-name>. Changes: 1) <change> 2) <change> 3) <change>`
- Create or update `docs/issues/<issue-number>/verification.md` with exact commands, results, scope, and blocker status.
- Always record both exact Slack texts in `handoff.md` together with whether they were `sent via MCP` or `fallback recorded`.
- Do not merge into `main` until the user explicitly confirms the issue is fully fixed.
- Once the user explicitly approves merge, complete the full merge workflow without stopping: merge branch into `main`, close the GitHub issue, then push `main`.

### Slack Fallback Rule

If Slack MCP is unavailable:

1. Record the exact Slack message in `docs/issues/<issue-number>/handoff.md` under `SlackMessage`.
2. Tell the user exactly: `请手动在 Slack 发送以下消息`
3. Paste the full message that must be sent.

### Validation Gates

For Solidity issue work:

1. `forge fmt`
2. `forge fmt --check`
3. targeted tests with `forge test --match-path ...` or `forge test --match-test ...`
4. `forge test` before handoff unless the user narrowed scope
5. stronger validation when relevant, including Slither, Echidna, Manticore, fuzz, invariant, fork, or FFI modes

Never claim a bug is fixed without a test or other verifiable proof.

### Working Rules

- Respect existing workspace changes and do not revert unrelated user work.
- Prefer compressed review artifacts over long prose transcripts.
- Commit `docs/memory/*.md` updates together with the issue implementation commit.
- If no architecture digest is needed, say so explicitly in handoff or PR text rather than leaving it implicit.

### Claude Code Entry Points

This port uses Claude Code project files to emulate the Cursor experience:

- `.claude/skills/issue-workflow/SKILL.md` for the top-level orchestration playbook
- `.claude/agents/*.md` for `IssueAgent`, `DevAgent`, `SecurityAgent`, `ReviewAgent`, and `DeployAgent`
- `.mcp.json` for project-scoped MCP servers
- `.claude/settings.json` for Claude Code project behavior
- `.claude/hooks/*.py` for executable workflow gates that block incomplete issue-branch completion
