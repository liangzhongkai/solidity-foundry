// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";

import {UniswapV3LiquidityNftExample} from "../../src/21-uniswap-v3/UniswapV3LiquidityNftExample.sol";
import {
    IUniswapV3Factory,
    IUniswapV3Pool,
    INonfungiblePositionManager
} from "../../src/21-uniswap-v3/interfaces/IUniswapV3.sol";

interface IWETH {
    function deposit() external payable;
}

/// @notice Unit tests for tick math plus fork mint flow against canonical mainnet NPM.
contract UniswapV3LiquidityNftExampleTest is Test {
    address internal constant NPM = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address internal constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    uint24 internal constant FEE_030 = 3000;

    UniswapV3LiquidityNftExample internal example;

    function setUp() public {
        example = new UniswapV3LiquidityNftExample(NPM);
        if (NPM.code.length == 0) {
            vm.skip(true);
        }
    }

    function testFeeToTickSpacingMatchesV3Constants() public view {
        assertTrue(example.feeToTickSpacing(100) == int24(1));
        assertTrue(example.feeToTickSpacing(500) == int24(10));
        assertTrue(example.feeToTickSpacing(3000) == int24(60));
        assertTrue(example.feeToTickSpacing(10_000) == int24(200));
    }

    function testFloorTickToSpacingHandlesNegativeTicks() public view {
        assertEq(example.floorTickToSpacing(-55, 60), -60);
        assertEq(example.floorTickToSpacing(65, 60), 60);
    }

    /// @dev Mint sends the NFT to `msg.sender`; asymmetric deposits are normal when price sits inside the range.
    function testMintPositionCreatesNft() public {
        address lp = makeAddr("lp");
        vm.deal(lp, 5 ether);
        vm.startPrank(lp);
        IWETH(WETH).deposit{value: 2 ether}();
        deal(DAI, lp, 5_000 ether);

        IERC20(WETH).approve(address(example), 2 ether);
        IERC20(DAI).approve(address(example), 5_000 ether);

        (int24 lower, int24 upper) = _symmetricTickWindow(WETH, DAI, FEE_030, 600);

        uint256 tokenId = example.mintPosition(
            WETH, DAI, FEE_030, lower, upper, 2 ether, 5_000 ether, 0, 0, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(tokenId, 0);
        (,, address token0, address token1, uint24 fee, int24 posLower, int24 posUpper, uint128 liquidity,,,,) =
            INonfungiblePositionManager(NPM).positions(tokenId);

        assertEq(token0, DAI);
        assertEq(token1, WETH);
        assertEq(fee, FEE_030);
        assertGt(liquidity, 0);
        assertTrue(posLower < posUpper);
        assertEq(posLower, lower);
        assertEq(posUpper, upper);
    }

    /// @dev NPM reverts when ticks are not on spacing boundaries — production integrators must align off-chain or via `floorTickToSpacing`.
    function testMintRevertsWhenTicksMisaligned() public {
        address lp = makeAddr("lp");
        vm.deal(lp, 1 ether);
        vm.startPrank(lp);
        IWETH(WETH).deposit{value: 0.5 ether}();
        deal(DAI, lp, 1_000 ether);
        IERC20(WETH).approve(address(example), type(uint256).max);
        IERC20(DAI).approve(address(example), type(uint256).max);

        (int24 tickLower, int24 tickUpper) = _symmetricTickWindow(WETH, DAI, FEE_030, 600);
        tickLower += 1;

        vm.expectRevert();
        example.mintPosition(
            WETH, DAI, FEE_030, tickLower, tickUpper, 0.5 ether, 1_000 ether, 0, 0, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _symmetricTickWindow(address tokenA, address tokenB, uint24 fee, int24 halfWidthTicks)
        internal
        view
        returns (int24 tickLower, int24 tickUpper)
    {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        address pool = IUniswapV3Factory(FACTORY).getPool(token0, token1, fee);
        assertTrue(pool != address(0));
        (, int24 tick,,,,,) = IUniswapV3Pool(pool).slot0();
        int24 spacing = example.feeToTickSpacing(fee);
        assertTrue(halfWidthTicks > 0 && halfWidthTicks % spacing == 0);
        tickLower = example.floorTickToSpacing(tick - halfWidthTicks, spacing);
        tickUpper = example.floorTickToSpacing(tick + halfWidthTicks, spacing);
        assertTrue(tickLower < tickUpper);
    }
}
