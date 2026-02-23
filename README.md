## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
$ forge test --match-path test/Counter.t.sol --gas-report -vvvvv
```

FFI tests (e.g. `DifferentialTest.t.sol`) require Python and `eth-abi`:

```shell
pip install -r requirements.txt
forge test --ffi
```

### Format

```shell
$ forge fmt
```

### Pre-commit

Runs the same checks as CI before each commit (npm ci, forge fmt --check, build, test):

```shell
pip install pre-commit   # or: brew install pre-commit
pre-commit install
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
