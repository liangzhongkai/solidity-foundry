# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build, Test, and Lint Commands

```bash
forge build                          # Compile contracts
forge test                           # Run all tests
forge test --match-path test/Counter.t.sol -vvvvv  # Run specific test file with verbose output
forge test --match-test test_Increment  # Run tests matching a pattern
forge fmt                            # Format Solidity files
forge fmt --check                    # Check formatting (CI uses this)
forge snapshot                       # Generate gas snapshots
```

### Special Test Modes

```bash
# Fork tests (require RPC URL)
forge test --fork-url $MAINNET_FORK_URL --fork-block-number 21000000 --match-path test/Fork.t.sol

# FFI tests (differential testing with Python)
forge test --match-path test/DifferentialTest.t.sol --ffi

# Fuzz tests with more runs
FOUNDRY_FUZZ_RUNS=1000 forge test --match-path test/Fuzz.t.sol
```

### Deploy Commands

```bash
# Simulate deployment
forge script script/Counter.s.sol:CounterScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Deploy to network
forge script script/Counter.s.sol:CounterScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# Deploy and verify on Etherscan
forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/Storage.sol:Storage --broadcast --verify
```

### Pre-commit

```bash
pre-commit install   # Install git hooks (runs fmt check, build, test, slither, echidna, manticore)
```

## Project Structure

- `src/` - Solidity contracts organized by topic:
  - `01-slot-packing/` - Storage slot optimization examples
  - `02-erc20/` - ERC20 implementations including permit and gasless transfers
  - `03-mapping-slot/` - Mapping storage slot calculations
  - `04-proxy/` - Proxy contract patterns
  - `05-receive-fallback/` - receive() and fallback() function examples
  - `06-trade-tokens/` - Token exchange contracts (RareCoin, SkillsCoin)
  - `07-foundry-nft/` - NFT implementation
  - `08-vesting/` - Time-locked ERC20 vesting (1/n tokens over n days)
  - `echidna/` - Contracts for Echidna fuzzing
  - `manticore/` - Contracts for Manticore symbolic execution
- `test/` - Foundry test files (`.t.sol` suffix)
- `script/` - Deployment scripts (`.s.sol` suffix)
- `lib/` - Dependencies (forge-std, solmate, openzeppelin-contracts)

## Testing Patterns

This project demonstrates several Foundry testing patterns:

1. **Unit tests** - Standard tests with `setUp()` and `test_*` functions
2. **Fuzz tests** - Parameterized tests using `testFuzz_*` or parameters with `vm.assume()` and `bound()`
3. **Invariant tests** - Functions named `invariant_*` that run after random sequences of calls
4. **Fork tests** - Tests that fork mainnet state using `--fork-url`
5. **Differential tests** - Compare Solidity vs Python via `vm.ffi()`

## Dependencies

Import paths use versioned remappings:
- `forge-std@1.14.0/Test.sol` - Foundry test utilities
- `openzeppelin-contracts@5.4.0/` - OpenZeppelin contracts
- `solmate@6.8.0/` - Solmate contracts

## Configuration

- Solidity version: `0.8.20` (set in `foundry.toml`)
- Optimizer: enabled with 200 runs
- Fuzz runs: 256 (default)
- CI profile enables FFI for differential tests

## Security Tools

The CI pipeline and pre-commit hooks run:
- **Slither** - Static analysis (`slither . --config-file slither.config.json --fail-high`)
- **Echidna** - Fuzzing (`echidna-test . --contract CounterEchidna --config echidna.yaml`)
- **Manticore** - Symbolic execution (`manticore-verifier src/manticore/CounterManticore.sol`)
