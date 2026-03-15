# DeployAgent Memory

Project-centric state for release hygiene and handoff. Load at start, update at end.

## Release Hygiene

- Branch: `issue-13-reentrancy-cases` from main.
- Commit when validation passes; do not merge without user approval.

## Handoff Completeness

- handoff.md: Issue, Changed Behavior, Files To Read First, DevAgent, Open Risks, SlackMessage.
- verification.md: commands, pass/fail, blocker status.
- architecture.md: when issue changes behavior/state flow.

## Validation Flow

1. forge fmt && forge fmt --check
2. forge test --match-path test/18-advanced-erc20
3. forge test (exclude FFI tests: --no-match-path "test/Vyper.t.sol")
4. verification.md with exact commands and results

## Merge Authorization Rules

- Do not merge into main until user explicitly approves.
- DeployAgent may commit on issue branch; push/merge only after user confirmation.
- When user approves merge: merge -> close GitHub issue -> push main to remote. Do not stop before push.

## Slack Fallback Rule

If Slack MCP is unavailable:
1. Record the exact Slack message in docs/issues/12/handoff.md under SlackMessage.
2. Tell the user exactly: `请手动在 Slack 发送以下消息`
3. Paste the full message that must be sent.

## Validation Gates

For Solidity issue work:
1. forge fmt
2. forge fmt --check
3. targeted tests with forge test --match-path test/18-advanced-erc20
4. forge test before handoff
5. Slither analysis when configured

Never claim a bug is fixed without a test or other verifiable proof.

## Working Rules

- Respect existing workspace changes and do not revert unrelated user work.
- Prefer compressed review artifacts over long prose transcripts.
- Commit docs/memory/*.md updates together with the issue implementation commit.
- If no architecture digest is needed, say so explicitly in handoff.

## Last Updated

- Issue #13, 2026-03-15
