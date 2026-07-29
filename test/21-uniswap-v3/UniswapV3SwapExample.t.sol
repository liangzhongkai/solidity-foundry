// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";

import {ISwapRouter, IUniswapV3Factory, IUniswapV3Pool} from "../../src/21-uniswap-v3/interfaces/IUniswapV3.sol";
import {UniswapV3SwapExample} from "../../src/21-uniswap-v3/UniswapV3SwapExample.sol";
import {ERC20} from "../../src/02-erc20/ERC20.sol";

interface IWETH {
    function deposit() external payable;
}

/// @dev Pulls only a fraction of `amountIn` so leftover refunds can be asserted without a fork.
contract MockPartialPullSwapRouter {
    uint256 public constant OUT_AMOUNT = 42;

    function exactInputSingle(ISwapRouter.ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut)
    {
        uint256 consumed = params.amountIn / 4;
        if (consumed > 0) {
            IERC20(params.tokenIn).transferFrom(msg.sender, address(this), consumed);
        }
        amountOut = OUT_AMOUNT;
    }

    function exactInput(ISwapRouter.ExactInputParams calldata params) external payable returns (uint256 amountOut) {
        address tokenIn = address(bytes20(params.path[0:20]));
        uint256 consumed = params.amountIn / 2;
        if (consumed > 0) {
            IERC20(tokenIn).transferFrom(msg.sender, address(this), consumed);
        }
        amountOut = OUT_AMOUNT;
    }
}

