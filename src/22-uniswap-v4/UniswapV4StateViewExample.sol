// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IPositionManager, IStateView, PoolId, PoolKey, PositionInfo, PoolIdLibrary} from "./interfaces/IUniswapV4.sol";

/// @title UniswapV4StateViewExample
/// @notice Read-only helpers for deriving pool ids, reading singleton pool state, and inspecting PositionManager NFTs.
/// @dev Searcher-style simulations should prefer these deterministic reads before attempting swaps on the fork.
contract UniswapV4StateViewExample {
    using PoolIdLibrary for PoolKey;

    IStateView public immutable stateView;
    IPositionManager public immutable positionManager;

    error ZeroAddress();

    constructor(address stateView_, address positionManager_) {
        if (stateView_ == address(0) || positionManager_ == address(0)) revert ZeroAddress();
        stateView = IStateView(stateView_);
        positionManager = IPositionManager(positionManager_);
    }

    function poolId(PoolKey calldata key) external pure returns (PoolId id) {
        id = PoolIdLibrary.toId(key);
    }

    /// @notice Reads `slot0` plus aggregate liquidity for a pool key.
    function readPoolState(PoolKey calldata key)
        external
        view
        returns (PoolId id, uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee, uint128 liquidity)
    {
        id = PoolIdLibrary.toId(key);
        (sqrtPriceX96, tick, protocolFee, lpFee) = stateView.getSlot0(id);
        liquidity = stateView.getLiquidity(id);
    }

    /// @notice Reads global fee growth for a pool, useful when simulating LP fee accrual off-chain.
    function readFeeGrowthGlobals(PoolKey calldata key)
        external
        view
        returns (uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128)
    {
        return stateView.getFeeGrowthGlobals(PoolIdLibrary.toId(key));
    }

    /// @notice Reads a position directly from `StateView` using the low-level owner/range/salt tuple.
    function readPositionInfo(PoolKey calldata key, address owner, int24 tickLower, int24 tickUpper, bytes32 salt)
        external
        view
        returns (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128)
    {
        return stateView.getPositionInfo(PoolIdLibrary.toId(key), owner, tickLower, tickUpper, salt);
    }

    /// @notice Reads PositionManager NFT metadata and decodes its packed tick information.
    function readPositionNft(uint256 tokenId)
        external
        view
        returns (
            PoolKey memory key,
            bytes25 truncatedPoolId,
            int24 tickLower,
            int24 tickUpper,
            bool hasSubscriber,
            uint128 liquidity
        )
    {
        PositionInfo info;
        (key, info) = positionManager.getPoolAndPositionInfo(tokenId);
        truncatedPoolId = info.poolId();
        tickLower = info.tickLower();
        tickUpper = info.tickUpper();
        hasSubscriber = info.hasSubscriber();
        liquidity = positionManager.getPositionLiquidity(tokenId);
    }
}
