# Issue #15 verification

## Commands run (2026-03-30)

| Command | Result | Blocker |
|--------|--------|--------|
| `forge fmt --check` | Pass | No |
| `forge test --ffi` | Pass: 419 passed, 0 failed, 9 skipped | No |
| `forge test --ffi --match-path test/21-uniswap-v3/**` | Pass: suites skip without fork bytecode (expected) | No |
| `forge test --fork-url <RPC> --match-path test/21-uniswap-v3/**` | Pass when RPC healthy (e.g. `https://eth.llamarpc.com`); `ethereum.publicnode.com` TLS failed in this environment; llama occasionally returned HTTP 502 mid-run | No for logic; use stable `MAINNET_RPC_URL` |
| `slither src/21-uniswap-v3/UniswapV3SwapExample.sol --config-file slither.config.json` | Informational: repo-wide `solc-version` on 0.8.20 | No |
| `slither src/21-uniswap-v3/UniswapV3LiquidityNftExample.sol --config-file slither.config.json` | Informational: `solc-version` only after inline suppressions | No |
| `slither src/21-uniswap-v3/UniswapV3PoolLens.sol --config-file slither.config.json` | Informational: `solc-version` + suppressed `missing-inheritance` false positive | No |

## Scope

- `src/21-uniswap-v3/**/*.sol`
- `test/21-uniswap-v3/**/*.sol`
- `docs/issues/15/*`

## Notes

- Canonical **NonfungiblePositionManager** on Ethereum mainnet: `0xC36442b4a4522E871399CD717aBDD847Ab11FE88`.
- Full suite without `--ffi` still fails on existing FFI tests (`DifferentialTest`, `FFI.t.sol`, `Vyper.t.sol`); CI profile enables FFI — use `forge test --ffi` for parity.