/// @notice Fork tests for single- and multi-hop `SwapRouter` flows.
contract UniswapV3SwapExampleTest is Test {
    /// @dev Match `UniswapV3SwapExample` for `vm.expectEmit`.
    event FlashLoan(
        address indexed pool,
        address indexed initiator,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    );

    event FlashSwap(
        address indexed pool,
        address indexed initiator,
        address indexed recipient,
        int256 amount0Delta,
        int256 amount1Delta
    );
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

    /// @dev Single hop: `tokenIn (20) | fee (3) | tokenOut (20)` => 43 bytes.
    function testEncodePathSingleHopFormat() public view {
        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = DAI;
        uint24[] memory fees = new uint24[](1);
        fees[0] = FEE_030;
        bytes memory path = example.encodePath(tokens, fees);
        assertEq(path.length, 43);
    }

    function testEncodePathRevertsWhenLessThanTwoTokens() public {
        address[] memory tokens = new address[](1);
        tokens[0] = WETH;
        uint24[] memory fees = new uint24[](0);
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

    function testFlashLoanRevertsZeroPool() public {
        vm.expectRevert(UniswapV3SwapExample.ZeroAddress.selector);
        example.flashLoan(address(0), recipient, 1, 0);
    }

    function testFlashLoanRevertsZeroRecipient() public {
        vm.expectRevert(UniswapV3SwapExample.ZeroAddress.selector);
        example.flashLoan(makeAddr("pool"), address(0), 1, 0);
    }

    function testFlashSwapRevertsZeroAmount() public {
        vm.expectRevert(UniswapV3SwapExample.ZeroAmount.selector);
        example.flashSwapExactOutput(makeAddr("pool"), DAI, 0, recipient);
    }

    function testFlashSwapRevertsZeroPool() public {
        vm.expectRevert(UniswapV3SwapExample.ZeroAddress.selector);
        example.flashSwapExactOutput(address(0), DAI, 1, recipient);
    }

    function testFlashSwapRevertsZeroRecipient() public {
        vm.expectRevert(UniswapV3SwapExample.ZeroAddress.selector);
        example.flashSwapExactOutput(makeAddr("pool"), DAI, 1, address(0));
    }

    function _wethDaiPool() internal view returns (address pool) {
        pool = IUniswapV3Factory(FACTORY).getPool(WETH, DAI, FEE_030);
        assertTrue(pool != address(0));
    }

    /// @dev Pool `flash`: receive `token0` (DAI for WETH/DAI 0.3%), repay `amount + fee` in callback (`fee` tier / 1e6, rounded up).
    function testFlashLoanDaiToken0() public {
        _skipIfNoFork();
        address pool = _wethDaiPool();

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

    /// @dev Same pool: `token1` is WETH — flash `amount1` only.
    function testFlashLoanWethToken1() public {
        _skipIfNoFork();
        address pool = _wethDaiPool();

        address user = makeAddr("flashLoanWethUser");
        uint256 borrow = 2 ether;
        uint256 fee = (borrow * uint256(FEE_030) + 1e6 - 1) / 1e6;

        deal(WETH, user, borrow + fee + 1 ether);
        vm.startPrank(user);
        weth.approve(address(example), type(uint256).max);

        uint256 wethBefore = weth.balanceOf(user);
        example.flashLoan(pool, user, 0, borrow);
        assertEq(weth.balanceOf(user), wethBefore - fee);
        vm.stopPrank();
    }

    /// @dev Single `flash` call with both `amount0` and `amount1` non-zero (repay both + fees in callback).
    function testFlashLoanDaiAndWethTogether() public {
        _skipIfNoFork();
        address pool = _wethDaiPool();
        address user = makeAddr("flashBothSides");
        uint256 borrow0 = 200 ether;
        uint256 borrow1 = 1 ether;
        uint256 fee0 = (borrow0 * uint256(FEE_030) + 1e6 - 1) / 1e6;
        uint256 fee1 = (borrow1 * uint256(FEE_030) + 1e6 - 1) / 1e6;

        deal(DAI, user, borrow0 + fee0 + 1 ether);
        deal(WETH, user, borrow1 + fee1 + 1 ether);
        vm.startPrank(user);
        dai.approve(address(example), type(uint256).max);
        weth.approve(address(example), type(uint256).max);

        uint256 daiBefore = dai.balanceOf(user);
        uint256 wethBefore = weth.balanceOf(user);
        example.flashLoan(pool, user, borrow0, borrow1);
        assertEq(daiBefore - dai.balanceOf(user), borrow0 + fee0);
        assertEq(wethBefore - weth.balanceOf(user), borrow1 + fee1);
        vm.stopPrank();
    }

    /// @dev Tokens are sent to `recipient`; initiator still repays principal + fee from their balance.
    function testFlashLoanRecipientDistinctFromInitiator() public {
        _skipIfNoFork();
        address pool = _wethDaiPool();
        address other = makeAddr("flashRecipient");
        address user = makeAddr("flashPayer");
        uint256 borrow = 500 ether;
        uint256 fee = (borrow * uint256(FEE_030) + 1e6 - 1) / 1e6;

        deal(DAI, user, borrow + fee + 1 ether);
        vm.startPrank(user);
        dai.approve(address(example), type(uint256).max);

        uint256 recipientBefore = dai.balanceOf(other);
        uint256 userBefore = dai.balanceOf(user);
        example.flashLoan(pool, other, borrow, 0);
        assertEq(dai.balanceOf(other) - recipientBefore, borrow);
        assertEq(userBefore - dai.balanceOf(user), borrow + fee);
        vm.stopPrank();
    }

    function testFlashLoanRevertsWithoutInitiatorApproval() public {
        _skipIfNoFork();
        address pool = _wethDaiPool();
        address user = makeAddr("noApproveUser");
        uint256 borrow = 100 ether;
        uint256 fee = (borrow * uint256(FEE_030) + 1e6 - 1) / 1e6;
        deal(DAI, user, borrow + fee);
        vm.startPrank(user);
        vm.expectRevert();
        example.flashLoan(pool, user, borrow, 0);
        vm.stopPrank();
    }

    /// @dev Asserts `FlashLoan` payload matches pool fee and initiator.
    function testFlashLoanEmitsFlashLoan() public {
        _skipIfNoFork();
        address pool = _wethDaiPool();
        address user = makeAddr("emitFlashLoanUser");
        uint256 borrow = 200 ether;
        uint256 fee = (borrow * uint256(FEE_030) + 1e6 - 1) / 1e6;
        deal(DAI, user, borrow + fee + 1 ether);
        vm.startPrank(user);
        dai.approve(address(example), type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit FlashLoan(pool, user, user, borrow, 0, fee, 0);
        example.flashLoan(pool, user, borrow, 0);
        vm.stopPrank();
    }

    /// @dev Flash swap (exact output): pool sends DAI (`token0`) to `recipient`; initiator pays WETH (`token1`) in callback.
    function testFlashSwapExactOutputDai() public {
        _skipIfNoFork();
        address pool = _wethDaiPool();

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

    /// @dev Exact output of WETH (`token1`): initiator pays DAI (`token0`) in callback.
    function testFlashSwapExactOutputWeth() public {
        _skipIfNoFork();
        address pool = _wethDaiPool();
        assertEq(IUniswapV3Pool(pool).token0(), DAI);
        assertEq(IUniswapV3Pool(pool).token1(), WETH);

        address user = makeAddr("flashSwapWethUser");
        uint256 wethOut = 1 ether;

        deal(DAI, user, 10_000 ether);
        vm.startPrank(user);
        dai.approve(address(example), type(uint256).max);

        uint256 wethBefore = weth.balanceOf(user);
        uint256 daiBefore = dai.balanceOf(user);

        example.flashSwapExactOutput(pool, WETH, wethOut, user);

        assertEq(weth.balanceOf(user) - wethBefore, wethOut);
        assertLt(dai.balanceOf(user), daiBefore);
        vm.stopPrank();
    }

    /// @dev Output goes to a different address; initiator still funds the owed input.
    function testFlashSwapRecipientDistinctFromInitiator() public {
        _skipIfNoFork();
        address pool = _wethDaiPool();
        address user = makeAddr("flashSwapPayer");
        address other = makeAddr("flashSwapReceiver");
        uint256 daiOut = 100 ether;

        vm.deal(user, 50 ether);
        vm.startPrank(user);
        IWETH(WETH).deposit{value: 20 ether}();
        weth.approve(address(example), type(uint256).max);

        uint256 otherBefore = dai.balanceOf(other);
        example.flashSwapExactOutput(pool, DAI, daiOut, other);
        assertEq(dai.balanceOf(other) - otherBefore, daiOut);
        vm.stopPrank();
    }

    function testFlashSwapRevertsWithoutInitiatorApproval() public {
        _skipIfNoFork();
        address pool = _wethDaiPool();
        address user = makeAddr("flashSwapNoApprove");
        vm.deal(user, 50 ether);
        vm.startPrank(user);
        IWETH(WETH).deposit{value: 10 ether}();
        vm.expectRevert();
        example.flashSwapExactOutput(pool, DAI, 1 ether, user);
        vm.stopPrank();
    }

    function testFlashSwapEmitsFlashSwap() public {
        _skipIfNoFork();
        address pool = _wethDaiPool();
        address user = makeAddr("emitFlashSwapUser");
        uint256 daiOut = 50 ether;

        vm.deal(user, 20 ether);
        vm.startPrank(user);
        IWETH(WETH).deposit{value: 10 ether}();
        weth.approve(address(example), type(uint256).max);

        vm.expectEmit(true, true, true, false);
        emit FlashSwap(pool, user, user, int256(0), int256(0));
        example.flashSwapExactOutput(pool, DAI, daiOut, user);
        vm.stopPrank();
    }

    function testFlashSwapRevertsForUnknownTokenOut() public {
        _skipIfNoFork();
        address pool = _wethDaiPool();
        vm.expectRevert(UniswapV3SwapExample.InvalidToken.selector);
        example.flashSwapExactOutput(pool, makeAddr("nope"), 1, recipient);
    }

    /// @dev Non-zero price limits (or thin liquidity) can leave unconsumed input in the wrapper; refunds must return it.
    function testSwapExactInputSingleRefundsUnusedInput() public {
        address router = example.SWAP_ROUTER();
        vm.etch(router, address(new MockPartialPullSwapRouter()).code);

        ERC20 tokenIn = new ERC20("TokenIn", "IN", 18);
        ERC20 tokenOut = new ERC20("TokenOut", "OUT", 18);
        address trader = makeAddr("partialFillTrader");
        uint256 amountIn = 400 ether;
        deal(address(tokenIn), trader, amountIn);

        vm.startPrank(trader);
        tokenIn.approve(address(example), amountIn);
        uint256 amountOut = example.swapExactInputSingle(
            address(tokenIn),
            address(tokenOut),
            FEE_030,
            amountIn,
            1,
            1, // non-zero limit path in production; mock ignores it and still partial-pulls
            block.timestamp + 1 hours,
            recipient
        );
        vm.stopPrank();

        assertEq(amountOut, MockPartialPullSwapRouter(router).OUT_AMOUNT());
        assertEq(tokenIn.balanceOf(address(example)), 0);
        assertEq(tokenIn.balanceOf(trader), amountIn - (amountIn / 4));
        assertEq(tokenIn.allowance(address(example), router), 0);
    }

    function testSwapExactInputRefundsUnusedInput() public {
        address router = example.SWAP_ROUTER();
        vm.etch(router, address(new MockPartialPullSwapRouter()).code);

        ERC20 tokenIn = new ERC20("TokenIn", "IN", 18);
        address trader = makeAddr("partialFillMultiHopTrader");
        uint256 amountIn = 200 ether;
        deal(address(tokenIn), trader, amountIn);

        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenIn);
        tokens[1] = DAI;
        uint24[] memory fees = new uint24[](1);
        fees[0] = FEE_030;
        bytes memory path = example.encodePath(tokens, fees);

        vm.startPrank(trader);
        tokenIn.approve(address(example), amountIn);
        uint256 amountOut = example.swapExactInput(path, amountIn, 1, block.timestamp + 1 hours, recipient);
        vm.stopPrank();

        assertEq(amountOut, MockPartialPullSwapRouter(router).OUT_AMOUNT());
        assertEq(tokenIn.balanceOf(address(example)), 0);
        assertEq(tokenIn.balanceOf(trader), amountIn / 2);
        assertEq(tokenIn.allowance(address(example), router), 0);
    }
}
