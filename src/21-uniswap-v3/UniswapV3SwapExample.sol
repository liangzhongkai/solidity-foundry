// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

import {ISwapRouter} from "./interfaces/IUniswapV3.sol";

/// @title UniswapV3SwapExample
/// @notice Demonstrates `SwapRouter.exactInputSingle` with explicit fee tier and slippage controls.
/// @dev Production tips encoded in NatSpec: deadlines, `sqrtPriceLimitX96`, and matching the pool's fee tier.
contract UniswapV3SwapExample {
    using SafeERC20 for IERC20;

    address public constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    event ExactInSingle(
        address indexed tokenIn,
        address indexed tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOut,
        address indexed recipient
    );

    error ZeroAddress();

    /// @notice Swap an exact amount of `tokenIn` for `tokenOut` through a single V3 pool.
    /// @param tokenIn Input token (must match a live pool with `tokenOut` at `fee`).
    /// @param tokenOut Output token.
    /// @param fee Pool fee tier in hundredths of a bip (e.g. 3000 = 0.30%). Must match an existing pool.
    /// @param amountIn Exact input amount pulled from `msg.sender`.
    /// @param amountOutMinimum Minimum output; set from an off-chain quote with slippage — on-chain `slot0` alone is not a safe quote.
    /// @param sqrtPriceLimitX96 Price limit for the swap; `0` disables the limit (common for integrators that enforce slippage via `amountOutMinimum` only).
    /// @param deadline Unix timestamp after which the router reverts; in production prefer `block.timestamp + delta` rather than bare `block.timestamp`.
    /// @param recipient Receiver of `tokenOut`.
    function swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96,
        uint256 deadline,
        address recipient
    ) external returns (uint256 amountOut) {
        if (recipient == address(0)) revert ZeroAddress();

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).forceApprove(SWAP_ROUTER, amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: recipient,
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        // slither-disable-next-line reentrancy-events -- emits only after canonical router returns completed swap amounts
        amountOut = ISwapRouter(SWAP_ROUTER).exactInputSingle(params);

        emit ExactInSingle(tokenIn, tokenOut, fee, amountIn, amountOut, recipient);
    }
}
