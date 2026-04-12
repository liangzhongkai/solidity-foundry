# DeployAgent Memory

Project-centric state for release hygiene and handoff. Load at start, update at end.

## Release Hygiene

- Branch: `issue-17-rareskills-gas-optimization` from main (prior: `issue-16-uniswap-v4-mev-example`).
- Commit when validation passes; do not merge without user approval.

## Handoff Completeness

- handoff.md: Issue, Changed Behavior, Files To Read First, DevAgent, Open Risks, SlackMessage.
- verification.md: commands, pass/fail, blocker status.
- architecture.md: when issue changes behavior/state flow.

## Validation Flow

1. `forge fmt` and `forge fmt --check`
2. `forge test --match-path "test/22-uniswap-v4/*.t.sol" -vv`
3. `forge test --match-path "test/22-uniswap-v4/UniswapV4WrapperUnit.t.sol" -vv`
4. `forge test --ffi`
5. Attempt targeted fork validation for V4 and record whether transient-storage runtime support blocks `PoolManager.unlock()`
6. `verification.md` with exact commands and results

## Merge Authorization Rules

- Do not merge into main until user explicitly approves.
- DeployAgent may commit on issue branch; push/merge only after user confirmation.
- When user approves merge: merge -> close GitHub issue -> push main to remote. Do not stop before push.

## Slack Fallback Rule

If Slack MCP is unavailable:
1. Record the exact Slack message in `docs/issues/<n>/handoff.md` under SlackMessage.
2. Tell the user exactly: `请手动在 Slack 发送以下消息`
3. Paste the full message that must be sent.

## Validation Gates

For Solidity issue work:
1. forge fmt
2. forge fmt --check
3. targeted tests should enumerate each touched Uniswap demo flow rather than only one file
4. real fork validation for integration-heavy modules
5. forge test --ffi before handoff when the repo includes FFI-based tests
6. Slither analysis when configured

Never claim a bug is fixed without a test or other verifiable proof.

## Working Rules

- Respect existing workspace changes and do not revert unrelated user work.
- Prefer compressed review artifacts over long prose transcripts.
- Commit docs/memory/*.md updates together with the issue implementation commit.
- If no architecture digest is needed, say so explicitly in handoff.

## Last Updated

- Issue #17, 2026-04-12: user approved merge; `main` fast-forwarded and **pushed** to `origin` (`cca56bd`). GitHub issue **#17** could not be closed via `gh` (CLI not logged in) — user should close on github.com if still open. See `docs/issues/17/verification.md` post-merge table.
