// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";

import {BalanceDelta, ModifyLiquidityParams, PoolKey} from "../../src/22-uniswap-v4/interfaces/IUniswapV4.sol";
import {UniswapV4PoolManagerExample} from "../../src/22-uniswap-v4/UniswapV4PoolManagerExample.sol";
import {UniswapV4Base} from "./UniswapV4Base.t.sol";

contract UniswapV4PoolManagerExampleTest is UniswapV4Base {
    function testModifyLiquidityAddsLiquidityAndSwapExactInputTransfersOutput() public {
        (PoolKey memory key,) = _seedCorePool();

        address addMoreLp = makeAddr("add-more-lp");
        deal(DAI, addMoreLp, 100 ether);
        deal(WETH, addMoreLp, 100 ether);

        vm.startPrank(addMoreLp);
        IERC20(DAI).approve(address(poolManagerExample), type(uint256).max);
        IERC20(WETH).approve(address(poolManagerExample), type(uint256).max);

        (BalanceDelta callerDelta,) = poolManagerExample.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: int256(5e13), salt: bytes32(uint256(1))
            }),
            bytes(""),
            addMoreLp
        );
        vm.stopPrank();

        assertLt(callerDelta.amount0(), 0);
        assertLt(callerDelta.amount1(), 0);

        address trader = makeAddr("direct-swap-trader");
        address recipient = makeAddr("direct-swap-recipient");
        deal(WETH, trader, 1 ether);

        vm.startPrank(trader);
        IERC20(WETH).approve(address(poolManagerExample), type(uint256).max);
        uint256 amountOut = poolManagerExample.swapExactInput(key, false, 0.1 ether, 0, 0, bytes(""), recipient);
        vm.stopPrank();

        assertGt(amountOut, 0);
        assertEq(IERC20(DAI).balanceOf(recipient), amountOut);
    }

    function testDonateConsumesCallerFunds() public {
        (PoolKey memory key,) = _seedCorePool();

        address donor = makeAddr("donor");
        deal(DAI, donor, 10 ether);
        deal(WETH, donor, 10 ether);

        vm.startPrank(donor);
        IERC20(DAI).approve(address(poolManagerExample), type(uint256).max);
        IERC20(WETH).approve(address(poolManagerExample), type(uint256).max);
        uint256 daiBefore = IERC20(DAI).balanceOf(donor);
        uint256 wethBefore = IERC20(WETH).balanceOf(donor);
        poolManagerExample.donate(key, 1 ether, 1 ether, bytes(""));
        vm.stopPrank();

        assertLt(IERC20(DAI).balanceOf(donor), daiBefore);
        assertLt(IERC20(WETH).balanceOf(donor), wethBefore);
    }

    function testSwapRevertsForZeroRecipient() public {
        PoolKey memory key = _poolKey();
        vm.expectRevert(UniswapV4PoolManagerExample.InvalidRecipient.selector);
        poolManagerExample.swapExactInput(key, false, 1, 0, 0, bytes(""), address(0));
    }
}
