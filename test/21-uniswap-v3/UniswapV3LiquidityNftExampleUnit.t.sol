// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {ERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/ERC20.sol";

import {UniswapV3LiquidityNftExample} from "../../src/21-uniswap-v3/UniswapV3LiquidityNftExample.sol";
import {INonfungiblePositionManager} from "../../src/21-uniswap-v3/interfaces/IUniswapV3.sol";

contract MockV3ERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockV3PositionManager is INonfungiblePositionManager {
    uint256 internal nextTokenId = 1;
    uint128 internal configuredLiquidity = 1e12;
    uint256 internal configuredAmount0;
    uint256 internal configuredAmount1;

    mapping(uint256 => address) internal owners;
    mapping(address => mapping(address => bool)) internal operatorApprovals;
    mapping(uint256 => Position) internal storedPositions;

    struct Position {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function setMintConsumption(uint256 amount0, uint256 amount1) external {
        configuredAmount0 = amount0;
        configuredAmount1 = amount1;
    }

    function setApprovalForAll(address operator, bool approved) external {
        operatorApprovals[msg.sender][operator] = approved;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = owners[tokenId];
        if (owner == address(0)) revert("ERC721: invalid token ID");
        return owner;
    }

    function factory() external pure returns (address) {
        return address(0);
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        tokenId = nextTokenId++;
        liquidity = configuredLiquidity;
        amount0 = configuredAmount0;
        amount1 = configuredAmount1;

        MockV3ERC20(params.token0).transferFrom(msg.sender, address(this), amount0);
        MockV3ERC20(params.token1).transferFrom(msg.sender, address(this), amount1);

        owners[tokenId] = params.recipient;
        storedPositions[tokenId] = Position({
            token0: params.token0,
            token1: params.token1,
            fee: params.fee,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            liquidity: liquidity,
            tokensOwed0: 0,
            tokensOwed1: 0
        });
    }

    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1) {
        _requireApprovedOrOwner(msg.sender, params.tokenId);
        Position storage position = storedPositions[params.tokenId];
        amount0 = position.tokensOwed0;
        amount1 = position.tokensOwed1;
        position.tokensOwed0 = 0;
        position.tokensOwed1 = 0;
    }

    function increaseLiquidity(IncreaseLiquidityParams calldata)
        external
        payable
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {}

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1)
    {
        _requireApprovedOrOwner(msg.sender, params.tokenId);
        Position storage position = storedPositions[params.tokenId];
        if (params.liquidity > position.liquidity) {
            position.liquidity = 0;
        } else {
            position.liquidity -= params.liquidity;
        }
        amount0 = params.liquidity;
        amount1 = params.liquidity;
        position.tokensOwed0 += uint128(amount0);
        position.tokensOwed1 += uint128(amount1);
    }

    function burn(uint256 tokenId) external payable {
        _requireApprovedOrOwner(msg.sender, tokenId);
        delete owners[tokenId];
        delete storedPositions[tokenId];
    }

    function positions(uint256 tokenId)
        external
        view
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
        Position storage position = storedPositions[tokenId];
        return (
            0,
            address(0),
            position.token0,
            position.token1,
            position.fee,
            position.tickLower,
            position.tickUpper,
            position.liquidity,
            0,
            0,
            position.tokensOwed0,
            position.tokensOwed1
        );
    }

    function _requireApprovedOrOwner(address spender, uint256 tokenId) internal view {
        address owner = owners[tokenId];
        require(owner != address(0), "missing token");
        require(spender == owner || operatorApprovals[owner][spender], "not approved");
    }
}

contract UniswapV3LiquidityNftExampleUnitTest is Test {
    MockV3ERC20 internal tokenA;
    MockV3ERC20 internal tokenB;
    MockV3PositionManager internal positionManager;
    UniswapV3LiquidityNftExample internal example;

    address internal lp = makeAddr("lp");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        tokenA = new MockV3ERC20("Token A", "TKNA");
        tokenB = new MockV3ERC20("Token B", "TKNB");
        positionManager = new MockV3PositionManager();
        example = new UniswapV3LiquidityNftExample(address(positionManager));
    }

    function testMintPositionRefundsUnusedTokenAmounts() public {
        uint256 amountADesired = 10 ether;
        uint256 amountBDesired = 20 ether;
        uint256 amount0Used = 3 ether;
        uint256 amount1Used = 7 ether;
        positionManager.setMintConsumption(amount0Used, amount1Used);

        tokenA.mint(lp, amountADesired);
        tokenB.mint(lp, amountBDesired);

        vm.startPrank(lp);
        tokenA.approve(address(example), amountADesired);
        tokenB.approve(address(example), amountBDesired);
        example.mintPosition(
            address(tokenA),
            address(tokenB),
            3000,
            -60,
            60,
            amountADesired,
            amountBDesired,
            0,
            0,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        uint256 amountAUsed = address(tokenA) < address(tokenB) ? amount0Used : amount1Used;
        uint256 amountBUsed = address(tokenA) < address(tokenB) ? amount1Used : amount0Used;
        assertEq(tokenA.balanceOf(lp), amountADesired - amountAUsed);
        assertEq(tokenB.balanceOf(lp), amountBDesired - amountBUsed);
        assertEq(tokenA.balanceOf(address(example)), 0);
        assertEq(tokenB.balanceOf(address(example)), 0);
    }

    function testUnauthorizedCallerCannotUseHelperApprovalToDecreaseOrCollect() public {
        uint256 tokenId = _mintApprovedPosition();

        vm.startPrank(attacker);
        vm.expectRevert(UniswapV3LiquidityNftExample.UnauthorizedPositionCaller.selector);
        example.decreaseLiquidityAmount(tokenId, 1, 0, 0, block.timestamp + 1 hours);

        vm.expectRevert(UniswapV3LiquidityNftExample.UnauthorizedPositionCaller.selector);
        example.collectFees(tokenId, attacker, type(uint128).max, type(uint128).max);
        vm.stopPrank();
    }

    function testUnauthorizedCallerCannotUseHelperApprovalToBurn() public {
        uint256 tokenId = _mintApprovedPosition();

        vm.prank(attacker);
        vm.expectRevert(UniswapV3LiquidityNftExample.UnauthorizedPositionCaller.selector);
        example.burnPositionFully(tokenId, 0, 0, block.timestamp + 1 hours);
    }

    function _mintApprovedPosition() internal returns (uint256 tokenId) {
        positionManager.setMintConsumption(1 ether, 1 ether);
        tokenA.mint(lp, 5 ether);
        tokenB.mint(lp, 5 ether);

        vm.startPrank(lp);
        tokenA.approve(address(example), type(uint256).max);
        tokenB.approve(address(example), type(uint256).max);
        tokenId = example.mintPosition(
            address(tokenA), address(tokenB), 3000, -60, 60, 5 ether, 5 ether, 0, 0, block.timestamp + 1 hours
        );
        positionManager.setApprovalForAll(address(example), true);
        vm.stopPrank();
    }
}
