// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/IERC721.sol";

import {UniswapV3LiquidityNftExample} from "../../src/21-uniswap-v3/UniswapV3LiquidityNftExample.sol";
import {
    IUniswapV3Factory,
    IUniswapV3Pool,
    INonfungiblePositionManager
} from "../../src/21-uniswap-v3/interfaces/IUniswapV3.sol";

interface IWETH {
    function deposit() external payable;
}

contract MockV3PositionManager {
    mapping(uint256 tokenId => address owner) internal owners;
    mapping(uint256 tokenId => address operator) internal approvals;
    mapping(address owner => mapping(address operator => bool approved)) internal operatorApprovals;

    address public lastCollectRecipient;

    function setOwner(uint256 tokenId, address owner) external {
        owners[tokenId] = owner;
    }

    function setApproved(uint256 tokenId, address operator) external {
        approvals[tokenId] = operator;
    }

    function setApprovedForAll(address owner, address operator, bool approved) external {
        operatorApprovals[owner][operator] = approved;
    }

    function mint(INonfungiblePositionManager.MintParams calldata)
        external
        pure
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        return (1, 1, 0, 0);
    }

    function collect(INonfungiblePositionManager.CollectParams calldata params)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        lastCollectRecipient = params.recipient;
        return (1, 1);
    }

    function increaseLiquidity(INonfungiblePositionManager.IncreaseLiquidityParams calldata)
        external
        pure
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        return (1, 0, 0);
    }

    function decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams calldata)
        external
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        return (1, 1);
    }

    function burn(uint256 tokenId) external {
        delete owners[tokenId];
    }

    function ownerOf(uint256 tokenId) external view returns (address owner) {
        owner = owners[tokenId];
        require(owner != address(0), "owner query for nonexistent token");
    }

    function getApproved(uint256 tokenId) external view returns (address operator) {
        return approvals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return operatorApprovals[owner][operator];
    }

    function positions(uint256)
        external
        pure
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        return (0, address(0), address(0), address(0), 0, 0, 0, 1, 0, 0, 0, 0);
    }
}

/// @notice Tick math (no fork) plus fork flows for mint / decrease / collect / burn.
contract UniswapV3LiquidityNftExampleTest is Test {
    address internal constant NPM = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address internal constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    uint24 internal constant FEE_030 = 3000;

    UniswapV3LiquidityNftExample internal example;

    function setUp() public {
        example = new UniswapV3LiquidityNftExample(NPM);
    }

    function _skipIfNoNpm() internal {
        if (NPM.code.length == 0) vm.skip(true);
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

    function testCollectFeesRejectsUnauthorizedCallerEvenWhenWrapperApproved() public {
        MockV3PositionManager mockNpm = new MockV3PositionManager();
        UniswapV3LiquidityNftExample localExample = new UniswapV3LiquidityNftExample(address(mockNpm));
        uint256 tokenId = 1;
        address lp = makeAddr("lp");
        address attacker = makeAddr("attacker");

        mockNpm.setOwner(tokenId, lp);
        mockNpm.setApprovedForAll(lp, address(localExample), true);

        vm.prank(attacker);
        vm.expectRevert(UniswapV3LiquidityNftExample.NotPositionOwnerOrApproved.selector);
        localExample.collectFees(tokenId, attacker, type(uint128).max, type(uint128).max);
    }

    function testApprovedPositionControllerCanCollectFees() public {
        MockV3PositionManager mockNpm = new MockV3PositionManager();
        UniswapV3LiquidityNftExample localExample = new UniswapV3LiquidityNftExample(address(mockNpm));
        uint256 tokenId = 1;
        address lp = makeAddr("lp");
        address controller = makeAddr("controller");

        mockNpm.setOwner(tokenId, lp);
        mockNpm.setApproved(tokenId, controller);

        vm.prank(controller);
        localExample.collectFees(tokenId, lp, type(uint128).max, type(uint128).max);

        assertEq(mockNpm.lastCollectRecipient(), lp);
    }

    /// @dev Mint sends the NFT to `msg.sender`; asymmetric deposits are normal when price sits inside the range.
    function testMintPositionCreatesNft() public {
        _skipIfNoNpm();
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
        _skipIfNoNpm();
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

    /// @dev `decreaseLiquidity` moves principal to `tokensOwed`; `collect` delivers tokens to the recipient (needs NPM approval on this helper).
    function testDecreaseHalfThenCollect() public {
        _skipIfNoNpm();
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

        (,,,,,,, uint128 liq,,,,) = INonfungiblePositionManager(NPM).positions(tokenId);
        assertGt(liq, 1);

        IERC721(NPM).setApprovalForAll(address(example), true);

        uint256 daiBefore = IERC20(DAI).balanceOf(lp);
        uint256 wethBefore = IERC20(WETH).balanceOf(lp);

        uint128 half = liq / 2;
        example.decreaseLiquidityAmount(tokenId, half, 0, 0, block.timestamp + 1 hours);
        example.collectFees(tokenId, lp, type(uint128).max, type(uint128).max);

        assertTrue(IERC20(DAI).balanceOf(lp) + IERC20(WETH).balanceOf(lp) > daiBefore + wethBefore);

        (,,,,,,, uint128 liqAfter,,,,) = INonfungiblePositionManager(NPM).positions(tokenId);
        assertEq(liqAfter, liq - half);
        vm.stopPrank();
    }

    /// @dev Full exit: decrease all, collect to LP, burn NFT — requires NPM approval for the helper contract.
    function testBurnPositionFullyDestroysPosition() public {
        _skipIfNoNpm();
        address lp = makeAddr("lp");
        vm.deal(lp, 5 ether);
        vm.startPrank(lp);
        IWETH(WETH).deposit{value: 1 ether}();
        deal(DAI, lp, 2_000 ether);
        IERC20(WETH).approve(address(example), 1 ether);
        IERC20(DAI).approve(address(example), 2_000 ether);

        (int24 lower, int24 upper) = _symmetricTickWindow(WETH, DAI, FEE_030, 600);
        uint256 tokenId = example.mintPosition(
            WETH, DAI, FEE_030, lower, upper, 1 ether, 2_000 ether, 0, 0, block.timestamp + 1 hours
        );

        IERC721(NPM).setApprovalForAll(address(example), true);
        example.burnPositionFully(tokenId, 0, 0, block.timestamp + 1 hours);
        vm.stopPrank();

        vm.expectRevert();
        IERC721(NPM).ownerOf(tokenId);
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
