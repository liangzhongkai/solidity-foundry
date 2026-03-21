// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

import {IUniswapV2Factory, IUniswapV2Pair, IUniswapV2Router} from "./interfaces/IUniswapV2.sol";

/// @title UniswapV2OptimalZap
/// @notice Demonstrates one-sided Uniswap V2 liquidity provision with either an optimal or naive split.
contract UniswapV2OptimalZap {
    using SafeERC20 for IERC20;

    address public constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    event ZapExecuted(
        address indexed tokenA, address indexed tokenB, uint256 amountIn, uint256 swapOut, uint256 liquidity
    );

    error PairNotFound();
    error WethPairRequired();

    /// @notice Babylonian square root implementation used by the optimal-swap formula.
    function sqrt(uint256 y) public pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /// @notice Calculates the optimal amount to swap before adding one-sided liquidity.
    /// @dev Formula adapted from the issue comment's sample code, using Solidity 0.8 checked arithmetic.
    function getSwapAmount(uint256 reserveIn, uint256 amountIn) public pure returns (uint256) {
        return (sqrt(reserveIn * (reserveIn * 3_988_009 + amountIn * 3_988_000)) - reserveIn * 1_997) / 1_994;
    }

    /// @notice Returns the pair address for two tokens.
    function getPair(address tokenA, address tokenB) external view returns (address) {
        return IUniswapV2Factory(FACTORY).getPair(tokenA, tokenB);
    }

    /// @notice Optimal one-sided supply for a WETH pair.
    function zap(address tokenA, address tokenB, uint256 amountA) external returns (uint256 liquidity) {
        if (tokenA != WETH && tokenB != WETH) revert WethPairRequired();

        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);

        address pair = IUniswapV2Factory(FACTORY).getPair(tokenA, tokenB);
        if (pair == address(0)) revert PairNotFound();

        // slither-disable-next-line unused-return -- only the reserve values are relevant for this formula demo
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        uint256 reserveIn = IUniswapV2Pair(pair).token0() == tokenA ? uint256(reserve0) : uint256(reserve1);
        uint256 swapAmount = getSwapAmount(reserveIn, amountA);

        uint256 swapOut = _swap(tokenA, tokenB, swapAmount);
        (,, liquidity) = _addLiquidity(tokenA, tokenB);

        // slither-disable-next-line reentrancy-events -- only emits values derived from completed router calls
        emit ZapExecuted(tokenA, tokenB, amountA, swapOut, liquidity);
    }

    /// @notice Naive one-sided supply: swap half and then add liquidity.
    function subOptimalZap(address tokenA, address tokenB, uint256 amountA) external returns (uint256 liquidity) {
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);

        uint256 swapOut = _swap(tokenA, tokenB, amountA / 2);
        (,, liquidity) = _addLiquidity(tokenA, tokenB);

        // slither-disable-next-line reentrancy-events -- only emits values derived from completed router calls
        emit ZapExecuted(tokenA, tokenB, amountA, swapOut, liquidity);
    }

    function _swap(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256 amountOut) {
        IERC20(tokenIn).forceApprove(ROUTER, amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amounts =
            IUniswapV2Router(ROUTER).swapExactTokensForTokens(amountIn, 1, path, address(this), block.timestamp);
        amountOut = amounts[amounts.length - 1];
    }

    function _addLiquidity(address tokenA, address tokenB)
        internal
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        uint256 balA = IERC20(tokenA).balanceOf(address(this));
        uint256 balB = IERC20(tokenB).balanceOf(address(this));

        IERC20(tokenA).forceApprove(ROUTER, balA);
        IERC20(tokenB).forceApprove(ROUTER, balB);

        (amountA, amountB, liquidity) =
            IUniswapV2Router(ROUTER).addLiquidity(tokenA, tokenB, balA, balB, 0, 0, address(this), block.timestamp);
    }
}
