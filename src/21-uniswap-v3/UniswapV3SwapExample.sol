// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

import {ISwapRouter} from "./interfaces/IUniswapV3.sol";

/// @title UniswapV3SwapExample
/// @notice Demonstrates `SwapRouter.exactInputSingle` and `exactInput` (multi-hop) with explicit fee tiers per pool.
/// @dev Production tips: path encoding must match live pools; deadlines; `amountOutMinimum`; each hop's `fee` must exist for that pair.
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

    event ExactIn(bytes path, uint256 amountIn, uint256 amountOut, address indexed recipient);

    error ZeroAddress();
    error InvalidPath();

    /// @notice Packs a router path: `tokens[0] + fees[0] + tokens[1] + fees[1] + ... + tokens[n-1]`.
    /// @dev Requires `fees.length == tokens.length - 1`. Each fee is the pool between the adjacent tokens.
    function encodePath(address[] calldata tokens, uint24[] calldata fees) external pure returns (bytes memory path) {
        uint256 n = tokens.length;
        if (n < 2 || fees.length != n - 1) revert InvalidPath();

        path = abi.encodePacked(tokens[0], fees[0]);
        for (uint256 i = 1; i < n - 1; i++) {
            path = abi.encodePacked(path, tokens[i], fees[i]);
        }
        path = abi.encodePacked(path, tokens[n - 1]);
    }

    /// @notice Swap an exact amount of `tokenIn` for `tokenOut` through a single V3 pool.
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

    /// @notice Multi-hop exact input using a packed `path` (see `encodePath`). Pulls the first token from `msg.sender`.
    /// @param path Packed as `token0 (20) | fee0 (3) | token1 (20) | fee1 (3) | ... | tokenOut (20)`.
    function swapExactInput(
        bytes calldata path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline,
        address recipient
    ) external returns (uint256 amountOut) {
        if (recipient == address(0)) revert ZeroAddress();
        if (path.length < 43) revert InvalidPath();

        address tokenIn = _pathFirstToken(path);
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).forceApprove(SWAP_ROUTER, amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path, recipient: recipient, deadline: deadline, amountIn: amountIn, amountOutMinimum: amountOutMinimum
        });

        // slither-disable-next-line reentrancy-events -- emits only after canonical router returns completed swap amounts
        amountOut = ISwapRouter(SWAP_ROUTER).exactInput(params);

        emit ExactIn(path, amountIn, amountOut, recipient);
    }

    function _pathFirstToken(bytes calldata path) private pure returns (address) {
        return abi.decode(abi.encodePacked(bytes12(0), path[:20]), (address));
    }
}
