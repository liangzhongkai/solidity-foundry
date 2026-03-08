# Verification

## Commands

| Command | Scope | Status |
|---------|-------|--------|
| `forge fmt --check` | Formatting | pass |
| `forge build` | Compilation | pass |
| `forge test --match-path test/14-stake-together/StakeTogether.t.sol` | StakeTogether tests | 17 passed |
| `forge test` | Full suite | 313 passed, 3 FFI tests need `--ffi` (pre-existing) |

## Blocker Status

- No blockers for merge.
