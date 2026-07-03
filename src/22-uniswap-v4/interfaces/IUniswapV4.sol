// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

type Currency is address;
type PoolId is bytes32;
type BalanceDelta is int256;
type PositionInfo is uint256;

/// @dev Minimal hooks marker interface for pool keys.
interface IHooks {}

struct PoolKey {
    Currency currency0;
    Currency currency1;
    uint24 fee;
    int24 tickSpacing;
    IHooks hooks;
}

struct ModifyLiquidityParams {
    int24 tickLower;
    int24 tickUpper;
    int256 liquidityDelta;
    bytes32 salt;
}

struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
}

struct PathKey {
    Currency intermediateCurrency;
    uint24 fee;
    int24 tickSpacing;
    IHooks hooks;
    bytes hookData;
}

using CurrencyLibrary for Currency global;
using PoolIdLibrary for PoolKey global;
using BalanceDeltaLibrary for BalanceDelta global;
using PositionInfoLibrary for PositionInfo global;

library CurrencyLibrary {
    Currency internal constant ADDRESS_ZERO = Currency.wrap(address(0));

    function isAddressZero(Currency currency) internal pure returns (bool) {
        return Currency.unwrap(currency) == address(0);
    }

    function toId(Currency currency) internal pure returns (uint256) {
        return uint160(Currency.unwrap(currency));
    }
}

library PoolIdLibrary {
    function toId(PoolKey memory poolKey) internal pure returns (PoolId poolId) {
        assembly ("memory-safe") {
            poolId := keccak256(poolKey, 0xa0)
        }
    }
}

library BalanceDeltaLibrary {
    function amount0(BalanceDelta balanceDelta) internal pure returns (int128 delta0) {
        assembly ("memory-safe") {
            delta0 := sar(128, balanceDelta)
        }
    }

    function amount1(BalanceDelta balanceDelta) internal pure returns (int128 delta1) {
        assembly ("memory-safe") {
            delta1 := signextend(15, balanceDelta)
        }
    }
}

library PositionInfoLibrary {
    uint256 internal constant MASK_UPPER_200_BITS = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000;
    uint256 internal constant MASK_8_BITS = 0xFF;
    uint24 internal constant MASK_24_BITS = 0xFFFFFF;
    uint8 internal constant TICK_LOWER_OFFSET = 8;
    uint8 internal constant TICK_UPPER_OFFSET = 32;

    function poolId(PositionInfo info) internal pure returns (bytes25 truncatedPoolId) {
        assembly ("memory-safe") {
            truncatedPoolId := and(MASK_UPPER_200_BITS, info)
        }
    }

    function tickLower(PositionInfo info) internal pure returns (int24 lower) {
        assembly ("memory-safe") {
            lower := signextend(2, shr(TICK_LOWER_OFFSET, info))
        }
    }

    function tickUpper(PositionInfo info) internal pure returns (int24 upper) {
        assembly ("memory-safe") {
            upper := signextend(2, shr(TICK_UPPER_OFFSET, info))
        }
    }

    function hasSubscriber(PositionInfo info) internal pure returns (bool subscribed) {
        assembly ("memory-safe") {
            subscribed := and(MASK_8_BITS, info)
        }
    }
}

interface IUnlockCallback {
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}

interface IPoolManager {
    function unlock(bytes calldata data) external returns (bytes memory);

    function initialize(PoolKey memory key, uint160 sqrtPriceX96) external returns (int24 tick);

    function modifyLiquidity(PoolKey memory key, ModifyLiquidityParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta callerDelta, BalanceDelta feesAccrued);

    function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta swapDelta);

    function donate(PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData)
        external
        returns (BalanceDelta delta);

    function sync(Currency currency) external;

    function take(Currency currency, address to, uint256 amount) external;

    function settle() external payable returns (uint256 paid);

    function settleFor(address recipient) external payable returns (uint256 paid);

    function clear(Currency currency, uint256 amount) external;

    function mint(address to, uint256 id, uint256 amount) external;

    function burn(address from, uint256 id, uint256 amount) external;

    function updateDynamicLPFee(PoolKey memory key, uint24 newDynamicLPFee) external;
}

interface IStateView {
    function getSlot0(PoolId poolId)
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee);

    function getFeeGrowthGlobals(PoolId poolId)
        external
        view
        returns (uint256 feeGrowthGlobal0, uint256 feeGrowthGlobal1);

    function getLiquidity(PoolId poolId) external view returns (uint128 liquidity);

    function getPositionInfo(PoolId poolId, address owner, int24 tickLower, int24 tickUpper, bytes32 salt)
        external
        view
        returns (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128);
}

interface IV4Router {
    struct ExactInputSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMinimum;
        uint256 minHopPriceX36;
        bytes hookData;
    }

    struct ExactInputParams {
        Currency currencyIn;
        PathKey[] path;
        uint256[] minHopPriceX36;
        uint128 amountIn;
        uint128 amountOutMinimum;
    }
}

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

interface IAllowanceTransfer {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

interface IPermit2 is IAllowanceTransfer {}

interface IPositionManager {
    function modifyLiquidities(bytes calldata unlockData, uint256 deadline) external payable;

    function modifyLiquiditiesWithoutUnlock(bytes calldata actions, bytes[] calldata params) external payable;

    function nextTokenId() external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function getPositionLiquidity(uint256 tokenId) external view returns (uint128 liquidity);

    function getPoolAndPositionInfo(uint256 tokenId) external view returns (PoolKey memory, PositionInfo);

    function positionInfo(uint256 tokenId) external view returns (PositionInfo);
}
