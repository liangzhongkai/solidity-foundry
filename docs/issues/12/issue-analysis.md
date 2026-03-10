# Issue #12 Analysis: Advanced ERC20 Token

**Issue Title:** task: 新建合约类ERC20 token

**Issue URL:** https://github.com/liangzhongkai/solidity-foundry/issues/12

## Extracted Requirements

Create an advanced ERC20-like token with the following features:

1. **Permit + VoteDelegation** - EIP-2612 (permit) and EIP-5805 (vote delegation) functionality
2. **Ownable / AccessControl** - Role-based access control
3. **Pausable** - Emergency stop mechanism
4. **ReentrancyGuard** - Custom mutex implementation (not importing from OpenZeppelin)

## Conflict Check

### Existing Codebase

- `src/02-erc20/ProductionERC20.sol` - Already implements EIP-2612 permit and EIP-5805 vote delegation
- `src/10-design-patterns/security/SecurityPatterns.sol` - Contains example of custom ReentrancyGuard using mutex pattern
- OpenZeppelin contracts available at `lib/openzeppelin-contracts/` for AccessControl, Ownable, Pausable

### Gap Analysis

The existing `ProductionERC20.sol` is missing:
- AccessControl / Ownable for role-based access
- Pausable functionality
- ReentrancyGuard (issue specifically requires custom implementation)

### Conflicts

No conflicts detected. This is a new standalone module in `src/18-advanced-erc20/`.

## Implementation Plan

### Option A: Extend ProductionERC20
Create a new contract `AdvancedERC20.sol` that:
- Builds upon patterns from `ProductionERC20.sol`
- Integrates Ownable + AccessControl
- Adds Pausable functionality
- Implements custom ReentrancyGuard

### Option B: Create from scratch
Build a new comprehensive ERC20 with all features integrated.

**Decision:** Option A - Extend and enhance existing patterns for consistency with the codebase.

## Design Decisions

1. **Access Control Model:** Use both Ownable and AccessControl
   - Ownable for simple admin functions (pause/unpause)
   - AccessControl for granular role-based permissions (MINTER_ROLE, BURNER_ROLE, PAUSER_ROLE)

2. **ReentrancyGuard Implementation:** Custom mutex pattern following the pattern in SecurityPatterns.sol:
   ```solidity
   uint256 private _entered;
   modifier nonReentrant() {
       if (_entered != 0) revert Reentrancy();
       _entered = 1;
       _;
       _entered = 0;
   }
   ```

3. **Pausable Scope:** Apply `whenNotPaused` to:
   - transfer
   - transferFrom
   - mint
   - burn
   - permit (optional - typically not paused)

4. **File Location:** `src/18-advanced-erc20/AdvancedERC20.sol`

## Acceptance Criteria

- [x] ERC20 base functionality (transfer, approve, transferFrom)
- [x] EIP-2612 Permit functionality
- [x] EIP-5805 Vote delegation with checkpoints
- [x] Ownable for basic ownership
- [x] AccessControl for role-based permissions
- [x] Pausable with pause/unpause functionality
- [x] Custom ReentrancyGuard implementation
- [x] Comprehensive Foundry tests
- [x] NatSpec documentation

## Security Considerations

1. ReentrancyGuard is needed for any external calls (though ERC20 typically doesn't have them)
2. AccessControl roles should follow principle of least privilege
3. Pausable should be callable by PAUSER_ROLE, not just owner
4. Mint/burn should be access-controlled

## Dependencies

- No external dependencies beyond existing OpenZeppelin contracts
- Follows existing project patterns from `ProductionERC20.sol`

## Risk Assessment

- **Low Risk:** Well-established patterns, existing codebase examples
- **Potential Issues:** Combining multiple inheritance chains correctly

## Questions for User

None - requirements are clear.
