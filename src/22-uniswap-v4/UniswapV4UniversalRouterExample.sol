// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

import {
    Currency,
    CurrencyLibrary,
    IPermit2,
    IUniversalRouter,
    IV4Router,
    PoolId,
    PoolIdLibrary,
    PoolKey
} from "./interfaces/IUniswapV4.sol";

/// @title UniswapV4UniversalRouterExample
/// @notice Demonstrates the higher-level Universal Router path for v4 exact-input swaps with Permit2 allowance forwarding.
/// @dev This route is easier than raw `PoolManager` callbacks, but searchers should still inspect pool state before execution.
contract UniswapV4UniversalRouterExample {
    using SafeERC20 for IERC20;
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    uint8 internal constant COMMAND_V4_SWAP = 0x10;
    uint8 internal constant ACTION_SWAP_EXACT_IN_SINGLE = 0x06;
    uint8 internal constant ACTION_SETTLE_ALL = 0x0c;
    uint8 internal constant ACTION_TAKE_ALL = 0x0f;

    struct ExactInputSingleRequest {
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMinimum;
        uint256 deadline;
        address recipient;
        bytes hookData;
    }

    IUniversalRouter public immutable router;
    IPermit2 public immutable permit2;

    event Permit2Approval(address indexed token, uint160 amount, uint48 expiration);
    event RouterExactIn(
        PoolId indexed poolId,
        address indexed initiator,
        address indexed recipient,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOut
    );

    error ZeroAddress();
    error InvalidAmount();
    error InvalidRecipient();
    error NativeCurrencyNotSupported();

    constructor(address router_, address permit2_) {
        if (router_ == address(0) || permit2_ == address(0)) revert ZeroAddress();
        router = IUniversalRouter(router_);
        permit2 = IPermit2(permit2_);
    }

    /// @notice Approves the Universal Router via Permit2 using this contract's token balance.
    function approveTokenWithPermit2(address token, uint160 amount, uint48 expiration) public {
        IERC20(token).forceApprove(address(permit2), type(uint256).max);
        permit2.approve(token, address(router), amount, expiration);
        emit Permit2Approval(token, amount, expiration);
    }

    /// @notice Returns the raw Universal Router command/input payload for a single-hop v4 exact-input swap.
    function encodeExactInputSingle(
        PoolKey calldata key,
        bool zeroForOne,
        uint128 amountIn,
        uint128 amountOutMinimum,
        bytes calldata hookData
    ) external pure returns (bytes memory commands, bytes[] memory inputs) {
        (commands, inputs) = _encodeExactInputSingle(key, zeroForOne, amountIn, amountOutMinimum, hookData);
    }

    /// @notice Pulls ERC20s from the caller, approves Permit2 -> Universal Router, executes the swap, and forwards output tokens.
    function swapExactInputSingle(
        PoolKey calldata key,
        bool zeroForOne,
        uint128 amountIn,
        uint128 amountOutMinimum,
        uint256 deadline,
        address recipient,
        bytes calldata hookData
    ) external returns (uint256 amountOut) {
        ExactInputSingleRequest memory request = ExactInputSingleRequest({
            zeroForOne: zeroForOne,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            deadline: deadline,
            recipient: recipient,
            hookData: hookData
        });
        amountOut = _swapExactInputSingle(key, request);
    }

    function _swapExactInputSingle(PoolKey calldata key, ExactInputSingleRequest memory request)
        internal
        returns (uint256 amountOut)
    {
        if (request.amountIn == 0) revert InvalidAmount();
        if (request.recipient == address(0)) revert InvalidRecipient();

        Currency inputCurrency = request.zeroForOne ? key.currency0 : key.currency1;
        Currency outputCurrency = request.zeroForOne ? key.currency1 : key.currency0;
        if (inputCurrency.isAddressZero() || outputCurrency.isAddressZero()) revert NativeCurrencyNotSupported();

        address tokenIn = Currency.unwrap(inputCurrency);
        address tokenOut = Currency.unwrap(outputCurrency);

        // Pre-pull `amountIn`, then refund any remainder. V4 `SETTLE_ALL` only pulls the open
        // debt, which can be less than `amountIn` when liquidity is thin or a hook returns delta.
        uint256 startBalanceIn = IERC20(tokenIn).balanceOf(address(this));
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), request.amountIn);
        approveTokenWithPermit2(
            tokenIn,
            uint160(request.amountIn),
            request.deadline > type(uint48).max ? type(uint48).max : uint48(request.deadline)
        );

        uint256 beforeOut = IERC20(tokenOut).balanceOf(address(this));
        (bytes memory commands, bytes[] memory inputs) = _encodeExactInputSingle(
            key, request.zeroForOne, request.amountIn, request.amountOutMinimum, request.hookData
        );
        router.execute(commands, inputs, request.deadline);
        amountOut = IERC20(tokenOut).balanceOf(address(this)) - beforeOut;
        IERC20(tokenOut).safeTransfer(request.recipient, amountOut);
        _refundTokenDelta(tokenIn, msg.sender, startBalanceIn);

        emit RouterExactIn(key.toId(), msg.sender, request.recipient, request.zeroForOne, request.amountIn, amountOut);
    }

    function _refundTokenDelta(address token, address recipient, uint256 startingBalance) internal {
        uint256 endingBalance = IERC20(token).balanceOf(address(this));
        if (endingBalance > startingBalance) {
            IERC20(token).safeTransfer(recipient, endingBalance - startingBalance);
        }
    }

    function _encodeExactInputSingle(
        PoolKey calldata key,
        bool zeroForOne,
        uint128 amountIn,
        uint128 amountOutMinimum,
        bytes memory hookData
    ) internal pure returns (bytes memory commands, bytes[] memory inputs) {
        Currency inputCurrency = zeroForOne ? key.currency0 : key.currency1;
        Currency outputCurrency = zeroForOne ? key.currency1 : key.currency0;

        commands = abi.encodePacked(bytes1(COMMAND_V4_SWAP));
        bytes memory actions =
            abi.encodePacked(bytes1(ACTION_SWAP_EXACT_IN_SINGLE), bytes1(ACTION_SETTLE_ALL), bytes1(ACTION_TAKE_ALL));

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                minHopPriceX36: 0,
                hookData: hookData
            })
        );
        params[1] = abi.encode(inputCurrency, amountIn);
        params[2] = abi.encode(outputCurrency, amountOutMinimum);

        inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);
    }
}
