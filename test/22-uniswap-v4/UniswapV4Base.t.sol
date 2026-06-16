// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/IERC721.sol";

import {UniswapV4PoolManagerExample} from "../../src/22-uniswap-v4/UniswapV4PoolManagerExample.sol";
import {UniswapV4PositionManagerExample} from "../../src/22-uniswap-v4/UniswapV4PositionManagerExample.sol";
import {UniswapV4StateViewExample} from "../../src/22-uniswap-v4/UniswapV4StateViewExample.sol";
import {UniswapV4UniversalRouterExample} from "../../src/22-uniswap-v4/UniswapV4UniversalRouterExample.sol";
import {Currency, IHooks, ModifyLiquidityParams, PoolKey} from "../../src/22-uniswap-v4/interfaces/IUniswapV4.sol";

abstract contract UniswapV4Base is Test {
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address internal constant POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address internal constant POSITION_MANAGER = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    address internal constant UNIVERSAL_ROUTER = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
    address internal constant STATE_VIEW = 0x7fFE42C4a5DEeA5b0feC41C94C136Cf115597227;
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    uint160 internal constant SQRT_PRICE_1_1 = 79_228_162_514_264_337_593_543_950_336;
    int24 internal constant TICK_SPACING = 60;
    int24 internal constant TICK_LOWER = -120;
    int24 internal constant TICK_UPPER = 120;
    uint24 internal constant FEE = 4242;

    uint256 internal constant CORE_LIQUIDITY = 1e15;
    uint256 internal constant POSITION_LIQUIDITY = 5e14;
    uint128 internal constant MAX_DAI = 500 ether;
    uint128 internal constant MAX_WETH = 500 ether;

    UniswapV4StateViewExample internal stateExample;
    UniswapV4PoolManagerExample internal poolManagerExample;
    UniswapV4UniversalRouterExample internal routerExample;
    UniswapV4PositionManagerExample internal positionExample;

    function setUp() public virtual {
        stateExample = new UniswapV4StateViewExample(STATE_VIEW, POSITION_MANAGER);
        poolManagerExample = new UniswapV4PoolManagerExample(POOL_MANAGER);
        routerExample = new UniswapV4UniversalRouterExample(UNIVERSAL_ROUTER, PERMIT2);
        positionExample = new UniswapV4PositionManagerExample(POSITION_MANAGER, PERMIT2);
    }

    function _skipIfNoFork() internal {
        if (
            POOL_MANAGER.code.length == 0 || POSITION_MANAGER.code.length == 0 || UNIVERSAL_ROUTER.code.length == 0
                || STATE_VIEW.code.length == 0 || PERMIT2.code.length == 0 || DAI.code.length == 0
                || WETH.code.length == 0
        ) {
            vm.skip(true);
        }
    }

    function _poolKey() internal pure returns (PoolKey memory key) {
        key = PoolKey({
            currency0: Currency.wrap(DAI),
            currency1: Currency.wrap(WETH),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0))
        });
    }

    function _initializePool() internal returns (PoolKey memory key) {
        _skipIfNoFork();
        key = _poolKey();
        poolManagerExample.initializePool(key, SQRT_PRICE_1_1);
    }

    function _seedCorePool() internal returns (PoolKey memory key, address liquidityProvider) {
        key = _initializePool();
        liquidityProvider = makeAddr("core-liquidity-provider");

        deal(DAI, liquidityProvider, uint256(MAX_DAI));
        deal(WETH, liquidityProvider, uint256(MAX_WETH));

        vm.startPrank(liquidityProvider);
        IERC20(DAI).approve(address(poolManagerExample), type(uint256).max);
        IERC20(WETH).approve(address(poolManagerExample), type(uint256).max);
        poolManagerExample.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: int256(CORE_LIQUIDITY), salt: bytes32(0)
            }),
            bytes(""),
            liquidityProvider
        );
        vm.stopPrank();
    }

    function _mintPositionToWrapper() internal returns (PoolKey memory key, uint256 tokenId, address funder) {
        key = _initializePool();
        funder = makeAddr("position-funder");

        deal(DAI, funder, uint256(MAX_DAI));
        deal(WETH, funder, uint256(MAX_WETH));

        vm.startPrank(funder);
        IERC20(DAI).approve(address(positionExample), type(uint256).max);
        IERC20(WETH).approve(address(positionExample), type(uint256).max);
        tokenId = positionExample.mintPosition(
            key,
            TICK_LOWER,
            TICK_UPPER,
            POSITION_LIQUIDITY,
            MAX_DAI,
            MAX_WETH,
            block.timestamp + 1 hours,
            funder,
            bytes("")
        );
        IERC721(POSITION_MANAGER).setApprovalForAll(address(positionExample), true);
        vm.stopPrank();
    }
}
