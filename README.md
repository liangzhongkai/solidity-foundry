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
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>  // 模拟部署

$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast // 真实部署到rpc url

$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast --verify // 真实部署到rpc url, 并进行验证

// 建议在 forge create 中使用 --verify 标志，以便部署后在 explorer 上自动验证合约。 请注意，对于 Etherscan，必须设置 ETHERSCAN_API_KEY。
$ forge create --rpc-url <your_rpc_url> --private-key <your_private_key> src/Storage.sol:Storage --broadcast --verify -vvvv 
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
