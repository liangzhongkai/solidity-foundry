// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/IERC721.sol";

import {INonfungiblePositionManager} from "./interfaces/IUniswapV3.sol";

/// @title UniswapV3LiquidityNftExample
/// @notice Wraps NPM `mint`, `decreaseLiquidity`, `collect`, and `burn` for teaching.
/// @dev `collect`, `decreaseLiquidity`, and `burn` are executed by this contract calling NPM, so the position owner
///      must `setApprovalForAll(address(this), true)` or `approve(address(this), tokenId)` on the NPM ERC721 first.
///      Ticks must align to fee-tier spacing; narrow ranges increase IL and operational overhead.
contract UniswapV3LiquidityNftExample {
    using SafeERC20 for IERC20;

    INonfungiblePositionManager public immutable positionManager;

    event PositionMinted(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event LiquidityDecreased(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event FeesCollected(uint256 indexed tokenId, address indexed recipient, uint256 amount0, uint256 amount1);
    event PositionBurned(uint256 indexed tokenId);

    error ZeroAddress();
    error UnsupportedFeeTier();
    error NotPositionOwnerOrApproved();

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

    /// @notice Removes `liquidity` from an existing position; principal becomes claimable via `collect` (and appears as `tokensOwed`).
    function decreaseLiquidityAmount(
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1) {
        _requirePositionOwnerOrApproved(tokenId);

        INonfungiblePositionManager.DecreaseLiquidityParams memory params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: deadline
            });

        // slither-disable-next-line reentrancy-events -- event reflects NPM return values after state update
        (amount0, amount1) = positionManager.decreaseLiquidity(params);
        emit LiquidityDecreased(tokenId, liquidity, amount0, amount1);
    }

    /// @notice Collects owed tokens (fees and post-decrease principal) to `recipient`.
    function collectFees(uint256 tokenId, address recipient, uint128 amount0Max, uint128 amount1Max)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        if (recipient == address(0)) revert ZeroAddress();
        _requirePositionOwnerOrApproved(tokenId);

        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId, recipient: recipient, amount0Max: amount0Max, amount1Max: amount1Max
        });

        // slither-disable-next-line reentrancy-events -- event reflects NPM return values after transfer
        (amount0, amount1) = positionManager.collect(params);
        emit FeesCollected(tokenId, recipient, amount0, amount1);
    }

    /// @notice Removes all liquidity, collects proceeds to `msg.sender`, then burns the NFT (must be empty afterward).
    function burnPositionFully(
        uint256 tokenId,
        uint256 amount0MinDecrease,
        uint256 amount1MinDecrease,
        uint256 deadline
    ) external {
        _requirePositionOwnerOrApproved(tokenId);

        // slither-disable-next-line unused-return -- only `liquidity` is needed for the burn sequence
        (,,,,,,, uint128 liq,,,,) = positionManager.positions(tokenId);
        if (liq > 0) {
            INonfungiblePositionManager.DecreaseLiquidityParams memory d =
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liq,
                    amount0Min: amount0MinDecrease,
                    amount1Min: amount1MinDecrease,
                    deadline: deadline
                });
            // slither-disable-next-line reentrancy-events -- burn flow; events follow NPM ordering
            (uint256 dec0, uint256 dec1) = positionManager.decreaseLiquidity(d);
            emit LiquidityDecreased(tokenId, liq, dec0, dec1);
        }

        (uint256 c0, uint256 c1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId, recipient: msg.sender, amount0Max: type(uint128).max, amount1Max: type(uint128).max
            })
        );
        emit FeesCollected(tokenId, msg.sender, c0, c1);

        positionManager.burn(tokenId);
        emit PositionBurned(tokenId);
    }

    function _pullAndApprove(address token0, address token1, uint256 amount0Desired, uint256 amount1Desired) internal {
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0Desired);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1Desired);
        IERC20(token0).forceApprove(address(positionManager), amount0Desired);
        IERC20(token1).forceApprove(address(positionManager), amount1Desired);
    }

    function _requirePositionOwnerOrApproved(uint256 tokenId) internal view {
        IERC721 nft = IERC721(address(positionManager));
        address owner = nft.ownerOf(tokenId);
        if (msg.sender == owner || nft.getApproved(tokenId) == msg.sender || nft.isApprovedForAll(owner, msg.sender)) {
            return;
        }
        revert NotPositionOwnerOrApproved();
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
