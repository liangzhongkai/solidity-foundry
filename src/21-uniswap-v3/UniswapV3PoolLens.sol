// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IUniswapV3Factory, IUniswapV3Pool} from "./interfaces/IUniswapV3.sol";

/// @title UniswapV3PoolLens
/// @notice Read-only helpers for discovering pools and inspecting on-chain price state.
/// @dev Production note: `slot0` is a spot snapshot; sandwiching and ordering across txs can move price before your swap executes.
// slither-disable-next-line missing-inheritance -- helper contract; does not implement the factory interface surface
contract UniswapV3PoolLens {
    address public immutable factory;

    error ZeroAddress();
    error PoolNotFound();

    constructor(address factory_) {
        if (factory_ == address(0)) revert ZeroAddress();
        factory = factory_;
    }

    /// @notice Returns the canonical pool address for `(tokenA, tokenB, fee)`; tokens need not be sorted.
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool) {
        pool = IUniswapV3Factory(factory).getPool(tokenA, tokenB, fee);
        if (pool == address(0)) {
            pool = IUniswapV3Factory(factory).getPool(tokenB, tokenA, fee);
        }
    }

    /// @notice Reads `slot0` and liquidity for a live pool; reverts if the pool does not exist.
    function readPoolState(address tokenA, address tokenB, uint24 fee)
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint128 liquidity, address token0, address token1)
    {
        address pool = IUniswapV3Factory(factory).getPool(tokenA, tokenB, fee);
        if (pool == address(0)) {
            pool = IUniswapV3Factory(factory).getPool(tokenB, tokenA, fee);
        }
        if (pool == address(0)) revert PoolNotFound();

        token0 = IUniswapV3Pool(pool).token0();
        token1 = IUniswapV3Pool(pool).token1();
        liquidity = IUniswapV3Pool(pool).liquidity();
        (sqrtPriceX96, tick,,,,,) = IUniswapV3Pool(pool).slot0();
    }
}
