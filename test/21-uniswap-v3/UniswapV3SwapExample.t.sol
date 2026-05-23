// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/ERC20.sol";

import {IUniswapV3Factory, IUniswapV3Pool} from "../../src/21-uniswap-v3/interfaces/IUniswapV3.sol";
import {UniswapV3SwapExample} from "../../src/21-uniswap-v3/UniswapV3SwapExample.sol";

interface IWETH {
    function deposit() external payable;
}

contract MockCallbackToken is ERC20 {
    constructor() ERC20("Mock Callback Token", "MCT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MaliciousV3Pool {
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;

    constructor(address token0_, address token1_, uint24 fee_) {
        token0 = token0_;
        token1 = token1_;
        fee = fee_;
    }

    function spoofFlashCallback(address example, address victim, uint256 amount0, uint256 fee0) external {
        UniswapV3SwapExample(example)
            .uniswapV3FlashCallback(fee0, 0, abi.encode(victim, address(this), amount0, uint256(0), address(this)));
    }

    function spoofSwapCallback(address example, address victim, int256 amount0Delta, int256 amount1Delta) external {
        UniswapV3SwapExample(example)
            .uniswapV3SwapCallback(amount0Delta, amount1Delta, abi.encode(victim, address(this), address(this)));
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

    function testFlashCallbackRejectsSpoofedPoolBeforeMovingVictimAllowance() public {
        MockCallbackToken token = new MockCallbackToken();
        MaliciousV3Pool maliciousPool = new MaliciousV3Pool(address(token), WETH, FEE_030);
        address victim = makeAddr("flashCallbackVictim");
        uint256 victimBalance = 100 ether;
        uint256 amount = 10 ether;
        uint256 callbackFee = 1 ether;

        token.mint(victim, victimBalance);
        vm.prank(victim);
        token.approve(address(example), type(uint256).max);
        vm.mockCall(
            FACTORY,
            abi.encodeWithSelector(IUniswapV3Factory.getPool.selector, address(token), WETH, FEE_030),
            abi.encode(makeAddr("canonicalPool"))
        );

        vm.expectRevert(UniswapV3SwapExample.NotPool.selector);
        maliciousPool.spoofFlashCallback(address(example), victim, amount, callbackFee);

        assertEq(token.balanceOf(victim), victimBalance);
        assertEq(token.balanceOf(address(maliciousPool)), 0);
    }

    function testSwapCallbackRejectsSpoofedPoolBeforeMovingVictimAllowance() public {
        MockCallbackToken token = new MockCallbackToken();
        MaliciousV3Pool maliciousPool = new MaliciousV3Pool(address(token), WETH, FEE_030);
        address victim = makeAddr("swapCallbackVictim");
        uint256 victimBalance = 100 ether;
        uint256 amountOwed = 10 ether;

        token.mint(victim, victimBalance);
        vm.prank(victim);
        token.approve(address(example), type(uint256).max);
        vm.mockCall(
            FACTORY,
            abi.encodeWithSelector(IUniswapV3Factory.getPool.selector, address(token), WETH, FEE_030),
            abi.encode(makeAddr("canonicalPool"))
        );

        vm.expectRevert(UniswapV3SwapExample.NotPool.selector);
        maliciousPool.spoofSwapCallback(address(example), victim, int256(amountOwed), 0);

        assertEq(token.balanceOf(victim), victimBalance);
        assertEq(token.balanceOf(address(maliciousPool)), 0);
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
}
