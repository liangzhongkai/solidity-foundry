# Issue Review Packets

Each issue should create a folder under `docs/issues/<issue-number>/` with a small review packet for humans.

Recommended files:

- `issue-analysis.md`
  Written by `IssueAgent` before implementation. It captures extracted requirements, acceptance criteria, system context, conflict checks, and any user confirmation required before `DevAgent` can begin.
- `handoff.md`
  Summary of what changed, which agent produced which output, what to read first, and any open risks.
- `verification.md`
  Commands run, scope, pass/fail status, and blocker status for tests, formatting, and security checks.
- `architecture.md`
  Required only when the issue changes behavior, state flow, permissions, module boundaries, or external interactions.

Suggested review order:

1. `issue-analysis.md`
2. `handoff.md`
3. `architecture.md` if present
4. changed tests
5. implementation files
6. `verification.md`
