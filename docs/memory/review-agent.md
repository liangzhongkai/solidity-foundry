# ReviewAgent Memory

Project-centric state for quality bar and review consistency. Load at start, update at end.

## Quality Bar Expectations

- NatSpec on public/external; custom errors; forge fmt.
- Tests cover happy path and key revert cases.

## Prior Review Findings

- AdvancedERC20 (#12): All quality checks pass; 57 tests; NatSpec complete; custom errors throughout.
- Issue #14: For fork-only teaching modules, distinguish between verifying the clean skip path and verifying live protocol interaction. If the environment cannot reach forked contracts, record that the happy path remains unproven in that run and call out any untested local guard rails explicitly.
- Issue #14 follow-up: when issue comments expand a protocol-demo scope, update the issue packet and validation evidence to enumerate each new flow separately rather than folding everything into one "integration test" claim.

## Testing Blind Spots

- blockhash availability: tests must vm.roll(drawBlock+1) not vm.roll(drawBlock).
- Refund with multiple participants: verify swap-with-last in _removeParticipant.
- AccessControl role tests: vm.prank may not work with _msgSender() in inherited contracts; use simpler verification.
- Live AMM comparisons should avoid assertions that mix token units directly; prefer route correctness, revert guards, and relative LP or output comparisons.
- Issue #14: when a swap demo advertises both direct-WETH and WETH-routed paths, keep one test for each path plus one local guard-path test so the review packet proves routing and input validation separately.

## Last Updated

- Issue #14, 2026-03-16 follow-up review pass
