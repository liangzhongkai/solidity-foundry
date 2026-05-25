// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

import {
    BalanceDelta,
    BalanceDeltaLibrary,
    Currency,
    CurrencyLibrary,
    IHooks,
    IPoolManager,
    IUnlockCallback,
    ModifyLiquidityParams,
    PoolId,
    PoolIdLibrary,
    PoolKey,
    SwapParams
} from "./interfaces/IUniswapV4.sol";

/// @title UniswapV4PoolManagerExample
/// @notice Direct singleton interactions for initializing pools, modifying liquidity, swapping, and donating.
/// @dev This contract demonstrates the unlock callback flow that searchers and advanced integrators must understand for raw v4 core usage.
contract UniswapV4PoolManagerExample is IUnlockCallback {
    using SafeERC20 for IERC20;
    using BalanceDeltaLibrary for BalanceDelta;
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    uint160 internal constant MIN_SQRT_PRICE_PLUS_ONE = 4_295_128_740;
    uint160 internal constant MAX_SQRT_PRICE_MINUS_ONE =
        1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341;

    enum Operation {
        SwapExactIn,
        ModifyLiquidity,
        Donate
    }

    struct CallbackState {
        Operation op;
        address payer;
        address recipient;
        PoolKey key;
        bytes hookData;
        bool zeroForOne;
        uint256 amountIn;
        uint256 minAmountOut;
        uint160 sqrtPriceLimitX96;
        ModifyLiquidityParams liquidityParams;
        uint256 amount0;
        uint256 amount1;
        uint256 nativeValue;
    }

    IPoolManager public immutable poolManager;

    event PoolInitialized(PoolId indexed poolId, int24 tick);
    event DirectSwap(
        PoolId indexed poolId,
        address indexed initiator,
        address indexed recipient,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOut
    );
    event DirectModifyLiquidity(
        PoolId indexed poolId,
        address indexed initiator,
        address indexed recipient,
        int24 tickLower,
        int24 tickUpper,
        int256 liquidityDelta,
        int128 callerDelta0,
        int128 callerDelta1,
        int128 feesAccrued0,
        int128 feesAccrued1
    );
    event DirectDonate(PoolId indexed poolId, address indexed initiator, uint256 amount0, uint256 amount1);

    error ZeroAddress();
    error InvalidAmount();
    error InvalidRecipient();
    error NotPoolManager();
    error NativeCurrencyNotSupported();
    error InsufficientOutput(uint256 amountOut, uint256 minAmountOut);
    error NativeValueTooLow(uint256 requiredAmount, uint256 availableAmount);
    error NativeRefundFailed();

    constructor(address poolManager_) {
        if (poolManager_ == address(0)) revert ZeroAddress();
        poolManager = IPoolManager(poolManager_);
    }

    /// @notice Initializes a new pool key directly on the singleton.
    function initializePool(PoolKey calldata key, uint160 sqrtPriceX96) external returns (int24 tick) {
        tick = poolManager.initialize(key, sqrtPriceX96);
        emit PoolInitialized(key.toId(), tick);
    }

    /// @notice Executes an exact-input swap directly against `PoolManager` through the unlock callback.
    /// @dev `sqrtPriceLimitX96 == 0` uses the widest TickMath bound for the chosen direction.
    function swapExactInput(
        PoolKey calldata key,
        bool zeroForOne,
        uint128 amountIn,
        uint128 minAmountOut,
        uint160 sqrtPriceLimitX96,
        bytes calldata hookData,
        address recipient
    ) external payable returns (uint256 amountOut) {
        if (amountIn == 0) revert InvalidAmount();
        if (recipient == address(0)) revert InvalidRecipient();

        CallbackState memory state = CallbackState({
            op: Operation.SwapExactIn,
            payer: msg.sender,
            recipient: recipient,
            key: key,
            hookData: hookData,
            zeroForOne: zeroForOne,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            sqrtPriceLimitX96: sqrtPriceLimitX96,
            liquidityParams: ModifyLiquidityParams({tickLower: 0, tickUpper: 0, liquidityDelta: 0, salt: bytes32(0)}),
            amount0: 0,
            amount1: 0,
            nativeValue: msg.value
        });

        amountOut = abi.decode(poolManager.unlock(abi.encode(state)), (uint256));
    }

    /// @notice Adds or removes concentrated liquidity directly through the singleton, then settles any net token deltas.
    function modifyLiquidity(
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData,
        address recipient
    ) external payable returns (BalanceDelta callerDelta, BalanceDelta feesAccrued) {
        if (recipient == address(0)) revert InvalidRecipient();

        CallbackState memory state = CallbackState({
            op: Operation.ModifyLiquidity,
            payer: msg.sender,
            recipient: recipient,
            key: key,
            hookData: hookData,
            zeroForOne: false,
            amountIn: 0,
            minAmountOut: 0,
            sqrtPriceLimitX96: 0,
            liquidityParams: params,
            amount0: 0,
            amount1: 0,
            nativeValue: msg.value
        });

        (callerDelta, feesAccrued) = abi.decode(poolManager.unlock(abi.encode(state)), (BalanceDelta, BalanceDelta));
    }

    /// @notice Donates to the in-range liquidity providers of a pool and settles the resulting negative deltas.
    function donate(PoolKey calldata key, uint256 amount0, uint256 amount1, bytes calldata hookData) external payable {
        if (amount0 == 0 && amount1 == 0) revert InvalidAmount();

        CallbackState memory state = CallbackState({
            op: Operation.Donate,
            payer: msg.sender,
            recipient: msg.sender,
            key: key,
            hookData: hookData,
            zeroForOne: false,
            amountIn: 0,
            minAmountOut: 0,
            sqrtPriceLimitX96: 0,
            liquidityParams: ModifyLiquidityParams({tickLower: 0, tickUpper: 0, liquidityDelta: 0, salt: bytes32(0)}),
            amount0: amount0,
            amount1: amount1,
            nativeValue: msg.value
        });

        poolManager.unlock(abi.encode(state));
    }

    /// @inheritdoc IUnlockCallback
    function unlockCallback(bytes calldata data) external override returns (bytes memory result) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();

        CallbackState memory state = abi.decode(data, (CallbackState));
        if (state.op == Operation.SwapExactIn) {
            return _handleSwap(state);
        }
        if (state.op == Operation.ModifyLiquidity) {
            return _handleModifyLiquidity(state);
        }
        return _handleDonate(state);
    }

    function _handleSwap(CallbackState memory state) internal returns (bytes memory result) {
        SwapParams memory params = SwapParams({
            zeroForOne: state.zeroForOne,
            amountSpecified: -int256(state.amountIn),
            sqrtPriceLimitX96: state.sqrtPriceLimitX96 == 0
                ? (state.zeroForOne ? MIN_SQRT_PRICE_PLUS_ONE : MAX_SQRT_PRICE_MINUS_ONE)
                : state.sqrtPriceLimitX96
        });

        BalanceDelta delta = poolManager.swap(state.key, params, state.hookData);
        uint256 nativeRemaining = _settleDelta(state.key, delta, state.payer, state.recipient, state.nativeValue);
        _refundNative(state.payer, nativeRemaining);

        uint256 amountOut = state.zeroForOne ? _positiveAmount1(delta) : _positiveAmount0(delta);
        if (amountOut < state.minAmountOut) revert InsufficientOutput(amountOut, state.minAmountOut);

        emit DirectSwap(state.key.toId(), state.payer, state.recipient, state.zeroForOne, state.amountIn, amountOut);
        result = abi.encode(amountOut);
    }

    function _handleModifyLiquidity(CallbackState memory state) internal returns (bytes memory result) {
        (BalanceDelta callerDelta, BalanceDelta feesAccrued) =
            poolManager.modifyLiquidity(state.key, state.liquidityParams, state.hookData);

        uint256 nativeRemaining = _settleDelta(state.key, callerDelta, state.payer, state.recipient, state.nativeValue);
        _refundNative(state.payer, nativeRemaining);

        emit DirectModifyLiquidity(
            state.key.toId(),
            state.payer,
            state.recipient,
            state.liquidityParams.tickLower,
            state.liquidityParams.tickUpper,
            state.liquidityParams.liquidityDelta,
            callerDelta.amount0(),
            callerDelta.amount1(),
            feesAccrued.amount0(),
            feesAccrued.amount1()
        );

        result = abi.encode(callerDelta, feesAccrued);
    }

    function _handleDonate(CallbackState memory state) internal returns (bytes memory result) {
        BalanceDelta delta = poolManager.donate(state.key, state.amount0, state.amount1, state.hookData);
        uint256 nativeRemaining = _settleDelta(state.key, delta, state.payer, state.recipient, state.nativeValue);
        _refundNative(state.payer, nativeRemaining);

        emit DirectDonate(state.key.toId(), state.payer, state.amount0, state.amount1);
        result = abi.encode(delta);
    }

    function _settleDelta(PoolKey memory key, BalanceDelta delta, address payer, address recipient, uint256 nativeValue)
        internal
        returns (uint256 nativeRemaining)
    {
        nativeRemaining = nativeValue;

        int128 delta0 = delta.amount0();
        if (delta0 < 0) {
            nativeRemaining = _settleCurrency(key.currency0, payer, uint256(uint128(-delta0)), nativeRemaining);
        } else if (delta0 > 0) {
            poolManager.take(key.currency0, recipient, uint256(uint128(delta0)));
        }

        int128 delta1 = delta.amount1();
        if (delta1 < 0) {
            nativeRemaining = _settleCurrency(key.currency1, payer, uint256(uint128(-delta1)), nativeRemaining);
        } else if (delta1 > 0) {
            poolManager.take(key.currency1, recipient, uint256(uint128(delta1)));
        }
    }

    function _settleCurrency(Currency currency, address payer, uint256 amount, uint256 nativeRemaining)
        internal
        returns (uint256 updatedNativeRemaining)
    {
        if (currency.isAddressZero()) {
            if (nativeRemaining < amount) revert NativeValueTooLow(amount, nativeRemaining);
            poolManager.settle{value: amount}();
            return nativeRemaining - amount;
        }

        address token = Currency.unwrap(currency);
        poolManager.sync(currency);
        IERC20(token).safeTransferFrom(payer, address(this), amount);
        IERC20(token).safeTransfer(address(poolManager), amount);
        poolManager.settle();
        return nativeRemaining;
    }

    function _refundNative(address recipient, uint256 amount) internal {
        if (amount == 0) return;
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert NativeRefundFailed();
    }

    function _positiveAmount0(BalanceDelta delta) internal pure returns (uint256) {
        int128 amount0 = delta.amount0();
        return amount0 > 0 ? uint256(uint128(amount0)) : 0;
    }

    function _positiveAmount1(BalanceDelta delta) internal pure returns (uint256) {
        int128 amount1 = delta.amount1();
        return amount1 > 0 ? uint256(uint128(amount1)) : 0;
    }
}
