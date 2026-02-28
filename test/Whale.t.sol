// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {console} from "forge-std@1.14.0/console.sol";
import {IERC20} from "../src/02-erc20/IERC20.sol";

// forge test \
// --fork-url https://ethereum.publicnode.com   \
// --match-path test/Whale.t.sol -vvv
contract WhaleTest is Test {
    IERC20 public dai;

    function setUp() public {
        dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        if (address(dai).code.length == 0) vm.skip(true);
    }

    function testDeposit() public {
        address kevin = address(123);

        uint256 balBefore = dai.balanceOf(kevin);
        console.log("balance before", balBefore);

        uint256 totalBefore = dai.totalSupply();
        console.log("total supply before", totalBefore / 1e18);

        // token, account, amount, adjust total supply
        deal(address(dai), kevin, 1e6 * 1e18, true);

        uint256 balAfter = dai.balanceOf(kevin);
        console.log("balance after", balAfter / 1e18);

        uint256 totalAfter = dai.totalSupply();
        console.log("total supply after", totalAfter / 1e18);
    }
}
