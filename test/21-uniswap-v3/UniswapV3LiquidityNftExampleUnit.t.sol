// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {ERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/ERC721.sol";

import {UniswapV3LiquidityNftExample} from "../../src/21-uniswap-v3/UniswapV3LiquidityNftExample.sol";
import {INonfungiblePositionManager} from "../../src/21-uniswap-v3/interfaces/IUniswapV3.sol";

contract MockV3PositionManager is ERC721, INonfungiblePositionManager {
    uint256 internal nextId;
    mapping(uint256 => uint128) internal liquidities;

    constructor() ERC721("Mock V3 Position", "MV3") {}

    function mintTest(address to, uint128 liquidity) external returns (uint256 tokenId) {
        tokenId = ++nextId;
        liquidities[tokenId] = liquidity;
        _mint(to, tokenId);
    }

    function factory() external pure returns (address) {
        return address(0);
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        tokenId = ++nextId;
        liquidity = 1;
        liquidities[tokenId] = liquidity;
        _mint(params.recipient, tokenId);
        amount0 = params.amount0Desired;
        amount1 = params.amount1Desired;
    }

    function collect(CollectParams calldata) external payable returns (uint256 amount0, uint256 amount1) {
        return (1, 1);
    }

    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        liquidity = 1;
        liquidities[params.tokenId] += liquidity;
        return (liquidity, params.amount0Desired, params.amount1Desired);
    }

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1)
    {
        liquidities[params.tokenId] -= params.liquidity;
        return (1, 1);
    }

    function burn(uint256 tokenId) external payable {
        _burn(tokenId);
        delete liquidities[tokenId];
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
        nonce;
        operator = getApproved(tokenId);
        token0 = address(1);
        token1 = address(2);
        fee = 3000;
        tickLower = -60;
        tickUpper = 60;
        liquidity = liquidities[tokenId];
        feeGrowthInside0LastX128;
        feeGrowthInside1LastX128;
        tokensOwed0;
        tokensOwed1;
    }
}

contract UniswapV3LiquidityNftExampleUnitTest is Test {
    MockV3PositionManager internal npm;
    UniswapV3LiquidityNftExample internal example;

    address internal lp = makeAddr("lp");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        npm = new MockV3PositionManager();
        example = new UniswapV3LiquidityNftExample(address(npm));
    }

    function testApprovedWrapperDoesNotLetArbitraryCallerCollect() public {
        uint256 tokenId = npm.mintTest(lp, 100);
        vm.prank(lp);
        npm.setApprovalForAll(address(example), true);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(UniswapV3LiquidityNftExample.NotPositionController.selector, attacker, tokenId)
        );
        example.collectFees(tokenId, attacker, type(uint128).max, type(uint128).max);
    }

    function testOwnerCanUseApprovedWrapper() public {
        uint256 tokenId = npm.mintTest(lp, 100);
        vm.prank(lp);
        npm.setApprovalForAll(address(example), true);

        vm.prank(lp);
        example.decreaseLiquidityAmount(tokenId, 50, 0, 0, block.timestamp + 1);

        (,,,,,,, uint128 liquidity,,,,) = npm.positions(tokenId);
        assertEq(liquidity, 50);
    }
}
