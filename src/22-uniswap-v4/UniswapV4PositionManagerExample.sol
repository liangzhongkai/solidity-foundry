// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/IERC721.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

import {
    Currency,
    CurrencyLibrary,
    IPermit2,
    IPositionManager,
    PoolId,
    PoolIdLibrary,
    PoolKey,
    PositionInfo
} from "./interfaces/IUniswapV4.sol";

/// @title UniswapV4PositionManagerExample
/// @notice Shows how to encode and execute the PositionManager's command-based liquidity actions.
/// @dev This wrapper is intentionally custodial for the duration of a call: it pulls ERC20s into itself, forwards Permit2 approvals, and executes PosM actions.
contract UniswapV4PositionManagerExample {
    using SafeERC20 for IERC20;
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    uint8 internal constant ACTION_INCREASE_LIQUIDITY = 0x00;
    uint8 internal constant ACTION_DECREASE_LIQUIDITY = 0x01;
    uint8 internal constant ACTION_MINT_POSITION = 0x02;
    uint8 internal constant ACTION_BURN_POSITION = 0x03;
    uint8 internal constant ACTION_SETTLE_PAIR = 0x0d;
    uint8 internal constant ACTION_TAKE_PAIR = 0x11;

    struct MintPositionParams {
        int24 tickLower;
        int24 tickUpper;
        uint256 liquidity;
        uint128 amount0Max;
        uint128 amount1Max;
        uint256 deadline;
        address recipient;
        bytes hookData;
    }

    IPositionManager public immutable positionManager;
    IPermit2 public immutable permit2;

    mapping(uint256 tokenId => address owner) public custodialPositionOwner;

    event Permit2Approval(address indexed token, uint160 amount, uint48 expiration);
    event PositionMinted(uint256 indexed tokenId, address indexed recipient, PoolId indexed poolId);
    event LiquidityIncreased(uint256 indexed tokenId, uint256 liquidity);
    event LiquidityDecreased(uint256 indexed tokenId, uint256 liquidity, address indexed recipient);
    event FeesCollected(uint256 indexed tokenId, address indexed recipient);
    event PositionBurned(uint256 indexed tokenId, address indexed recipient);

    error ZeroAddress();
    error InvalidAmount();
    error InvalidRecipient();
    error NativeCurrencyNotSupported();
    error UnauthorizedPositionCaller(uint256 tokenId, address caller);

    constructor(address positionManager_, address permit2_) {
        if (positionManager_ == address(0) || permit2_ == address(0)) revert ZeroAddress();
        positionManager = IPositionManager(positionManager_);
        permit2 = IPermit2(permit2_);
    }

    /// @notice Approves the PositionManager via Permit2 using this contract's token balance.
    function approveTokenWithPermit2(address token, uint160 amount, uint48 expiration) public {
        IERC20(token).forceApprove(address(permit2), type(uint256).max);
        permit2.approve(token, address(positionManager), amount, expiration);
        emit Permit2Approval(token, amount, expiration);
    }

    function nextTokenId() external view returns (uint256) {
        return positionManager.nextTokenId();
    }

    function getPositionLiquidity(uint256 tokenId) external view returns (uint128 liquidity) {
        liquidity = positionManager.getPositionLiquidity(tokenId);
    }

    function getPoolAndPositionInfo(uint256 tokenId) external view returns (PoolKey memory key, PositionInfo info) {
        return positionManager.getPoolAndPositionInfo(tokenId);
    }

    function encodeMintPositionUnlockData(
        PoolKey memory key,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint128 amount0Max,
        uint128 amount1Max,
        address recipient,
        bytes memory hookData
    ) public pure returns (bytes memory unlockData) {
        bytes memory actions = abi.encodePacked(bytes1(ACTION_MINT_POSITION), bytes1(ACTION_SETTLE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(key, tickLower, tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData);
        params[1] = abi.encode(key.currency0, key.currency1);
        unlockData = abi.encode(actions, params);
    }

    function encodeIncreaseLiquidityUnlockData(
        PoolKey memory key,
        uint256 tokenId,
        uint256 liquidity,
        uint128 amount0Max,
        uint128 amount1Max,
        bytes memory hookData
    ) public pure returns (bytes memory unlockData) {
        bytes memory actions = abi.encodePacked(bytes1(ACTION_INCREASE_LIQUIDITY), bytes1(ACTION_SETTLE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(tokenId, liquidity, amount0Max, amount1Max, hookData);
        params[1] = abi.encode(key.currency0, key.currency1);
        unlockData = abi.encode(actions, params);
    }

    function encodeDecreaseLiquidityUnlockData(
        PoolKey memory key,
        uint256 tokenId,
        uint256 liquidity,
        uint128 amount0Min,
        uint128 amount1Min,
        address recipient,
        bytes memory hookData
    ) public pure returns (bytes memory unlockData) {
        bytes memory actions = abi.encodePacked(bytes1(ACTION_DECREASE_LIQUIDITY), bytes1(ACTION_TAKE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(tokenId, liquidity, amount0Min, amount1Min, hookData);
        params[1] = abi.encode(key.currency0, key.currency1, recipient);
        unlockData = abi.encode(actions, params);
    }

    function encodeBurnPositionUnlockData(
        PoolKey memory key,
        uint256 tokenId,
        uint128 amount0Min,
        uint128 amount1Min,
        address recipient,
        bytes memory hookData
    ) public pure returns (bytes memory unlockData) {
        bytes memory actions = abi.encodePacked(bytes1(ACTION_BURN_POSITION), bytes1(ACTION_TAKE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(tokenId, amount0Min, amount1Min, hookData);
        params[1] = abi.encode(key.currency0, key.currency1, recipient);
        unlockData = abi.encode(actions, params);
    }

    /// @notice Mints a new v4 LP NFT. `recipient` receives the NFT, but any unused token buffers are refunded to the caller.
    function mintPosition(
        PoolKey calldata key,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint128 amount0Max,
        uint128 amount1Max,
        uint256 deadline,
        address recipient,
        bytes calldata hookData
    ) external returns (uint256 tokenId) {
        MintPositionParams memory params = MintPositionParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            amount0Max: amount0Max,
            amount1Max: amount1Max,
            deadline: deadline,
            recipient: recipient,
            hookData: hookData
        });
        tokenId = _mintPosition(key, params);
    }

    /// @notice Increases liquidity for an existing NFT position.
    function increaseLiquidity(
        uint256 tokenId,
        uint256 liquidity,
        uint128 amount0Max,
        uint128 amount1Max,
        uint256 deadline,
        bytes calldata hookData
    ) external {
        if (liquidity == 0) revert InvalidAmount();
        (PoolKey memory key,) = positionManager.getPoolAndPositionInfo(tokenId);

        (address token0, address token1) = _pullPair(key, amount0Max, amount1Max);
        _approvePair(token0, token1, amount0Max, amount1Max, deadline);

        uint256 startBalance0 = IERC20(token0).balanceOf(address(this)) - amount0Max;
        uint256 startBalance1 = IERC20(token1).balanceOf(address(this)) - amount1Max;
        positionManager.modifyLiquidities(
            encodeIncreaseLiquidityUnlockData(key, tokenId, liquidity, amount0Max, amount1Max, hookData), deadline
        );
        _refundTokenDelta(token0, msg.sender, startBalance0);
        _refundTokenDelta(token1, msg.sender, startBalance1);

        emit LiquidityIncreased(tokenId, liquidity);
    }

    /// @notice Decreases liquidity and transfers the withdrawn tokens to `recipient`.
    function decreaseLiquidity(
        uint256 tokenId,
        uint256 liquidity,
        uint128 amount0Min,
        uint128 amount1Min,
        uint256 deadline,
        address recipient,
        bytes calldata hookData
    ) public {
        if (recipient == address(0)) revert InvalidRecipient();
        _requirePositionCaller(tokenId);
        (PoolKey memory key,) = positionManager.getPoolAndPositionInfo(tokenId);
        positionManager.modifyLiquidities(
            encodeDecreaseLiquidityUnlockData(key, tokenId, liquidity, amount0Min, amount1Min, recipient, hookData),
            deadline
        );

        emit LiquidityDecreased(tokenId, liquidity, recipient);
    }

    /// @notice Claims currently accrued fees using the `DECREASE_LIQUIDITY` + `TAKE_PAIR` zero-liquidity pattern.
    function collectFees(uint256 tokenId, uint256 deadline, address recipient, bytes calldata hookData) external {
        decreaseLiquidity(tokenId, 0, 0, 0, deadline, recipient, hookData);
        emit FeesCollected(tokenId, recipient);
    }

    /// @notice Fully burns a position and transfers the withdrawn assets to `recipient`.
    function burnPosition(
        uint256 tokenId,
        uint128 amount0Min,
        uint128 amount1Min,
        uint256 deadline,
        address recipient,
        bytes calldata hookData
    ) external {
        if (recipient == address(0)) revert InvalidRecipient();
        _requirePositionCaller(tokenId);
        (PoolKey memory key,) = positionManager.getPoolAndPositionInfo(tokenId);
        positionManager.modifyLiquidities(
            encodeBurnPositionUnlockData(key, tokenId, amount0Min, amount1Min, recipient, hookData), deadline
        );
        delete custodialPositionOwner[tokenId];
        emit PositionBurned(tokenId, recipient);
    }

    function _pullPair(PoolKey memory key, uint128 amount0Max, uint128 amount1Max)
        internal
        returns (address token0, address token1)
    {
        if (key.currency0.isAddressZero() || key.currency1.isAddressZero()) {
            revert NativeCurrencyNotSupported();
        }

        token0 = Currency.unwrap(key.currency0);
        token1 = Currency.unwrap(key.currency1);

        if (amount0Max > 0) IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0Max);
        if (amount1Max > 0) IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1Max);
    }

    function _approvePair(address token0, address token1, uint128 amount0Max, uint128 amount1Max, uint256 deadline)
        internal
    {
        uint48 expiration = deadline > type(uint48).max ? type(uint48).max : uint48(deadline);
        if (amount0Max > 0) approveTokenWithPermit2(token0, uint160(amount0Max), expiration);
        if (amount1Max > 0) approveTokenWithPermit2(token1, uint160(amount1Max), expiration);
    }

    function _refundTokenDelta(address token, address recipient, uint256 startingBalance) internal {
        uint256 endingBalance = IERC20(token).balanceOf(address(this));
        if (endingBalance > startingBalance) {
            IERC20(token).safeTransfer(recipient, endingBalance - startingBalance);
        }
    }

    function _requirePositionCaller(uint256 tokenId) internal view {
        address custodialOwner = custodialPositionOwner[tokenId];
        if (custodialOwner != address(0)) {
            if (msg.sender != custodialOwner) revert UnauthorizedPositionCaller(tokenId, msg.sender);
            return;
        }

        IERC721 nft = IERC721(address(positionManager));
        address owner = nft.ownerOf(tokenId);
        if (msg.sender == owner || nft.getApproved(tokenId) == msg.sender || nft.isApprovedForAll(owner, msg.sender)) {
            return;
        }

        revert UnauthorizedPositionCaller(tokenId, msg.sender);
    }

    function _mintPosition(PoolKey calldata key, MintPositionParams memory params) internal returns (uint256 tokenId) {
        if (params.recipient == address(0)) revert InvalidRecipient();
        if (params.liquidity == 0) revert InvalidAmount();

        tokenId = positionManager.nextTokenId();
        (address token0, address token1) = _pullPair(key, params.amount0Max, params.amount1Max);
        _approvePair(token0, token1, params.amount0Max, params.amount1Max, params.deadline);

        uint256 startBalance0 = IERC20(token0).balanceOf(address(this)) - params.amount0Max;
        uint256 startBalance1 = IERC20(token1).balanceOf(address(this)) - params.amount1Max;
        bytes memory unlockData = encodeMintPositionUnlockData(
            key,
            params.tickLower,
            params.tickUpper,
            params.liquidity,
            params.amount0Max,
            params.amount1Max,
            params.recipient,
            params.hookData
        );
        positionManager.modifyLiquidities(unlockData, params.deadline);
        if (params.recipient == address(this)) {
            custodialPositionOwner[tokenId] = msg.sender;
        }
        _refundTokenDelta(token0, msg.sender, startBalance0);
        _refundTokenDelta(token1, msg.sender, startBalance1);

        emit PositionMinted(tokenId, params.recipient, key.toId());
    }
}
