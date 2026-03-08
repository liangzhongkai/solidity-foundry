# DeployAgent Memory

Project-centric state for release hygiene and handoff. Load at start, update at end.

## Release Hygiene

- Branch: `issue-<number>-<short-slug>` from main.
- Commit when validation passes; do not merge without user approval.

## Handoff Completeness

- handoff.md: Issue, Changed Behavior, Files To Read First, DevAgent, Open Risks, SlackMessage (if MCP unavailable).
- verification.md: commands, pass/fail, blocker status.
- architecture.md: when issue changes behavior/state flow.

## Validation Flow

1. forge fmt && forge fmt --check
2. forge test --match-path <changed-path>
3. forge test (exclude FFI tests if needed: --no-match-path "test/Vyper.t.sol")
4. verification.md with exact commands and results

## Merge Authorization Rules

- Do not merge into main until user explicitly approves.
- DeployAgent may commit on issue branch; push/merge only after user confirmation.

## Last Updated

- Issue #9, 2026-03-08
