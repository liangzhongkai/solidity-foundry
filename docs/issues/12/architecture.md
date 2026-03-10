# Architecture: AdvancedERC20 (Issue #12)

## Why This Diagram Exists
This document explains the system architecture and design decisions.

It serves as a learning reference for similar future implementations.

## System View

```
┌──────────────────────────────────────────────────────────────────┐─────────────────────────────────┐────────────┐
│ Contract: AdvancedERC20 │
│ Inheritance: Ownable, AccessControl, Pausable │
│ Location: src/18-advanced-erc20/AdvancedERC20.sol │
└──────────────────────────────────────────────────────────────────┘─────────────────────────────────┘────────────┘
│ Core: ERC20 │
│  - transfer() / transferFrom() / approve() │
│  - balanceOf() / allowance() │
│  - totalSupply / _balances / _allowances │
├──────────────────────────────────────────────────────────────────┼─────────────────────────────────┼────────────┐
│ EIP-2612: Permit │
│  - permit() / DOMAIN_SEPARATOR() │
│  - nonces (replay protection) │
└──────────────────────────────────────────────────────────────────┼─────────────────────────────────┼────────────┐
│ EIP-5805: Voting │
│  - delegate() / delegateBySig() │
│  - delegates() / getVotes() / getPastVotes() │
│  - Checkpoints for historical queries │
└──────────────────────────────────────────────────────────────────┼─────────────────────────────────┼────────────┐
│ Access Control │
│  - MINTER_ROLE: Can mint tokens │
│  - PAUSER_ROLE: Can pause/unpause │
│  - DEFAULT_ADMIN_ROLE: Can manage roles │
└──────────────────────────────────────────────────────────────────┼─────────────────────────────────┼────────────┐
│ Security │
│  - ReentrancyGuard (custom mutex) │
│  - Pausable (emergency stop) │
│  - Custom errors for gas efficiency │
└──────────────────────────────────────────────────────────────────┘─────────────────────────────────┘────────────┘
```

## Review Hotspots
1. **Role inheritance complexity**: Multiple contracts (Ownable, AccessControl, Pausable) - ensure proper initialization order
2. **Nonce management**: Nonces shared between permit and delegateBySig - verify correct nonce increment
3. **Vote checkpoint consistency**: Ensure checkpoints are pushed correctly in transfers/delegations
4. **Unchecked arithmetic**: Verify unchecked blocks don't overflow
5. **Assembly usage**: Ensure assembly is safe and doesn't introduce memory issues
6. **Domain separator caching**: Verify chain ID change handling
7. **Role-based permissions**: Ensure role grants follow least privilege
