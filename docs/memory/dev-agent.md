# DevAgent Memory

Project-centric state for architecture, design, and implementation. Load at start, update at end.

## Current Architecture

- Modules in `src/01-slot-packing/` through `src/19-reentrancy/`; each folder is self-contained.
- Reference: `docs/issues/12/architecture.md` for issue-specific diagrams.

## Module Boundaries

- SimpleLottery: standalone; no cross-module calls. Uses OpenZeppelin ReentrancyGuard.
- ERC1155Bingo: standalone; extends OpenZeppelin ERC1155; no cross-module calls.
- OnChainBlackjack: standalone; no cross-module calls; no ETH/token transfers.
- AdvancedERC20: standalone; no cross-module calls. Uses OpenZeppelin Ownable, AccessControl, Pausable, custom ReentrancyGuard.
- Reentrancy (#13): standalone; three demo pairs (classic, read-only, cross-contract); vulnerable + attack + fixed contracts.
    - Custom ReentrancyGuard mutex pattern
    - Ownable for simple admin functions
    - AccessControl for granular role-based permissions (MINTER_ROLE, PAUSER_ROLE)
    - DEFAULT_ADMIN_ROLE for managing roles

## Design Tradeoffs

- blockhash randomness: simple, no oracle; miner-influenceable. Suitable for low-stakes learning demos.
- participants as address[]: O(n) refund scan; acceptable for demo scale.
- Custom ReentrancyGuard mutex: simpler than OpenZeppelin but functionally equivalent for ERC20 use case.
- Solidity 0.8.20 with built-in overflow/underflow checks
- Optimized domain separator handling
    - unchecked blocks for non-overflowing arithmetic
    - Immutables for constructor-set values
    - Comprehensive Foundry tests
    - NatSpec documentation

## Extension Seams

- Lottery params (TICKET_PRICE, PURCHASE_WINDOW) could be made configurable per lottery.
- AdvancedERC20 roles can be extended with additional roles (e.g., BURNER_ROLE separate from MINTER_ROLE).
- Pausable scope: transfer/mint/burn
    - mint() - MINTER_ROLE only
    - burn() - Any holder
    - burnFrom() - with allowance
    - permit() - Not paused (gas-efficient approvals)
    - delegate() / delegateBySig() - Not paused (voting continues during pause)

## Test Strategy

- Unit tests with vm.warp, vm.roll for time/block manipulation.
- AdvancedERC20: 57 tests covering ERC20, permit, delegation, access control, pausable, fuzz tests.

## Performance Constraints

- Refund iterates participants; O(n) per participant. Not suitable for large lotteries.
- ERC1155Bingo draw iterates all players; O(players) per draw.
- AdvancedERC20 checkpoint binary search: O(log n) for getPastVotes
    - Same-block checkpoint update (in-place modification)

## Last Updated

- Issue #13, 2026-03-15
