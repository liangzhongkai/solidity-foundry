// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ProductionERC20} from "../src/02-erc20/ProductionERC20.sol";

contract DeployERC20Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("========== Production ERC20 Token Deployment ==========\n");

        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with account:", deployer);

        // Token configuration
        string memory tokenName = "My Production Token";
        string memory tokenSymbol = "MPT";
        uint8 tokenDecimals = 18;
        uint256 initialSupply = 1_000_000 * 1e18;

        console.log("\nToken Configuration:");
        console.log("  Name:", tokenName);
        console.log("  Symbol:", tokenSymbol);
        console.log("  Decimals:");
        console.logUint(tokenDecimals);
        console.log("  Initial Supply:");
        console.logUint(initialSupply / 1e18);

        // Deploy contract
        console.log("\nDeploying ProductionERC20 contract...");
        ProductionERC20 token = new ProductionERC20(tokenName, tokenSymbol, tokenDecimals, initialSupply, deployer);

        address tokenAddress = address(token);
        console.log("Contract deployed successfully!");
        console.log("Token Address:", tokenAddress);

        vm.stopBroadcast();

        // Verify deployment
        console.log("\nVerifying deployment...");
        string memory name = token.name();
        string memory symbol = token.symbol();
        uint256 totalSupply = token.totalSupply();
        uint256 deployerBalance = token.balanceOf(deployer);

        console.log("Deployment verified:");
        console.log("  Name:", name);
        console.log("  Symbol:", symbol);
        console.log("  Total Supply:");
        console.logUint(totalSupply / 1e18);
        console.log("  Deployer Balance:");
        console.logUint(deployerBalance / 1e18);

        console.log("\nDeployment completed successfully!");
        console.log("Contract Summary:");
        console.log("  Address:", tokenAddress);
    }
}
