# IssueAgent Memory

Project-centric state for requirement analysis and conflict resolution. Load at start, update at end.

## Product Direction

- Solidity learning / pattern demos; each module (01-slot-packing through 18-advanced-erc20) is self-contained.

## Accepted Directions

- Simple lottery (#9): blockhash for randomness (RareSkills pattern); 24h purchase + 1h delay; 256-block claim window; refund if no claim.
- ERC1155 Bingo (#10): ERC1155 tokens 1-25, 5x5 grid per player, draw every n blocks, first 5-in-row wins.
- On-chain Blackjack (#11): Open hands, blockhash RNG (2-9: 1/13, 10: 4/13, Ace: 1/13), dealer hits until 17, 10-block move timeout.
- Advanced ERC20 (#12): EIP-2612 permit + EIP-5805 vote delegation, Ownable + AccessControl, Pausable, custom ReentrancyGuard mutex.

## Rejected Directions

- (none recorded)

## Cross-Issue Requirement History

- Issue #9: standalone SimpleLottery; no dependencies on other modules.
- Issue #10: standalone ERC1155Bingo; blockhash for randomness.
- Issue #11: standalone OnChainBlackjack; dealer threshold 17 (standard); issue text said "at least 21" but 17 used for playability.
- Issue #12: standalone AdvancedERC20; builds on ProductionERC20 patterns but adds access control, pausable, and custom reentrancy guard.

## Prior Conflict Resolutions

- (none recorded)

## Last Updated

- Issue #12, 2026-03-10
