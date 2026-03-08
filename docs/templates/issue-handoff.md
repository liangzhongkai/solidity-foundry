# Issue Handoff Template

Use this file as `docs/issues/<issue-number>/handoff.md`.

## Issue

- Issue: `#<number> - <title>`
- Branch: `issue-<number>-<slug>`
- Base commit: `<sha>`
- Scope: `<what this change is supposed to do>`
- Non-goals: `<what this change intentionally does not cover>`

## Prerequisite Issue Analysis

- Analysis file: `docs/issues/<issue-number>/issue-analysis.md`
- Confirmation status: `<confirmed / blocked pending confirmation / no confirmation needed>`
- Key conflict note: `<short summary of any confirmed conflict or "No material conflict detected">`

## Changed Behavior

### Before

- `<old behavior or gap>`

### After

- `<new behavior>`

### Why This Approach

- `<design rationale>`

## Files To Read First

1. `<tests to start with>`
2. `<primary implementation files>`
3. `<supporting files or docs>`

## DevAgent

### Summary

- `<what was implemented>`

### Files Changed

- `<file path>`

### Tests Added Or Updated

- `<test path>`

### Open Questions

- `<anything still uncertain>`

## SecurityAgent

### Findings

- `<finding or "No material findings">`

### Why It Matters

- `<impact on funds, permissions, state, or integrations>`

### Test Or Proof

- `<regression test, invariant, fuzz, or analysis evidence>`

### Residual Risk

- `<what still deserves human attention>`

## ReviewAgent

### Findings

- `<review finding or "No material findings">`

### Why It Matters

- `<why reviewer should care>`

### Test Or Proof

- `<tests, code reasoning, or validation evidence>`

### Residual Risk

- `<remaining edge cases or caveats>`

## DeployAgent

### SlackMessage (if MCP unavailable)

- `<Issue #X ready for review on branch X. Changes: 1) ... 2) ... 3) ...>`

### Release Readiness

- `<ready / blocked>`

### Validation Summary

- `<high-level pass/fail summary>`

### User Test Request

- `<what the human should verify manually>`

## Open Risks

- `<risks to inspect closely>`

## Suggested Reading Order

1. `docs/issues/<issue-number>/issue-analysis.md`
2. `<before/after section>`
3. `<tests>`
4. `<implementation>`
5. `<security/review findings>`
