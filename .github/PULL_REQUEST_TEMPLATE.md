## Issue

- Issue: `#<number> - <title>`
- Branch: `issue-<number>-<slug>`
- Scope: `<what this PR is intended to solve>`
- Out of scope: `<what this PR intentionally does not change>`
- Issue analysis: `docs/issues/<issue-number>/issue-analysis.md`

## Summary

- `<one-sentence purpose>`
- `<key behavior change>`
- `<design or implementation rationale>`

## Agent Handoffs

- Issue analysis file: `docs/issues/<issue-number>/issue-analysis.md`
- Handoff file: `docs/issues/<issue-number>/handoff.md`
- Verification file: `docs/issues/<issue-number>/verification.md`
- Architecture digest: `docs/issues/<issue-number>/architecture.md` if behavior, state flow, or trust boundaries changed

## Files To Read First

1. `docs/issues/<issue-number>/issue-analysis.md`
2. `<tests>`
3. `<primary implementation files>`
4. `<supporting docs>`

## Issue Conflict Check

- [ ] `IssueAgent` found no material conflict with existing requirements or system behavior
- [ ] `IssueAgent` found conflicts and explicit user confirmation was captured before development

## Design / Diagram Updated

- [ ] No architecture-impacting change
- [ ] Updated `docs/issues/<issue-number>/architecture.md`

## Validation Evidence

- [ ] `forge test --match-path "<path>"`
- [ ] `forge test`
- [ ] `forge fmt --check`
- [ ] Additional security/adversarial validation recorded in `verification.md`

## Security Findings

- `<No material findings, or summarize findings and mitigations>`

## User Test Request

- `<what a human should verify manually before merge>`
