// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";

import {UniswapV2SwapExample} from "../../src/20-uniswap-v2/UniswapV2SwapExample.sol";

interface IWETH {
    function deposit() external payable;
}

contract UniswapV2SwapExampleTest is Test {
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant WBTC_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    uint256 internal constant AMOUNT_IN = 100_000_000;

    UniswapV2SwapExample internal example;
    IERC20 internal tokenIn;
    IERC20 internal tokenOut;
    address internal recipient;

    function setUp() public {
        example = new UniswapV2SwapExample();
        tokenIn = IERC20(WBTC);
        tokenOut = IERC20(DAI);
        recipient = makeAddr("recipient");

        if (example.ROUTER().code.length == 0 || WBTC.code.length == 0 || DAI.code.length == 0) {
            vm.skip(true);
        }

        vm.deal(WBTC_WHALE, 1 ether);
        vm.prank(WBTC_WHALE);
        tokenIn.approve(address(example), AMOUNT_IN);
    }

    function testGetAmountOutMinQuotesThreeHopSwap() public view {
        uint256 quotedOut = example.getAmountOutMin(WBTC, DAI, AMOUNT_IN);

        assertGt(quotedOut, 0);
    }

    function testSwapTransfersQuotedOutputToRecipient() public {
        uint256 quotedOut = example.getAmountOutMin(WBTC, DAI, AMOUNT_IN);
        uint256 recipientBefore = tokenOut.balanceOf(recipient);

        vm.prank(WBTC_WHALE);
        uint256 amountOut = example.swap(WBTC, DAI, AMOUNT_IN, 1, recipient);

        uint256 recipientAfter = tokenOut.balanceOf(recipient);

        assertEq(amountOut, quotedOut);
        assertEq(recipientAfter - recipientBefore, amountOut);
        assertGt(amountOut, 0);
    }

    function testSwapSupportsDirectWethPath() public {
        address wethTrader = makeAddr("wethTrader");
        IERC20 weth = IERC20(example.WETH());

        vm.deal(wethTrader, 1 ether);
        vm.prank(wethTrader);
        IWETH(address(weth)).deposit{value: 1 ether}();

        vm.prank(wethTrader);
        weth.approve(address(example), 1 ether);

        uint256 quotedOut = example.getAmountOutMin(address(weth), DAI, 1 ether);
        uint256 recipientBefore = tokenOut.balanceOf(recipient);

        vm.prank(wethTrader);
        uint256 amountOut = example.swap(address(weth), DAI, 1 ether, 1, recipient);

        uint256 recipientAfter = tokenOut.balanceOf(recipient);

        assertEq(amountOut, quotedOut);
        assertEq(recipientAfter - recipientBefore, amountOut);
        assertGt(amountOut, 0);
    }

    function testSwapRevertsForZeroRecipient() public {
        vm.expectRevert(UniswapV2SwapExample.ZeroAddress.selector);
        example.swap(WBTC, DAI, AMOUNT_IN, 1, address(0));
    }
}
