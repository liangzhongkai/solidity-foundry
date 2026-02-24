// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "../src/02-erc20/ERC20.sol";

// https://dashboard.alchemy.com/ 获取alchemy的api key, 用于获取sepolia测试网的rpc url: SEPOLIA_RPC_URL, 然后配置到.env文件中
// https://sepoliafaucet.org/ 获取sepolia测试网的钱包地址
// https://sepolia.etherscan.io/ 获取sepolia测试网的区块浏览器
// $ forge script script/Token.s.sol:TokenScript --rpc-url $SEPOLIA_RPC_URL --private-key $DEV_PRIVATE_KEY --broadcast --verify -vvvv
contract MyToken is ERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol, decimals) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}

contract TokenScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEV_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        vm.startBroadcast(deployerPrivateKey);

        MyToken token = new MyToken("MyToken", "MTK", 18);
        console.log("Token deployed:", address(token));

        token.mint(deployer, 300);
        console.log("Token minted:", token.balanceOf(deployer));

        vm.stopBroadcast();
    }
}

// [⠊] Compiling...
// No files changed, compilation skipped
// Traces:
//   [496758] TokenScript::run()
//     ├─ [0] VM::envUint("DEV_PRIVATE_KEY") [staticcall]
//     │   └─ ← [Return] <env var value>
//     ├─ [0] VM::addr(<pk>) [staticcall]
//     │   └─ ← [Return] 0x6caE352882B3B46f3317d686504249a277A3aADc
//     ├─ [0] console::log("Deployer:", 0x6caE352882B3B46f3317d686504249a277A3aADc) [staticcall]
//     │   └─ ← [Stop]
//     ├─ [0] VM::startBroadcast(<pk>)
//     │   └─ ← [Return]
//     ├─ [407019] → new MyToken@0xA0B4c6737C0D4942A353368AD86eBbf24503Fbba
//     │   └─ ← [Return] 1802 bytes of code
//     ├─ [0] console::log("Token deployed:", MyToken: [0xA0B4c6737C0D4942A353368AD86eBbf24503Fbba]) [staticcall]
//     │   └─ ← [Stop]
//     ├─ [46721] MyToken::mint(0x6caE352882B3B46f3317d686504249a277A3aADc, 300)
//     │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: 0x6caE352882B3B46f3317d686504249a277A3aADc, value: 300)
//     │   └─ ← [Stop]
//     ├─ [538] MyToken::balanceOf(0x6caE352882B3B46f3317d686504249a277A3aADc) [staticcall]
//     │   └─ ← [Return] 300
//     ├─ [0] console::log("Token minted:", 300) [staticcall]
//     │   └─ ← [Stop]
//     ├─ [0] VM::stopBroadcast()
//     │   └─ ← [Return]
//     └─ ← [Stop]

// Script ran successfully.

// == Logs ==
//   Deployer: 0x6caE352882B3B46f3317d686504249a277A3aADc
//   Token deployed: 0xA0B4c6737C0D4942A353368AD86eBbf24503Fbba
//   Token minted: 300

// ## Setting up 1 EVM.
// ==========================
// Simulated On-chain Traces:

//   [407019] → new MyToken@0xA0B4c6737C0D4942A353368AD86eBbf24503Fbba
//     └─ ← [Return] 1802 bytes of code

//   [46721] MyToken::mint(0x6caE352882B3B46f3317d686504249a277A3aADc, 300)
//     ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: 0x6caE352882B3B46f3317d686504249a277A3aADc, value: 300)
//     └─ ← [Stop]

// ==========================

// Chain 11155111

// Estimated gas price: 0.00100225 gwei

// Estimated total gas used for script: 751464

// Estimated amount required: 0.000000753154794 ETH

// ==========================

// ##### sepolia
// ✅  [Success] Hash: 0xe05bc9cf38d111c08273af68273f1aacc454a70e0aa892214bf7291cc7040511
// Contract Address: 0xA0B4c6737C0D4942A353368AD86eBbf24503Fbba
// Block: 10324903
// Paid: 0.000000502327197645 ETH (501207 gas * 0.001002235 gwei)

// ##### sepolia
// ✅  [Success] Hash: 0xf820888e9175ef21bfdf7db54079a6731f22f379144765f1881ce3169ac73c68
// Block: 10324903
// Paid: 0.000000068457661675 ETH (68305 gas * 0.001002235 gwei)

// ✅ Sequence #1 on sepolia | Total Paid: 0.00000057078485932 ETH (569512 gas * avg 0.001002235 gwei)

// ==========================

// ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
// ##
// Start verification for (1) contracts
// Start verifying contract `0xA0B4c6737C0D4942A353368AD86eBbf24503Fbba` deployed on sepolia
// EVM version: shanghai
// Compiler version: 0.8.20
// Optimizations:    200
// Constructor args: 000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000074d79546f6b656e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000034d544b0000000000000000000000000000000000000000000000000000000000
// Attempting to verify on Sourcify. Pass the --etherscan-api-key <API_KEY> to verify on Etherscan, or use the --verifier flag to verify on another provider.

// Submitting verification for [MyToken] "0xA0B4c6737C0D4942A353368AD86eBbf24503Fbba".
// Submitted contract for verification:
//         Verification Job ID: `3fb5d105-548f-4063-90b9-c358dc0f9418`
//         URL: https://sourcify.dev/server/v2/verify/3fb5d105-548f-4063-90b9-c358dc0f9418
// Warning: Verification is still pending...; waiting 15 seconds before trying again (7 tries remaining)
// Contract successfully verified:
// Status: `exact_match`
// All (1) contracts were verified!

// Transactions saved to: /home/kleung/chain/eth/solidity-foundry/broadcast/Token.s.sol/11155111/run-latest.json

// Sensitive values saved to: /home/kleung/chain/eth/solidity-foundry/cache/Token.s.sol/11155111/run-latest.json
