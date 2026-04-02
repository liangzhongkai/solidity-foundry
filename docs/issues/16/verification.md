# Issue #16 verification

## Commands run (2026-04-02)

| Command | Result | Blocker |
|--------|--------|--------|
| `forge fmt --check` | Pass | No |
| `forge test --match-path "test/22-uniswap-v4/*.t.sol" -vv` | Pass: 9 passed, 0 failed, 6 skipped | No |
| `forge test --match-path "test/22-uniswap-v4/UniswapV4WrapperUnit.t.sol" -vv` | Pass: 5 passed, 0 failed, 0 skipped | No |
| `forge test --ffi` | Pass repo-wide in this environment | No |
| `forge test --fork-url https://ethereum.publicnode.com --match-path "test/22-uniswap-v4/UniswapV4StateViewExample.t.sol" -vv` | Fail: `PoolManager.unlock()` reverted with `NotActivated` during live V4 singleton execution | Yes for live integration proof |
| `forge test --fork-url http://127.0.0.1:8547 --evm-version cancun --match-test testReadPoolStateAfterCoreLiquiditySeed -vvvvv` | Fail: same `NotActivated` behavior on a local Anvil mainnet fork | Yes for live integration proof |

## Scope

- `src/22-uniswap-v4/**/*.sol`
- `test/22-uniswap-v4/**/*.sol`
- `docs/issues/16/*`
- `docs/memory/*.md`

## Notes

- Canonical Ethereum mainnet addresses used by the new module:
  `PoolManager`, `PositionManager`, `Universal Router`, `StateView`, and `Permit2`.
- The new wrapper unit tests provide deterministic proof of:
  direct singleton settlement handling, router command encoding, Permit2 forwarding, PositionManager batch encoding, and NFT position bookkeeping.
- Live V4 fork execution remains environment-limited here because the runtime reports transient-storage activation failures when `PoolManager.unlock()` is exercised.
