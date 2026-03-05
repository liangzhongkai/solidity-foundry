// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin-contracts@5.4.0/token/ERC721/IERC721Receiver.sol";

/// @title NFTSwap (Case 10)
/// @notice Trustless NFT-for-NFT swap with timeout-based withdrawals.
contract NFTSwap is IERC721Receiver {
    struct NFT {
        address nft;
        uint256 tokenId;
    }

    struct Swap {
        address maker;
        address taker;
        NFT makerNft;
        NFT takerNft;
        bool makerDeposited;
        bool takerDeposited;
        uint64 withdrawAfter;
    }

    uint64 public constant MAX_LOCK_PERIOD = 30 days;
    uint256 public swapCounter;
    mapping(uint256 => Swap) public swaps;

    error InvalidSwapId();
    error InvalidAddress();
    error InvalidLockPeriod();
    error Unauthorized();
    error AlreadyDeposited();
    error WithdrawalNotAllowedYet();
    error SwapNotReady();

    event SwapCreated(
        uint256 indexed swapId,
        address indexed maker,
        address indexed taker,
        address makerNft,
        uint256 makerTokenId,
        address takerNft,
        uint256 takerTokenId,
        uint64 withdrawAfter
    );
    event Deposited(uint256 indexed swapId, address indexed depositor, address nft, uint256 tokenId);
    event Swapped(uint256 indexed swapId, address indexed maker, address indexed taker);
    event Withdrawn(uint256 indexed swapId, address indexed user, address nft, uint256 tokenId);

    function createSwap(
        address taker,
        address makerNft,
        uint256 makerTokenId,
        address takerNft,
        uint256 takerTokenId,
        uint64 lockPeriod
    ) external returns (uint256 swapId) {
        if (makerNft == address(0) || takerNft == address(0)) revert InvalidAddress();
        if (lockPeriod > MAX_LOCK_PERIOD) revert InvalidLockPeriod();

        swapId = swapCounter++;
        uint64 withdrawAfter = uint64(block.timestamp) + lockPeriod;

        swaps[swapId] = Swap({
            maker: msg.sender,
            taker: taker,
            makerNft: NFT({nft: makerNft, tokenId: makerTokenId}),
            takerNft: NFT({nft: takerNft, tokenId: takerTokenId}),
            makerDeposited: false,
            takerDeposited: false,
            withdrawAfter: withdrawAfter
        });

        emit SwapCreated(swapId, msg.sender, taker, makerNft, makerTokenId, takerNft, takerTokenId, withdrawAfter);
    }

    function depositMaker(uint256 swapId) external {
        Swap storage s = _mustExist(swapId);
        if (msg.sender != s.maker) revert Unauthorized();
        if (s.makerDeposited) revert AlreadyDeposited();

        s.makerDeposited = true;
        IERC721(s.makerNft.nft).safeTransferFrom(msg.sender, address(this), s.makerNft.tokenId);
        emit Deposited(swapId, msg.sender, s.makerNft.nft, s.makerNft.tokenId);
    }

    function depositTaker(uint256 swapId) external {
        Swap storage s = _mustExist(swapId);
        if (s.taker != address(0) && msg.sender != s.taker) revert Unauthorized();
        if (s.takerDeposited) revert AlreadyDeposited();

        s.takerDeposited = true;
        // For open swaps, lock taker identity to first depositor.
        if (s.taker == address(0)) {
            s.taker = msg.sender;
        }

        IERC721(s.takerNft.nft).safeTransferFrom(msg.sender, address(this), s.takerNft.tokenId);
        emit Deposited(swapId, msg.sender, s.takerNft.nft, s.takerNft.tokenId);
    }

    function swap(uint256 swapId) external {
        Swap memory s = _loadAndValidateForSwap(swapId);
        if (msg.sender != s.maker && msg.sender != s.taker) revert Unauthorized();

        delete swaps[swapId];

        IERC721(s.makerNft.nft).safeTransferFrom(address(this), s.taker, s.makerNft.tokenId);
        IERC721(s.takerNft.nft).safeTransferFrom(address(this), s.maker, s.takerNft.tokenId);

        emit Swapped(swapId, s.maker, s.taker);
    }

    function withdraw(uint256 swapId) external {
        Swap storage s = _mustExist(swapId);
        if (block.timestamp < s.withdrawAfter) revert WithdrawalNotAllowedYet();

        bool isMaker = msg.sender == s.maker;
        bool isTaker = msg.sender == s.taker;
        if (!isMaker && !isTaker) revert Unauthorized();

        if (isMaker && s.makerDeposited) {
            s.makerDeposited = false;
            IERC721(s.makerNft.nft).safeTransferFrom(address(this), s.maker, s.makerNft.tokenId);
            emit Withdrawn(swapId, s.maker, s.makerNft.nft, s.makerNft.tokenId);
        }

        if (isTaker && s.takerDeposited) {
            s.takerDeposited = false;
            IERC721(s.takerNft.nft).safeTransferFrom(address(this), s.taker, s.takerNft.tokenId);
            emit Withdrawn(swapId, s.taker, s.takerNft.nft, s.takerNft.tokenId);
        }

        if (!s.makerDeposited && !s.takerDeposited) {
            delete swaps[swapId];
        }
    }

    function getSwap(uint256 swapId) external view returns (Swap memory s) {
        s = swaps[swapId];
        if (s.maker == address(0)) revert InvalidSwapId();
    }

    function _mustExist(uint256 swapId) internal view returns (Swap storage s) {
        s = swaps[swapId];
        if (s.maker == address(0)) revert InvalidSwapId();
    }

    function _loadAndValidateForSwap(uint256 swapId) internal view returns (Swap memory s) {
        s = swaps[swapId];
        if (s.maker == address(0)) revert InvalidSwapId();
        if (!s.makerDeposited || !s.takerDeposited) revert SwapNotReady();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
