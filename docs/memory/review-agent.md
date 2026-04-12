# ReviewAgent Memory

Project-centric state for quality bar and review consistency. Load at start, update at end.

## Quality Bar Expectations

- NatSpec on public/external; custom errors; forge fmt.
- Tests cover happy path and key revert cases.

## Prior Review Findings

- AdvancedERC20 (#12): All quality checks pass; 57 tests; NatSpec complete; custom errors throughout.
- Issue #14: For fork-only teaching modules, distinguish between verifying the clean skip path and verifying live protocol interaction. If the environment cannot reach forked contracts, record that the happy path remains unproven in that run and call out any untested local guard rails explicitly.
- Issue #14 follow-up: when issue comments expand a protocol-demo scope, update the issue packet and validation evidence to enumerate each new flow separately rather than folding everything into one "integration test" claim.
- Issue #16: when V4 singleton execution is environment-limited, pair skip-capable fork tests with deterministic mock-backed wrapper tests so the review packet still proves local correctness rather than only compilation.
- Issue #17: gas microbenchmarks are compiler-sensitive; README index + console logs are part of the review contract when strict `assertLt` is intentionally omitted. When reviewing gas teaching modules, verify every implemented contract pair has at least a log-only test — code-without-test hides both breakage and teaching gaps.

## Testing Blind Spots

- blockhash availability: tests must vm.roll(drawBlock+1) not vm.roll(drawBlock).
- Refund with multiple participants: verify swap-with-last in _removeParticipant.
- AccessControl role tests: vm.prank may not work with _msgSender() in inherited contracts; use simpler verification.
- Live AMM comparisons should avoid assertions that mix token units directly; prefer route correctness, revert guards, and relative LP or output comparisons.
- Issue #14: when a swap demo advertises both direct-WETH and WETH-routed paths, keep one test for each path plus one local guard-path test so the review packet proves routing and input validation separately.
- Issue #15: V3 modules should document fork skip behavior, canonical periphery addresses (especially NPM), and that tick windows are constructed relative to live `slot0` in tests.
- Issue #16: for V4 singleton wrappers, review both the raw callback path and the higher-level Permit2/router path; subtle settlement or spender mistakes can hide behind pure calldata-encoding tests unless wrapper logic is mocked end-to-end.
- Issue #17: outer `gasleft()` wrappers include contract `new` overhead in some tests; do not read logged numbers as steady-state hot-path costs without isolating setup.

## Last Updated

- Issue #17, 2026-04-12: second review pass — fixed README `RsgCross01` symbol mismatch, added 14 gas tests (38→52) covering all previously untested contract pairs, improved NatSpec on `RsgBook01Good`, added deployment-cost comparison for `Dep06` clone pattern, added gas-logging variant for `Solc11` short-circuit. Full suite 496/0/33.
