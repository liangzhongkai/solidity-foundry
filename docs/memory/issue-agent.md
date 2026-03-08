# IssueAgent Memory

Project-centric state for requirement analysis and conflict resolution. Load at start, update at end.

## Product Direction

- Solidity learning / pattern demos; each module (01-slot-packing through 16-erc1155-bingo) is self-contained.

## Accepted Directions

- Simple lottery (#9): blockhash for randomness (RareSkills pattern); 24h purchase + 1h delay; 256-block claim window; refund if no claim.
- ERC1155 Bingo (#10): ERC1155 tokens 1-25, 5x5 grid per player, draw every n blocks, first 5-in-row wins.

## Rejected Directions

- (none recorded)

## Cross-Issue Requirement History

- Issue #9: standalone SimpleLottery; no dependencies on other modules.
- Issue #10: standalone ERC1155Bingo; blockhash for randomness.

## Prior Conflict Resolutions

- (none recorded)

## Last Updated

- Issue #10, 2026-03-08
