# ReviewAgent Memory

Project-centric state for quality bar and review consistency. Load at start, update at end.

## Quality Bar Expectations

- NatSpec on public/external; custom errors; forge fmt.
- Tests cover happy path and key revert cases.

## Prior Review Findings

- (none recorded)

## Testing Blind Spots

- blockhash availability: tests must vm.roll(drawBlock+1) not vm.roll(drawBlock).
- Refund with multiple participants: verify swap-with-last in _removeParticipant.

## Last Updated

- Issue #9, 2026-03-08
