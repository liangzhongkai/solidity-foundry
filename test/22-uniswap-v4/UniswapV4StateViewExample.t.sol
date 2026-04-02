// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {PoolId, PoolIdLibrary, PoolKey} from "../../src/22-uniswap-v4/interfaces/IUniswapV4.sol";
import {UniswapV4Base} from "./UniswapV4Base.t.sol";

contract UniswapV4StateViewExampleTest is UniswapV4Base {
    using PoolIdLibrary for PoolKey;

    function testPoolIdMatchesLibraryHash() public {
        PoolKey memory key = _poolKey();
        assertEq(PoolId.unwrap(stateExample.poolId(key)), PoolId.unwrap(key.toId()));
    }

    /// @dev Searchers generally read singleton state before routing or quoting.
    function testReadPoolStateAfterCoreLiquiditySeed() public {
        (PoolKey memory key,) = _seedCorePool();

        (PoolId id, uint160 sqrtPriceX96, int24 tick,, uint24 lpFee, uint128 liquidity) =
            stateExample.readPoolState(key);

        assertEq(PoolId.unwrap(id), PoolId.unwrap(key.toId()));
        assertEq(sqrtPriceX96, SQRT_PRICE_1_1);
        assertEq(tick, 0);
        assertEq(lpFee, FEE);
        assertGt(liquidity, 0);
    }

    function testReadPositionNftAfterMint() public {
        (PoolKey memory key, uint256 tokenId,) = _mintPositionToWrapper();

        (
            PoolKey memory storedKey,
            bytes25 truncatedPoolId,
            int24 tickLower,
            int24 tickUpper,
            bool hasSubscriber,
            uint128 liquidity
        ) = stateExample.readPositionNft(tokenId);

        assertEq(PoolId.unwrap(storedKey.toId()), PoolId.unwrap(key.toId()));
        assertEq(truncatedPoolId, bytes25(PoolId.unwrap(key.toId())));
        assertEq(tickLower, TICK_LOWER);
        assertEq(tickUpper, TICK_UPPER);
        assertFalse(hasSubscriber);
        assertGt(liquidity, 0);
    }
}
