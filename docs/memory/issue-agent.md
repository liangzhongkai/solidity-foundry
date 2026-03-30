# IssueAgent Memory

Project-centric state for requirement analysis and conflict resolution. Load at start, update at end.

## Product Direction

- Solidity learning / pattern demos; each module (01-slot-packing through 18-advanced-erc20) is self-contained.

## Accepted Directions

- Simple lottery (#9): blockhash for randomness (RareSkills pattern); 24h purchase + 1h delay; 256-block claim window; refund if no claim.
- ERC1155 Bingo (#10): ERC1155 tokens 1-25, 5x5 grid per player, draw every n blocks, first 5-in-row wins.
- On-chain Blackjack (#11): Open hands, blockhash RNG (2-9: 1/13, 10: 4/13, Ace: 1/13), dealer hits until 17, 10-block move timeout.
- Advanced ERC20 (#12): EIP-2612 permit + EIP-5805 vote delegation, Ownable + AccessControl, Pausable, custom ReentrancyGuard mutex.
- Reentrancy demos (#13): 经典重入、read-only 重入、跨合约重入 三组教学示例。
- Uniswap V2 example (#14): standalone Foundry teaching module using canonical mainnet Uniswap V2 `Factory` / `Router` / `Pair` addresses plus fork-based coverage for liquidity, swap, and one-sided zap examples.
- Uniswap V3 example (#15): standalone `src/21-uniswap-v3/` module using canonical mainnet `Factory`, `SwapRouter`, and `NonfungiblePositionManager` (`0xC36442b4a4522E871399CD717aBDD847Ab11FE88`) with fork-skipping tests and tick-spacing teaching notes.

## Rejected Directions

- (none recorded)

## Cross-Issue Requirement History

- Issue #9: standalone SimpleLottery; no dependencies on other modules.
- Issue #10: standalone ERC1155Bingo; blockhash for randomness.
- Issue #11: standalone OnChainBlackjack; dealer threshold 17 (standard); issue text said "at least 21" but 17 used for playability.
- Issue #12: standalone AdvancedERC20; builds on ProductionERC20 patterns but adds access control, pausable, and custom reentrancy guard.
- Issue #13: standalone reentrancy demos; 19-reentrancy module.
- Issue #14: standalone Uniswap V2 interface demo; issue comments expanded scope from liquidity add/remove to also include routed swaps and optimal-vs-suboptimal zap examples. Use real mainnet fork interactions for verification, but keep the default non-fork suite green by skipping when forked contracts are unavailable.
- Issue #15: standalone Uniswap V3 interface demo; verify NPM address against official deployment docs (avoid checksum typos). Fork RPC reliability varies — record multiple RPC options in verification.

## Prior Conflict Resolutions

- (none recorded)

## Last Updated

- Issue #15, 2026-03-30
