# Agent Memory

Each agent has a persistent memory file here (`<agent>.md`) that records project-centric state. Agents load memory at start and update it at end to coordinate across the workflow.

- **issue-agent.md** – Product direction, accepted/rejected directions, cross-issue requirements
- **dev-agent.md** – Architecture, module boundaries, design tradeoffs, code style, test strategy
- **security-agent.md** – Attack patterns, exploitation preconditions, defensive techniques
- **review-agent.md** – Quality bar, prior review findings, testing blind spots
- **deploy-agent.md** – Release hygiene, handoff completeness, validation flow

If a file does not exist, the agent creates it from `docs/templates/memory-<agent>.md` on first run.
