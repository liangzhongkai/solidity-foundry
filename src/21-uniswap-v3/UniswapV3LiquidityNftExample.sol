// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

import {INonfungiblePositionManager} from "./interfaces/IUniswapV3.sol";

/// @title UniswapV3LiquidityNftExample
/// @notice Mints a concentrated liquidity position via the canonical NonfungiblePositionManager.
/// @dev Production notes: ticks must align to the fee tier's tick spacing; token0/token1 are sorted by address;
///      narrow ranges improve capital efficiency but increase impermanent loss and maintenance cost.
///      Callers should read `slot0` off-chain or via a lens, then align ticks with `feeToTickSpacing` / `floorTickToSpacing`.
contract UniswapV3LiquidityNftExample {
    using SafeERC20 for IERC20;

    INonfungiblePositionManager public immutable positionManager;

    event PositionMinted(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    error ZeroAddress();
    error UnsupportedFeeTier();

    constructor(address positionManager_) {
        if (positionManager_ == address(0)) revert ZeroAddress();
        positionManager = INonfungiblePositionManager(positionManager_);
    }

    /// @notice Returns tick spacing for standard Uniswap V3 fee tiers on Ethereum mainnet.
    function feeToTickSpacing(uint24 fee) public pure returns (int24 spacing) {
        if (fee == 100) return 1;
        if (fee == 500) return 10;
        if (fee == 3000) return 60;
        if (fee == 10_000) return 200;
        revert UnsupportedFeeTier();
    }

    /// @notice Floors `tick` to a multiple of `spacing` (toward negative infinity).
    /// @dev Integer divide/multiply is intentional tick-space stepping (same pattern as Uniswap V3 tick math demos).
    function floorTickToSpacing(int24 tick, int24 spacing) public pure returns (int24) {
        // slither-disable-next-line divide-before-multiply
        int24 q = tick / spacing;
        int24 r = tick % spacing;
        if (r != 0 && tick < 0) {
            q -= 1;
        }
        return q * spacing;
    }

    /// @notice Mints an NFT position; `tickLower`/`tickUpper` must be valid for the pool's tick spacing.
    function mintPosition(
        address tokenA,
        address tokenB,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external returns (uint256 tokenId) {
        (address token0, address token1, uint256 amount0Desired, uint256 amount1Desired) =
            _resolveTokensAndAmounts(tokenA, tokenB, amountADesired, amountBDesired);

        _pullAndApprove(token0, token1, amount0Desired, amount1Desired);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            recipient: msg.sender,
            deadline: deadline
        });

        uint128 liq;
        uint256 a0;
        uint256 a1;
        // slither-disable-next-line reentrancy-events -- event logs values returned by canonical NPM after mint completes
        (tokenId, liq, a0, a1) = positionManager.mint(params);
        emit PositionMinted(tokenId, liq, a0, a1);
    }

    function _pullAndApprove(address token0, address token1, uint256 amount0Desired, uint256 amount1Desired) internal {
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0Desired);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1Desired);
        IERC20(token0).forceApprove(address(positionManager), amount0Desired);
        IERC20(token1).forceApprove(address(positionManager), amount1Desired);
    }

    function _resolveTokensAndAmounts(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired)
        internal
        pure
        returns (address token0, address token1, uint256 amount0Desired, uint256 amount1Desired)
    {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (amount0Desired, amount1Desired) =
            tokenA == token0 ? (amountADesired, amountBDesired) : (amountBDesired, amountADesired);
    }
}
