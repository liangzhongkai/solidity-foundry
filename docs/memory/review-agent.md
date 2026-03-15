# ReviewAgent Memory

Project-centric state for quality bar and review consistency. Load at start, update at end.

## Quality Bar Expectations

- NatSpec on public/external; custom errors; forge fmt.
- Tests cover happy path and key revert cases.

## Prior Review Findings

- AdvancedERC20 (#12): All quality checks pass; 57 tests; NatSpec complete; custom errors throughout.

## Testing Blind Spots

- blockhash availability: tests must vm.roll(drawBlock+1) not vm.roll(drawBlock).
- Refund with multiple participants: verify swap-with-last in _removeParticipant.
- AccessControl role tests: vm.prank may not work with _msgSender() in inherited contracts; use simpler verification.

## Last Updated

- Issue #13, 2026-03-15
