// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";

import {UniswapV2LiquidityExample} from "../../src/20-uniswap-v2/UniswapV2LiquidityExample.sol";

interface IWETH {
    function deposit() external payable;
}

contract UniswapV2LiquidityExampleTest is Test {
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant DAI_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    uint256 internal constant WETH_AMOUNT = 1 ether;
    uint256 internal constant DAI_AMOUNT = 3_000 ether;

    UniswapV2LiquidityExample internal example;
    IERC20 internal weth;
    IERC20 internal dai;
    address internal liquidityProvider;

    function setUp() public {
        example = new UniswapV2LiquidityExample();
        weth = IERC20(example.WETH());
        dai = IERC20(DAI);
        liquidityProvider = makeAddr("liquidityProvider");

        if (example.ROUTER().code.length == 0 || DAI.code.length == 0) {
            vm.skip(true);
        }

        vm.deal(liquidityProvider, WETH_AMOUNT);
        vm.prank(liquidityProvider);
        IWETH(address(weth)).deposit{value: WETH_AMOUNT}();

        vm.deal(DAI_WHALE, 1 ether);
        vm.prank(DAI_WHALE);
        assertTrue(dai.transfer(liquidityProvider, DAI_AMOUNT));

        vm.startPrank(liquidityProvider);
        weth.approve(address(example), type(uint256).max);
        dai.approve(address(example), type(uint256).max);
        vm.stopPrank();
    }

    function testAddLiquidityStoresLpTokensOnExample() public {
        vm.prank(liquidityProvider);
        (uint256 usedA, uint256 usedB, uint256 liquidity) =
            example.addLiquidity(address(weth), address(dai), WETH_AMOUNT, DAI_AMOUNT);

        address pair = example.pairFor(address(weth), address(dai));

        assertNotEq(pair, address(0));
        assertGt(usedA, 0);
        assertGt(usedB, 0);
        assertGt(liquidity, 0);
        assertLe(usedA, WETH_AMOUNT);
        assertLe(usedB, DAI_AMOUNT);
        assertEq(IERC20(pair).balanceOf(address(example)), liquidity);
    }

    function testRemoveLiquidityRevertsWhenPairDoesNotExist() public {
        vm.expectRevert(UniswapV2LiquidityExample.PairNotFound.selector);
        example.removeLiquidity(makeAddr("tokenA"), makeAddr("tokenB"));
    }

    function testRemoveLiquidityRevertsWhenLpBalanceIsZero() public {
        vm.expectRevert(UniswapV2LiquidityExample.ZeroLiquidity.selector);
        example.removeLiquidity(address(weth), address(dai));
    }

    function testRemoveLiquidityBurnsLpAndReturnsUnderlyingAssets() public {
        vm.prank(liquidityProvider);
        example.addLiquidity(address(weth), address(dai), WETH_AMOUNT, DAI_AMOUNT);

        address pair = example.pairFor(address(weth), address(dai));
        uint256 lpBalanceBefore = IERC20(pair).balanceOf(address(example));
        uint256 wethBalanceBefore = weth.balanceOf(address(example));
        uint256 daiBalanceBefore = dai.balanceOf(address(example));

        vm.prank(liquidityProvider);
        (uint256 amountA, uint256 amountB) = example.removeLiquidity(address(weth), address(dai));

        assertGt(lpBalanceBefore, 0);
        assertGt(amountA, 0);
        assertGt(amountB, 0);
        assertEq(IERC20(pair).balanceOf(address(example)), 0);
        assertEq(weth.balanceOf(address(example)), wethBalanceBefore + amountA);
        assertEq(dai.balanceOf(address(example)), daiBalanceBefore + amountB);
    }
}
