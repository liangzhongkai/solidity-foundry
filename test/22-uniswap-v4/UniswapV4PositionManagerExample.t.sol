// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";

import {PoolId, PoolIdLibrary, PoolKey, PositionInfo} from "../../src/22-uniswap-v4/interfaces/IUniswapV4.sol";
import {UniswapV4PositionManagerExample} from "../../src/22-uniswap-v4/UniswapV4PositionManagerExample.sol";
import {UniswapV4Base} from "./UniswapV4Base.t.sol";

contract UniswapV4PositionManagerExampleTest is UniswapV4Base {
    using PoolIdLibrary for PoolKey;

    function testEncodeMintPositionUnlockDataIsNonEmpty() public view {
        PoolKey memory key = _poolKey();
        bytes memory unlockData = positionExample.encodeMintPositionUnlockData(
            key, TICK_LOWER, TICK_UPPER, POSITION_LIQUIDITY, MAX_DAI, MAX_WETH, address(this), bytes("")
        );

        assertGt(unlockData.length, 0);
    }

    function testMintIncreaseCollectAndBurnPosition() public {
        (PoolKey memory key, uint256 tokenId, address funder) = _mintPositionToWrapper();

        (PoolKey memory storedKey, PositionInfo info) = positionExample.getPoolAndPositionInfo(tokenId);
        assertEq(PoolId.unwrap(storedKey.toId()), PoolId.unwrap(key.toId()));
        assertEq(info.tickLower(), TICK_LOWER);
        assertEq(info.tickUpper(), TICK_UPPER);
        assertGt(positionExample.getPositionLiquidity(tokenId), 0);

        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(UniswapV4PositionManagerExample.NotPositionController.selector);
        positionExample.decreaseLiquidity(tokenId, 1, 0, 0, block.timestamp + 1 hours, attacker, bytes(""));

        deal(DAI, funder, 100 ether);
        deal(WETH, funder, 100 ether);
        vm.startPrank(funder);
        IERC20(DAI).approve(address(positionExample), type(uint256).max);
        IERC20(WETH).approve(address(positionExample), type(uint256).max);
        positionExample.increaseLiquidity(tokenId, 1e14, 100 ether, 100 ether, block.timestamp + 1 hours, bytes(""));
        vm.stopPrank();

        uint128 liquidityAfterIncrease = positionExample.getPositionLiquidity(tokenId);
        assertGt(liquidityAfterIncrease, 0);

        address feeRecipient = makeAddr("fee-recipient");
        vm.startPrank(funder);
        positionExample.collectFees(tokenId, block.timestamp + 1 hours, feeRecipient, bytes(""));
        positionExample.decreaseLiquidity(
            tokenId, liquidityAfterIncrease / 2, 0, 0, block.timestamp + 1 hours, feeRecipient, bytes("")
        );
        vm.stopPrank();

        uint128 liquidityAfterDecrease = positionExample.getPositionLiquidity(tokenId);
        assertLt(liquidityAfterDecrease, liquidityAfterIncrease);

        address burnRecipient = makeAddr("burn-recipient");
        vm.prank(funder);
        positionExample.burnPosition(tokenId, 0, 0, block.timestamp + 1 hours, burnRecipient, bytes(""));
        vm.expectRevert();
        positionExample.getPositionLiquidity(tokenId);
    }
}
