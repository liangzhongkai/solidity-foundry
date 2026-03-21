// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

import {IUniswapV2Router} from "./interfaces/IUniswapV2.sol";

/// @title UniswapV2SwapExample
/// @notice Demonstrates Uniswap V2 token swaps with either a direct WETH hop or a WETH-routed path.
contract UniswapV2SwapExample {
    using SafeERC20 for IERC20;

    address public constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    event SwapExecuted(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, address indexed to
    );

    error ZeroAddress();

    /// @notice Swap an exact amount of `tokenIn` for `tokenOut`.
    /// @param tokenIn The token to sell.
    /// @param tokenOut The token to buy.
    /// @param amountIn The input token amount.
    /// @param amountOutMin The minimum acceptable amount of output tokens.
    /// @param to The recipient of the output tokens.
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin, address to)
        external
        returns (uint256 amountOut)
    {
        if (to == address(0)) revert ZeroAddress();

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).forceApprove(ROUTER, amountIn);

        address[] memory path = _buildPath(tokenIn, tokenOut);
        // slither-disable-next-line reentrancy-events -- only emits router return data after the external call
        uint256[] memory amounts =
            IUniswapV2Router(ROUTER).swapExactTokensForTokens(amountIn, amountOutMin, path, to, block.timestamp);
        amountOut = amounts[amounts.length - 1];

        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut, to);
    }

    /// @notice Quote the minimum output amount for a swap along the same route used by `swap()`.
    function getAmountOutMin(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256) {
        address[] memory path = _buildPath(tokenIn, tokenOut);
        uint256[] memory amountOutMins = IUniswapV2Router(ROUTER).getAmountsOut(amountIn, path);
        return amountOutMins[path.length - 1];
    }

    function _buildPath(address tokenIn, address tokenOut) internal pure returns (address[] memory path) {
        if (tokenIn == WETH || tokenOut == WETH) {
            path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;
            return path;
        }

        path = new address[](3);
        path[0] = tokenIn;
        path[1] = WETH;
        path[2] = tokenOut;
    }
}
