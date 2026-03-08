# Issue Analysis Template

Use this file as `docs/issues/<issue-number>/issue-analysis.md`.

## Issue Summary

- Issue: `#<number> - <title>`
- Branch: `issue-<number>-<slug>`
- Analyst: `IssueAgent`
- Requested change: `<what the issue is asking for>`

## Extracted Requirements

- `<explicit requirement>`
- `<implicit requirement inferred from the issue>`

## Acceptance Criteria

- `<condition that must be true when this is done>`
- `<condition that should be tested or demonstrated>`

## Existing System Context

- Impacted modules:
  - `<file or module>`
- Existing behaviors or constraints:
  - `<current behavior, invariant, or trust boundary>`
- Relevant prior decisions:
  - `<prior issue, documented rule, or design constraint>`

## Conflict Check

### No Conflict

- `<write "No material conflict detected" when appropriate>`

### Potential Conflicts

- `<requested behavior vs existing behavior>`
- `<requested behavior vs prior requirement>`
- `<requested behavior vs security or architecture constraint>`

## User Confirmation Required

- `<question that must be answered before DevAgent proceeds>`
- `<default recommendation, if any>`

Status:

- `<confirmed / blocked pending confirmation / no confirmation needed>`

## Recommended Approach

- `<recommended direction for DevAgent once clarified>`
- `<scope limits or non-goals>`

## Files To Read First

1. `<issue-relevant docs or rules>`
2. `<existing tests that describe current behavior>`
3. `<primary implementation files>`

## Quick Review Guide

- Start with `Extracted Requirements` to understand what the issue is really asking for.
- Read `Conflict Check` before reviewing any implementation.
- If `User Confirmation Required` is not resolved, do not start development review.
- Use `Files To Read First` to inspect current behavior quickly.

## IssueAgent Summary

### What It Did

- `<what IssueAgent analyzed>`
- `<what comparisons or conflict checks it performed>`

### Why It Matters

- `<why this analysis changes or protects downstream implementation>`

### Residual Uncertainty

- `<anything the human should still keep in mind>`
