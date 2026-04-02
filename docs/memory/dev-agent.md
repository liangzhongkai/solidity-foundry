# DevAgent Memory

Project-centric state for architecture, design, and implementation. Load at start, update at end.

## Current Architecture

- Modules in `src/01-slot-packing/` through `src/22-uniswap-v4/`; each folder is self-contained.
- Reference: `docs/issues/12/architecture.md` for issue-specific diagrams.

## Module Boundaries

- SimpleLottery: standalone; no cross-module calls. Uses OpenZeppelin ReentrancyGuard.
- ERC1155Bingo: standalone; extends OpenZeppelin ERC1155; no cross-module calls.
- OnChainBlackjack: standalone; no cross-module calls; no ETH/token transfers.
- AdvancedERC20: standalone; no cross-module calls. Uses OpenZeppelin Ownable, AccessControl, Pausable, custom ReentrancyGuard.
- Reentrancy (#13): standalone; three demo pairs (classic, read-only, cross-contract); vulnerable + attack + fixed contracts.
- Uniswap V2 example (#14): standalone router/factory/pair integration demo; uses canonical mainnet addresses and fork tests against live protocol state.
- Uniswap V4 example (#16): standalone singleton/periphery demo using minimal local V4 ABIs plus focused wrappers for `StateView`, `PoolManager`, `Universal Router`, and `PositionManager`.

## Design Tradeoffs

- blockhash randomness: simple, no oracle; miner-influenceable. Suitable for low-stakes learning demos.
- participants as address[]: O(n) refund scan; acceptable for demo scale.
- Custom ReentrancyGuard mutex: simpler than OpenZeppelin but functionally equivalent for ERC20 use case.
- Solidity 0.8.20 with built-in overflow/underflow checks
- Optimized domain separator handling
- Uniswap V2 example keeps LP tokens and redeemed assets on the demo contracts to make router effects easy to inspect, at the cost of intentionally custodial behavior.
- The swap example routes directly when one side is `WETH`, otherwise via `tokenIn -> WETH -> tokenOut`, matching the issue comment's expected routing logic.
- Uniswap V4 example keeps the repo on `0.8.20` by defining local minimal V4 interfaces instead of importing the full official V4 repos, trading some upstream helper reuse for toolchain stability.

## Extension Seams

- Lottery params (TICKET_PRICE, PURCHASE_WINDOW) could be made configurable per lottery.
- AdvancedERC20 roles can be extended with additional roles (e.g., BURNER_ROLE separate from MINTER_ROLE).
- Uniswap example could grow a safer wrapper with per-user accounting, recipient selection, or dedicated recovery/withdraw flows if a future issue wants a production-style pattern.
- Uniswap V3 example (#15): prefer explicit tick inputs plus pure/view tick helpers in the demo contract; keep `mint` stack shallow to avoid requiring `via_ir` for the whole repo.
- The zap example can be extended with multi-hop swaps or automatic dust return if a later issue wants a more product-like UX instead of pure protocol demonstration.
- Uniswap V4 example can later add hook-specific demos, Quoter-specific off-chain helpers, or native-ETH settlement once the repo has a stable Cancun-capable fork workflow.

## Test Strategy

- Unit tests with vm.warp, vm.roll for time/block manipulation.
- AdvancedERC20: 57 tests covering ERC20, permit, delegation, access control, pausable, fuzz tests.
- Uniswap V2 example: default suite verifies clean skip behavior without a fork; targeted fork tests validate liquidity add/remove, indirect routed swaps, and optimal-vs-suboptimal zap behavior against live mainnet protocol state.
- Uniswap V3 example: skip in `setUp` when router/factory/NPM bytecode missing; fork tests cover pool lens, `exactInputSingle`, NPM `mint`, fee-tier revert, and tick-spacing misalignment.
- Uniswap V4 example: default mock-backed wrapper tests prove encoding, settlement, Permit2 forwarding, and PositionManager bookkeeping; fork-oriented suites should document when live singleton validation is blocked by transient-storage runtime issues.

## Performance Constraints

- Refund iterates participants; O(n) per participant. Not suitable for large lotteries.
- ERC1155Bingo draw iterates all players; O(players) per draw.
- AdvancedERC20 checkpoint binary search: O(log n) for getPastVotes
- Uniswap example depends on external mainnet RPC latency during fork tests and external router/pair state for executed amounts.
- The optimal-zap comparison should prefer relative assertions such as LP output superiority over brittle dust-balance assumptions, since on live state both strategies may leave near-zero leftovers.
- Uniswap V4 singleton flows depend on transient-storage support inside the local EVM runtime; a fork URL alone is not enough if `PoolManager.unlock()` cannot activate those opcodes.

## Last Updated

- Issue #16, 2026-04-02
