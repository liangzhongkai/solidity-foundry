// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

import {IUniswapV2Factory, IUniswapV2Router} from "./interfaces/IUniswapV2.sol";

/// @title UniswapV2LiquidityExample
/// @notice Demonstrates adding and removing liquidity through the Uniswap V2 router on a fork.
/// @dev This is a teaching example. LP tokens and redeemed assets remain on this contract for inspection.
contract UniswapV2LiquidityExample {
    using SafeERC20 for IERC20;

    address public constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    event Log(string message, uint256 value);

    error PairNotFound();
    error ZeroLiquidity();

    /// @notice Returns the Uniswap V2 pair for a token pair.
    function pairFor(address tokenA, address tokenB) public view returns (address pair) {
        return IUniswapV2Factory(FACTORY).getPair(tokenA, tokenB);
    }

    /// @notice Returns the example contract's LP token balance for a token pair.
    function lpBalance(address tokenA, address tokenB) external view returns (uint256 liquidity) {
        address pair = pairFor(tokenA, tokenB);
        if (pair == address(0)) return 0;
        return IERC20(pair).balanceOf(address(this));
    }

    /// @notice Pulls tokens from the caller and adds liquidity through the Uniswap V2 router.
    /// @param tokenA First token in the pair.
    /// @param tokenB Second token in the pair.
    /// @param amountA Amount of tokenA to supply.
    /// @param amountB Amount of tokenB to supply.
    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        external
        returns (uint256 usedA, uint256 usedB, uint256 liquidity)
    {
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        IERC20(tokenA).forceApprove(ROUTER, amountA);
        IERC20(tokenB).forceApprove(ROUTER, amountB);

        // slither-disable-next-line reentrancy-events -- only emits router return data after the external call
        (usedA, usedB, liquidity) = IUniswapV2Router(ROUTER)
            .addLiquidity(tokenA, tokenB, amountA, amountB, 1, 1, address(this), block.timestamp);

        emit Log("amountA", usedA);
        emit Log("amountB", usedB);
        emit Log("liquidity", liquidity);
    }

    /// @notice Removes this contract's entire LP position for a token pair.
    /// @param tokenA First token in the pair.
    /// @param tokenB Second token in the pair.
    function removeLiquidity(address tokenA, address tokenB) external returns (uint256 amountA, uint256 amountB) {
        address pair = pairFor(tokenA, tokenB);
        if (pair == address(0)) revert PairNotFound();

        uint256 liquidity = IERC20(pair).balanceOf(address(this));
        // slither-disable-next-line incorrect-equality -- explicit LP presence guard for this demo contract
        if (liquidity == 0) revert ZeroLiquidity();

        IERC20(pair).forceApprove(ROUTER, liquidity);

        // slither-disable-next-line reentrancy-events -- only emits router return data after the external call
        (amountA, amountB) =
            IUniswapV2Router(ROUTER).removeLiquidity(tokenA, tokenB, liquidity, 1, 1, address(this), block.timestamp);

        emit Log("amountA", amountA);
        emit Log("amountB", amountB);
    }
}
