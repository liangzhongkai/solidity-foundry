// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";

import {UniswapV2OptimalZap} from "../../src/20-uniswap-v2/UniswapV2OptimalZap.sol";

contract UniswapV2OptimalZapTest is Test {
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant DAI_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    uint256 internal constant AMOUNT_IN = 1_000 ether;

    IERC20 internal dai;
    IERC20 internal weth;

    function setUp() public {
        dai = IERC20(DAI);
        weth = IERC20(WETH);

        if (address(weth).code.length == 0 || DAI.code.length == 0) {
            vm.skip(true);
        }

        vm.deal(DAI_WHALE, 1 ether);
    }

    function testZapRevertsWhenPairDoesNotIncludeWeth() public {
        UniswapV2OptimalZap zapper = new UniswapV2OptimalZap();

        vm.expectRevert(UniswapV2OptimalZap.WethPairRequired.selector);
        zapper.zap(DAI, USDC, AMOUNT_IN);
    }

    function testOptimalZapMintsMoreLpThanSubOptimalZap() public {
        uint256 snapshotId = vm.snapshotState();
        (uint256 optimalLp,,) = _runZap(true);

        assertTrue(vm.revertToState(snapshotId));

        (uint256 subOptimalLp,,) = _runZap(false);

        assertGt(optimalLp, 0);
        assertGt(subOptimalLp, 0);
        assertGt(optimalLp, subOptimalLp);
    }

    function testZapSupportsReserveSelectionWhenTokenAIsWeth() public {
        UniswapV2OptimalZap zapper = new UniswapV2OptimalZap();
        address wethProvider = makeAddr("wethProvider");

        vm.deal(wethProvider, 1 ether);
        vm.prank(wethProvider);
        IWETH(address(weth)).deposit{value: 1 ether}();

        vm.prank(wethProvider);
        weth.approve(address(zapper), 1 ether);

        vm.prank(wethProvider);
        uint256 liquidity = zapper.zap(address(weth), DAI, 1 ether);

        address pair = zapper.getPair(address(weth), DAI);
        assertGt(liquidity, 0);
        assertEq(IERC20(pair).balanceOf(address(zapper)), liquidity);
    }

    function _runZap(bool useOptimal) internal returns (uint256 lp, uint256 daiLeft, uint256 wethLeft) {
        UniswapV2OptimalZap zapper = new UniswapV2OptimalZap();
        address pair = zapper.getPair(DAI, address(weth));

        vm.startPrank(DAI_WHALE);
        dai.approve(address(zapper), AMOUNT_IN);
        if (useOptimal) {
            zapper.zap(DAI, address(weth), AMOUNT_IN);
        } else {
            zapper.subOptimalZap(DAI, address(weth), AMOUNT_IN);
        }
        vm.stopPrank();

        lp = IERC20(pair).balanceOf(address(zapper));
        daiLeft = dai.balanceOf(address(zapper));
        wethLeft = weth.balanceOf(address(zapper));
    }
}

interface IWETH {
    function deposit() external payable;
}
