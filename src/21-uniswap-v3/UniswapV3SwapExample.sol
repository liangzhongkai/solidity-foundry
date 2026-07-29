// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

import {
    ISwapRouter,
    IUniswapV3Pool,
    IUniswapV3SwapCallback,
    IUniswapV3FlashCallback
} from "./interfaces/IUniswapV3.sol";

/// @title UniswapV3SwapExample
/// @notice Router swaps (`exactInputSingle` / `exactInput`) plus pool-level **flash loan** (`flash`) and **flash swap** (`swap` with exact output + callback).
/// @dev Callbacks run with `msg.sender` equal to the pool — this contract verifies `pool` before moving funds.
///      Flash flows require `initiator` (original `msg.sender`) to have approved this contract for repayment tokens.
///      Sqrt price limits for flash swap follow Uniswap `TickMath` no-bound pattern (MIN+1 / MAX-1).
contract UniswapV3SwapExample is IUniswapV3SwapCallback, IUniswapV3FlashCallback {
    using SafeERC20 for IERC20;

    address public constant SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    /// @dev Uniswap V3 `TickMath.MIN_SQRT_RATIO + 1` (flash swap limit when swapping token0 -> token1).
    uint160 internal constant MIN_SQRT_RATIO_PLUS_ONE = 4_295_128_740;
    /// @dev Uniswap V3 `TickMath.MAX_SQRT_RATIO - 1` (flash swap limit when swapping token1 -> token0).
    uint160 internal constant MAX_SQRT_RATIO_MINUS_ONE =
        1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341;

    event ExactInSingle(
        address indexed tokenIn,
        address indexed tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOut,
        address indexed recipient
    );

    event ExactIn(bytes path, uint256 amountIn, uint256 amountOut, address indexed recipient);

    event FlashLoan(
        address indexed pool,
        address indexed initiator,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    );

    event FlashSwap(
        address indexed pool,
        address indexed initiator,
        address indexed recipient,
        int256 amount0Delta,
        int256 amount1Delta
    );

    error ZeroAddress();
    error InvalidPath();
    error NotPool();
    error InvalidToken();
    error ZeroAmount();

    /// @notice Packs a router path: `tokens[0] + fees[0] + tokens[1] + fees[1] + ... + tokens[n-1]`.
    function encodePath(address[] calldata tokens, uint24[] calldata fees) external pure returns (bytes memory path) {
        uint256 n = tokens.length;
        if (n < 2 || fees.length != n - 1) revert InvalidPath();

        path = abi.encodePacked(tokens[0], fees[0]);
        for (uint256 i = 1; i < n - 1; i++) {
            path = abi.encodePacked(path, tokens[i], fees[i]);
        }
        path = abi.encodePacked(path, tokens[n - 1]);
    }

    /// @notice Swap an exact amount of `tokenIn` for `tokenOut` through a single V3 pool (via router).
    /// @dev Refunds any unconsumed `tokenIn` to the caller. A non-zero `sqrtPriceLimitX96` (or thin liquidity)
    ///      can stop the swap before the full `amountIn` is pulled by the router, which would otherwise leave
    ///      leftovers permanently stuck in this wrapper.
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

        uint256 balanceBefore = IERC20(tokenIn).balanceOf(address(this));
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
        _refundUnusedInput(tokenIn, msg.sender, balanceBefore);

        emit ExactInSingle(tokenIn, tokenOut, fee, amountIn, amountOut, recipient);
    }

    /// @notice Multi-hop exact input using a packed `path` (via router).
    /// @dev Refunds any unconsumed path input token to the caller after the router returns.
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
        uint256 balanceBefore = IERC20(tokenIn).balanceOf(address(this));
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).forceApprove(SWAP_ROUTER, amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path, recipient: recipient, deadline: deadline, amountIn: amountIn, amountOutMinimum: amountOutMinimum
        });

        // slither-disable-next-line reentrancy-events -- emits only after canonical router returns completed swap amounts
        amountOut = ISwapRouter(SWAP_ROUTER).exactInput(params);
        _refundUnusedInput(tokenIn, msg.sender, balanceBefore);

        emit ExactIn(path, amountIn, amountOut, recipient);
    }

    /// @notice Flash **loan** against a V3 pool: `amount0` / `amount1` of pool tokens are sent to `recipient`, then this contract pulls
    ///         `amount + fee` from `msg.sender` (initiator) and pays the pool inside `uniswapV3FlashCallback`.
    /// @dev Initiator must approve this contract for at least `amount0 + fee0` / `amount1 + fee1` (fees are `amount * fee / 1e6` rounded up).
    function flashLoan(address pool, address recipient, uint256 amount0, uint256 amount1) external {
        if (pool == address(0) || recipient == address(0)) revert ZeroAddress();
        if (amount0 == 0 && amount1 == 0) revert ZeroAmount();

        bytes memory data = abi.encode(msg.sender, pool, amount0, amount1, recipient);
        // slither-disable-next-line reentrancy-events -- full flash completes before emit; no state deps after pool call
        IUniswapV3Pool(pool).flash(recipient, amount0, amount1, data);
    }

    /// @notice Flash **swap** (async / exact output): pool pushes `amountOut` of `tokenOut` to `recipient`; initiator pays owed input in the swap callback.
    /// @param tokenOut Must be the pool's `token0` or `token1`.
    /// @dev Uses exact-output `swap` (`amountSpecified < 0`). Initiator must approve owed input token(s) for this contract.
    function flashSwapExactOutput(address pool, address tokenOut, uint256 amountOut, address recipient) external {
        if (pool == address(0) || recipient == address(0)) revert ZeroAddress();
        if (amountOut == 0) revert ZeroAmount();

        IUniswapV3Pool p = IUniswapV3Pool(pool);
        address t0 = p.token0();
        address t1 = p.token1();
        if (tokenOut != t0 && tokenOut != t1) revert InvalidToken();
        bool zeroForOne = tokenOut == t1;

        uint160 sqrtPriceLimitX96 = zeroForOne ? MIN_SQRT_RATIO_PLUS_ONE : MAX_SQRT_RATIO_MINUS_ONE;

        int256 amountSpecified;
        unchecked {
            amountSpecified = -int256(uint256(amountOut));
        }

        bytes memory data = abi.encode(msg.sender, pool, recipient);
        // slither-disable-next-line reentrancy-events,unused-return -- deltas emitted in `FlashSwap` from swap callback
        p.swap(recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, data);
    }

    /// @inheritdoc IUniswapV3FlashCallback
    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external override {
        (address initiator, address pool, uint256 amt0, uint256 amt1, address recipient) =
            abi.decode(data, (address, address, uint256, uint256, address));
        if (msg.sender != pool) revert NotPool();
        _repayFlashLoan(initiator, pool, amt0, amt1, fee0, fee1);
        emit FlashLoan(pool, initiator, recipient, amt0, amt1, fee0, fee1);
    }

    /// @inheritdoc IUniswapV3SwapCallback
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        (address initiator, address pool, address recipient) = abi.decode(data, (address, address, address));
        if (msg.sender != pool) revert NotPool();
        _paySwapOwed(initiator, pool, amount0Delta, amount1Delta);
        emit FlashSwap(pool, initiator, recipient, amount0Delta, amount1Delta);
    }

    function _repayFlashLoan(address initiator, address pool, uint256 amt0, uint256 amt1, uint256 fee0, uint256 fee1)
        private
    {
        address t0 = IUniswapV3Pool(pool).token0();
        address t1 = IUniswapV3Pool(pool).token1();
        if (amt0 > 0) {
            uint256 pay0 = amt0 + fee0;
            IERC20(t0).safeTransferFrom(initiator, address(this), pay0);
            IERC20(t0).safeTransfer(pool, pay0);
        }
        if (amt1 > 0) {
            uint256 pay1 = amt1 + fee1;
            IERC20(t1).safeTransferFrom(initiator, address(this), pay1);
            IERC20(t1).safeTransfer(pool, pay1);
        }
    }

    function _paySwapOwed(address initiator, address pool, int256 amount0Delta, int256 amount1Delta) private {
        address t0 = IUniswapV3Pool(pool).token0();
        address t1 = IUniswapV3Pool(pool).token1();
        if (amount0Delta > 0) {
            IERC20(t0).safeTransferFrom(initiator, address(this), uint256(amount0Delta));
            IERC20(t0).safeTransfer(pool, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(t1).safeTransferFrom(initiator, address(this), uint256(amount1Delta));
            IERC20(t1).safeTransfer(pool, uint256(amount1Delta));
        }
    }

    function _pathFirstToken(bytes calldata path) private pure returns (address) {
        return abi.decode(abi.encodePacked(bytes12(0), path[:20]), (address));
    }

    /// @dev Returns any `tokenIn` still held above `balanceBefore` and clears residual router approval.
    function _refundUnusedInput(address tokenIn, address recipient, uint256 balanceBefore) private {
        IERC20(tokenIn).forceApprove(SWAP_ROUTER, 0);
        uint256 balanceAfter = IERC20(tokenIn).balanceOf(address(this));
        if (balanceAfter > balanceBefore) {
            IERC20(tokenIn).safeTransfer(recipient, balanceAfter - balanceBefore);
        }
    }
}
