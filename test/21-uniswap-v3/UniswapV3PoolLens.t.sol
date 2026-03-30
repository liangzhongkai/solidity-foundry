// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";

import {UniswapV3PoolLens} from "../../src/21-uniswap-v3/UniswapV3PoolLens.sol";

/// @notice Fork tests for pool discovery and `slot0` reads. Skips when mainnet contracts are unavailable.
contract UniswapV3PoolLensTest is Test {
    address internal constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    uint24 internal constant FEE_030 = 3000;

    UniswapV3PoolLens internal lens;

    function setUp() public {
        lens = new UniswapV3PoolLens(FACTORY);
    }

    function _skipIfNoFork() internal {
        if (FACTORY.code.length == 0) vm.skip(true);
    }

    /// @dev Shows `getPool` works with either token ordering — integrators still pass sorted tokens to mint.
    function testGetPoolIsSymmetricForTokenOrder() public {
        _skipIfNoFork();
        address p0 = lens.getPool(WETH, DAI, FEE_030);
        address p1 = lens.getPool(DAI, WETH, FEE_030);
        assertEq(p0, p1);
        assertTrue(p0 != address(0));
    }

    /// @dev `slot0` gives the live sqrt price and tick; do not treat it as a binding quote for the next block.
    function testReadPoolStateReturnsOrderedTokensAndLiquidity() public {
        _skipIfNoFork();
        (uint160 sqrtPriceX96, int24 tick, uint128 liquidity, address token0, address token1) =
            lens.readPoolState(WETH, DAI, FEE_030);

        assertTrue(sqrtPriceX96 > 0);
        assertTrue(liquidity > 0);
        assertTrue(token0 < token1);
        assertEq(token0, DAI);
        assertEq(token1, WETH);
        // tick moves with price; only sanity-check it parses
        assertTrue(tick > type(int24).min && tick < type(int24).max);
    }

    function testReadPoolStateRevertsWhenPoolMissing() public {
        address fakeA = makeAddr("fakeA");
        address fakeB = makeAddr("fakeB");
        if (FACTORY.code.length == 0) {
            vm.expectRevert();
        } else {
            vm.expectRevert(UniswapV3PoolLens.PoolNotFound.selector);
        }
        lens.readPoolState(fakeA, fakeB, FEE_030);
    }
}
