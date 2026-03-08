# Review Checklist Template

Adapt this checklist for a specific issue or PR. Keep it short enough that a human reviewer can use it in a few minutes.

## Verification Matrix

- Unit tests:
  `<test paths>`
- Fuzz tests:
  `<test paths>`
- Invariant tests:
  `<test paths>`
- Security tooling:
  `<slither / echidna / manticore / ffi / fork>`

## Verification Commands

- Run targeted tests for the touched area:
  `forge test --match-path "<path>"`
- Run the full suite before handoff:
  `forge test`
- Check formatting:
  `forge fmt --check`
- Run any stronger mode that matters for this issue:
  `<security or adversarial command>`

## Review Checklist

- Start with `docs/issues/<issue-number>/issue-analysis.md` and confirm the issue was clarified before implementation started.
- Check whether `IssueAgent` identified requirement conflicts, architecture drift, or prior-decision mismatches.
- If `User Confirmation Required` is unresolved, stop review and do not approve implementation work yet.
- Start with the tests that define the changed behavior.
- Confirm the implementation matches the issue scope and non-goals.
- Inspect permissions, state transitions, accounting, and external calls first.
- Check whether architecture, data flow, or trust boundaries changed.
- Verify the handoff and verification files match the actual diff.
- Note any skipped checks, residual risk, or manual test requests.

## Suggested Reading Order

1. `docs/issues/<issue-number>/issue-analysis.md`
2. `docs/issues/<issue-number>/handoff.md`
3. `docs/issues/<issue-number>/architecture.md` if present
4. Changed tests
5. Primary implementation files
6. `docs/issues/<issue-number>/verification.md`

## Production Caveat

- Human approval is still required for semantics, security judgment, and merge readiness.
