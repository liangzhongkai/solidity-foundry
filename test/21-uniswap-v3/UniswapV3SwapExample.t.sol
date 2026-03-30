// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";

import {IUniswapV3Factory} from "../../src/21-uniswap-v3/interfaces/IUniswapV3.sol";
import {UniswapV3SwapExample} from "../../src/21-uniswap-v3/UniswapV3SwapExample.sol";

interface IWETH {
    function deposit() external payable;
}

/// @notice Fork tests for single- and multi-hop `SwapRouter` flows.
contract UniswapV3SwapExampleTest is Test {
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant WBTC_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
    address internal constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    uint24 internal constant FEE_030 = 3000;
    /// @dev WBTC/WETH is often most liquid at 0.05% on mainnet; WETH/DAI commonly 0.3%.
    uint24 internal constant FEE_005 = 500;
    uint256 internal constant SWAP_IN = 1 ether;
    uint256 internal constant WBTC_IN = 100_000_000;

    UniswapV3SwapExample internal example;
    IERC20 internal weth;
    IERC20 internal dai;
    IERC20 internal wbtc;
    address internal recipient;

    function setUp() public {
        example = new UniswapV3SwapExample();
        weth = IERC20(WETH);
        dai = IERC20(DAI);
        wbtc = IERC20(WBTC);
        recipient = makeAddr("recipient");
    }

    function _skipIfNoFork() internal {
        if (example.SWAP_ROUTER().code.length == 0 || WETH.code.length == 0) {
            vm.skip(true);
        }
    }

    /// @dev Path layout: 20 + 3 + 20 + 3 + 20 bytes for two hops.
    function testEncodePathTwoHopFormat() public view {
        address[] memory tokens = new address[](3);
        tokens[0] = WBTC;
        tokens[1] = WETH;
        tokens[2] = DAI;
        uint24[] memory fees = new uint24[](2);
        fees[0] = FEE_005;
        fees[1] = FEE_030;
        bytes memory path = example.encodePath(tokens, fees);
        assertEq(path.length, 66);
    }

    function testEncodePathRevertsWhenFeesLengthMismatch() public {
        address[] memory tokens = new address[](3);
        tokens[0] = WBTC;
        tokens[1] = WETH;
        tokens[2] = DAI;
        uint24[] memory fees = new uint24[](1);
        fees[0] = FEE_030;
        vm.expectRevert(UniswapV3SwapExample.InvalidPath.selector);
        example.encodePath(tokens, fees);
    }

    /// @dev Production pattern: combine an off-chain quote with `amountOutMinimum`; here we only assert the swap succeeds with a loose floor.
    function testSwapExactInputSingleWethToDai() public {
        _skipIfNoFork();
        address trader = makeAddr("trader");
        vm.deal(trader, 2 ether);
        vm.startPrank(trader);
        IWETH(WETH).deposit{value: SWAP_IN}();
        weth.approve(address(example), SWAP_IN);

        uint256 beforeOut = dai.balanceOf(recipient);
        uint256 amountOut =
            example.swapExactInputSingle(WETH, DAI, FEE_030, SWAP_IN, 1, 0, block.timestamp + 1 hours, recipient);
        vm.stopPrank();

        assertGt(amountOut, 0);
        assertEq(dai.balanceOf(recipient) - beforeOut, amountOut);
    }

    /// @dev Two-hop WBTC -> WETH -> DAI (0.3% pools); path must match deployed pool fees on each leg.
    function testSwapExactInputTwoHopWbtcToDai() public {
        _skipIfNoFork();
        vm.deal(WBTC_WHALE, 1 ether);
        vm.startPrank(WBTC_WHALE);
        wbtc.approve(address(example), WBTC_IN);

        address[] memory tokens = new address[](3);
        tokens[0] = WBTC;
        tokens[1] = WETH;
        tokens[2] = DAI;
        uint24[] memory fees = new uint24[](2);
        fees[0] = FEE_005;
        fees[1] = FEE_030;
        bytes memory path = example.encodePath(tokens, fees);

        uint256 beforeOut = dai.balanceOf(recipient);
        uint256 amountOut = example.swapExactInput(path, WBTC_IN, 1, block.timestamp + 1 hours, recipient);
        vm.stopPrank();

        assertGt(amountOut, 0);
        assertEq(dai.balanceOf(recipient) - beforeOut, amountOut);
    }

    function testSwapExactInputRevertsForZeroRecipient() public {
        vm.expectRevert(UniswapV3SwapExample.ZeroAddress.selector);
        example.swapExactInput(hex"00", 1, 1, block.timestamp + 1, address(0));
    }

    function testSwapExactInputRevertsForShortPath() public {
        vm.expectRevert(UniswapV3SwapExample.InvalidPath.selector);
        example.swapExactInput(hex"00", 1, 1, block.timestamp + 1, recipient);
    }

    function testSwapRevertsForZeroRecipient() public {
        vm.expectRevert(UniswapV3SwapExample.ZeroAddress.selector);
        example.swapExactInputSingle(WETH, DAI, FEE_030, 1, 1, 0, block.timestamp + 1, address(0));
    }

    /// @dev Wrong fee tier => no pool => router reverts (teaches validating the pool exists before swapping).
    function testSwapRevertsForMismatchedFeeTier() public {
        _skipIfNoFork();
        address trader = makeAddr("trader");
        vm.deal(trader, 1 ether);
        vm.startPrank(trader);
        IWETH(WETH).deposit{value: 0.1 ether}();
        weth.approve(address(example), 0.1 ether);

        uint24 nonexistentFee = 1337;
        vm.expectRevert();
        example.swapExactInputSingle(WETH, DAI, nonexistentFee, 0.1 ether, 1, 0, block.timestamp + 1 hours, recipient);
        vm.stopPrank();
    }

    function testFlashLoanRevertsWhenBothAmountsZero() public {
        vm.expectRevert(UniswapV3SwapExample.ZeroAmount.selector);
        example.flashLoan(makeAddr("pool"), recipient, 0, 0);
    }

    /// @dev Pool `flash`: receive `token0` (DAI for WETH/DAI 0.3%), repay `amount + fee` in callback (`fee` tier / 1e6, rounded up).
    function testFlashLoanDaiToken0() public {
        _skipIfNoFork();
        address pool = IUniswapV3Factory(FACTORY).getPool(WETH, DAI, FEE_030);
        assertTrue(pool != address(0));

        address user = makeAddr("flashLoanUser");
        uint256 borrow = 1_000 ether;
        uint256 fee = (borrow * uint256(FEE_030) + 1e6 - 1) / 1e6;

        deal(DAI, user, borrow + fee + 1 ether);
        vm.startPrank(user);
        dai.approve(address(example), type(uint256).max);

        uint256 daiBefore = dai.balanceOf(user);
        example.flashLoan(pool, user, borrow, 0);
        assertEq(dai.balanceOf(user), daiBefore - fee);
        vm.stopPrank();
    }

    /// @dev Flash swap (exact output): pool sends DAI to `recipient`; initiator pays WETH (token1) via swap callback.
    function testFlashSwapExactOutputDai() public {
        _skipIfNoFork();
        address pool = IUniswapV3Factory(FACTORY).getPool(WETH, DAI, FEE_030);
        assertTrue(pool != address(0));

        address user = makeAddr("flashSwapUser");
        uint256 daiOut = 1_000 ether;

        vm.deal(user, 200 ether);
        vm.startPrank(user);
        IWETH(WETH).deposit{value: 100 ether}();
        weth.approve(address(example), type(uint256).max);

        uint256 daiBefore = dai.balanceOf(user);
        uint256 wethBefore = weth.balanceOf(user);

        example.flashSwapExactOutput(pool, DAI, daiOut, user);

        assertEq(dai.balanceOf(user) - daiBefore, daiOut);
        assertLt(weth.balanceOf(user), wethBefore);
        vm.stopPrank();
    }

    function testFlashSwapRevertsForUnknownTokenOut() public {
        _skipIfNoFork();
        address pool = IUniswapV3Factory(FACTORY).getPool(WETH, DAI, FEE_030);
        assertTrue(pool != address(0));
        vm.expectRevert(UniswapV3SwapExample.InvalidToken.selector);
        example.flashSwapExactOutput(pool, makeAddr("nope"), 1, recipient);
    }
}
