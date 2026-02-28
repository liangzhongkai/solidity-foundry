// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {console} from "forge-std@1.14.0/console.sol";

interface IWETH {
    function balanceOf(address) external view returns (uint256);
    function deposit() external payable;
}

// forge test \
// --fork-url https://eth-mainnet.g.alchemy.com/v2/_KzrTpzEzHqNs4Jn_O5qMzN4AJsQ5OK4 \
// --fork-block-number 21000000   \
// --match-path test/Fork.t.sol -vvv
contract ForkTest is Test {
    IWETH public weth;

    function setUp() public {
        weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        if (address(weth).code.length == 0) vm.skip(true);
    }

    function testDeposit() public {
        // 使用 vm.addr 生成一个主网上几乎不可能有 WETH 的地址，确保余额从 0 开始
        address tester = vm.addr(0x1234567890abcdef);
        vm.deal(tester, 100); // 给该地址 100 wei，刚好够 deposit{value: 100}

        uint256 balBefore = weth.balanceOf(tester);
        console.log("balance before", balBefore);

        vm.prank(tester);
        weth.deposit{value: 100}();

        uint256 balAfter = weth.balanceOf(tester);
        console.log("balance after", balAfter);
    }
}
