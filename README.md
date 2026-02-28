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

Runs the same checks as CI before each commit (forge fmt --check, build, test):

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

// 单纯验证合约：
$ forge verify-contract \
     --chain-id 11155111 \
     --num-of-optimizations 200     \
     --watch     \
     --etherscan-api-key $ETHERSCAN_API_KEY     \
     --compiler-version v0.8.20+commit.a1b79de6     \
     <合约地址: 0x8ACB23e393BB7ceB58d3dc8E27c51fb4e4F870Be>     \
     src/Storage.sol:Storage
Start verifying contract `0x8ACB23e393BB7ceB58d3dc8E27c51fb4e4F870Be` deployed on sepolia
Compiler version: v0.8.20+commit.a1b79de6
Optimizations:    200

Submitting verification for [src/Storage.sol:Storage] 0x8ACB23e393BB7ceB58d3dc8E27c51fb4e4F870Be.
Submitted contract for verification:
        Response: `OK`
        GUID: `k1agjm3resmstbac1c8th97rbeznj9htelfu4hvijcdzfugu53`
        URL: https://sepolia.etherscan.io/address/0x8acb23e393bb7ceb58d3dc8e27c51fb4e4f870be
Contract verification status:
Response: `NOTOK`
Details: `Pending in queue`
Warning: Verification is still pending...; waiting 15 seconds before trying again (7 tries remaining)
Contract verification status:
Response: `OK`
Details: `Pass - Verified`
Contract successfully verified

// 验证合约功能
$ export STORAGE_ADDR=0x8ACB23e393BB7ceB58d3dc8E27c51fb4e4F870Be

$ cast call $STORAGE_ADDR "retrieve()(uint256)" --rpc-url $SEPOLIA_RPC_URL
0

$ cast send $STORAGE_ADDR "store(uint256)" 100 --rpc-url $SEPOLIA_RPC_URL --private-key $DEV_PRIVATE_KEY
blockHash            0xf9b500a4ebf8fd8c6c3f30d930cd34592940f5e11aabe90dc9c5aa277ff3e89a
blockNumber          10331292
contractAddress      
cumulativeGasUsed    40550480
effectiveGasPrice    1200013
from                 0x6caE352882B3B46f3317d686504249a277A3aADc
gasUsed              43513
logs                 []
logsBloom            0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
root                 
status               1 (success)
transactionHash      0x36781e24ad23966307385b13e9cfbd7ee7dbd1f5b86cd9bc371f78c8141e3a8e
transactionIndex     197
type                 2
blobGasPrice         
blobGasUsed          
to                   0x8ACB23e393BB7ceB58d3dc8E27c51fb4e4F870Be

$ cast call $STORAGE_ADDR "retrieve()(uint256)" --rpc-url $SEPOLIA_RPC_URL
100
```

### Mockcall

```shell
forge test --fork-url $MAINNET_FORK_URL --match-path test/MockCall.sol -vvv
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
