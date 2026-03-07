// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin-contracts@5.4.0/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "openzeppelin-contracts@5.4.0/utils/ReentrancyGuard.sol";

/// @title EnglishAuction
/// @notice Escrows NFTs for concurrent English auctions settled in Ether.
/// @dev Outbid bidders withdraw later to avoid pushing Ether during bids.
contract EnglishAuction is IERC721Receiver, ReentrancyGuard {
    struct Auction {
        address seller;
        address nft;
        uint256 tokenId;
        uint256 deadline;
        uint256 reservePrice;
        address highestBidder;
        uint256 highestBid;
        bool settled;
    }

    uint256 public auctionCount;

    mapping(uint256 auctionId => Auction auction) public auctions;
    mapping(uint256 auctionId => mapping(address bidder => uint256 amount)) public refundableBids;
    mapping(address seller => uint256 amount) public sellerProceeds;

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nft,
        uint256 tokenId,
        uint256 deadline,
        uint256 reservePrice
    );
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event BidWithdrawn(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event ProceedsWithdrawn(address indexed seller, uint256 amount);
    event AuctionSettled(
        uint256 indexed auctionId, address indexed seller, address indexed winner, uint256 amount, bool reserveMet
    );

    error AmountZero();
    error AuctionAlreadySettled();
    error AuctionNotFound();
    error BidTooLow(uint256 bidAmount, uint256 highestBid);
    error DeadlineNotInFuture();
    error AuctionActive(uint256 currentTime, uint256 deadline);
    error AuctionExpired(uint256 currentTime, uint256 deadline);
    error NothingToWithdraw();
    error ReserveMet(uint256 highestBid, uint256 reservePrice);
    error ReserveNotMet(uint256 highestBid, uint256 reservePrice);
    error TransferFailed();
    error Unauthorized();
    error ZeroAddress();

    /// @notice Deposit an NFT into escrow and create a new auction.
    /// @param nft ERC721 token address being auctioned.
    /// @param tokenId NFT identifier being auctioned.
    /// @param deadline Timestamp after which no more bids are accepted.
    /// @param reservePrice Minimum winning bid denominated in wei.
    /// @return auctionId Newly created auction id.
    function deposit(address nft, uint256 tokenId, uint256 deadline, uint256 reservePrice)
        external
        returns (uint256 auctionId)
    {
        if (nft == address(0)) revert ZeroAddress();
        if (deadline <= block.timestamp) revert DeadlineNotInFuture();

        auctionId = ++auctionCount;
        auctions[auctionId] = Auction({
            seller: msg.sender,
            nft: nft,
            tokenId: tokenId,
            deadline: deadline,
            reservePrice: reservePrice,
            highestBidder: address(0),
            highestBid: 0,
            settled: false
        });

        IERC721(nft).safeTransferFrom(msg.sender, address(this), tokenId);

        emit AuctionCreated(auctionId, msg.sender, nft, tokenId, deadline, reservePrice);
    }

    /// @notice Place a bid with Ether before the deadline.
    /// @dev The full `msg.value` becomes the caller's active bid.
    /// @param auctionId Auction to bid on.
    function bid(uint256 auctionId) external payable {
        Auction storage auction = _getAuction(auctionId);

        if (msg.value == 0) revert AmountZero();
        if (auction.settled) revert AuctionAlreadySettled();
        if (block.timestamp >= auction.deadline) {
            revert AuctionExpired(block.timestamp, auction.deadline);
        }
        if (msg.value <= auction.highestBid) revert BidTooLow(msg.value, auction.highestBid);

        address previousHighestBidder = auction.highestBidder;
        uint256 previousHighestBid = auction.highestBid;

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        if (previousHighestBidder != address(0)) {
            refundableBids[auctionId][previousHighestBidder] += previousHighestBid;
        }

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    /// @notice Withdraw an outbid or unsuccessful bid balance.
    /// @param auctionId Auction whose refundable balance should be withdrawn.
    function withdrawBid(uint256 auctionId) external nonReentrant {
        Auction storage auction = _getAuction(auctionId);

        // If a failed auction expires before the seller reclaims the NFT, let the top bidder
        // escape their locked funds without depending on seller cooperation.
        if (
            !auction.settled && block.timestamp >= auction.deadline && auction.highestBid != 0
                && auction.highestBid < auction.reservePrice && msg.sender == auction.highestBidder
        ) {
            refundableBids[auctionId][msg.sender] += auction.highestBid;
            auction.highestBid = 0;
            auction.highestBidder = address(0);
        }

        uint256 amount = refundableBids[auctionId][msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        refundableBids[auctionId][msg.sender] = 0;

        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit BidWithdrawn(auctionId, msg.sender, amount);
    }

    /// @notice End an expired auction that met the reserve price.
    /// @dev Records seller proceeds for later withdrawal and transfers the NFT to the winner.
    /// @param auctionId Auction to settle.
    function sellerEndAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = _getAuction(auctionId);

        if (msg.sender != auction.seller) revert Unauthorized();
        if (auction.settled) revert AuctionAlreadySettled();
        if (block.timestamp < auction.deadline) {
            revert AuctionActive(block.timestamp, auction.deadline);
        }
        if (auction.highestBidder == address(0) || auction.highestBid < auction.reservePrice) {
            revert ReserveNotMet(auction.highestBid, auction.reservePrice);
        }

        auction.settled = true;
        sellerProceeds[auction.seller] += auction.highestBid;
        // Use transferFrom so a malicious bidder contract cannot brick settlement by reverting
        // in onERC721Received after it chose to bid from that address.
        IERC721(auction.nft).transferFrom(address(this), auction.highestBidder, auction.tokenId);

        emit AuctionSettled(auctionId, auction.seller, auction.highestBidder, auction.highestBid, true);
    }

    /// @notice Reclaim an expired auction that failed to meet the reserve price.
    /// @dev The top bidder, if any, is credited for later withdrawal.
    /// @param auctionId Auction to close without a sale.
    function reclaimUnsoldAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = _getAuction(auctionId);

        if (msg.sender != auction.seller) revert Unauthorized();
        if (auction.settled) revert AuctionAlreadySettled();
        if (block.timestamp < auction.deadline) {
            revert AuctionActive(block.timestamp, auction.deadline);
        }
        if (auction.highestBidder != address(0) && auction.highestBid >= auction.reservePrice) {
            revert ReserveMet(auction.highestBid, auction.reservePrice);
        }

        auction.settled = true;

        if (auction.highestBidder != address(0) && auction.highestBid != 0) {
            refundableBids[auctionId][auction.highestBidder] += auction.highestBid;
            auction.highestBid = 0;
            auction.highestBidder = address(0);
        }

        IERC721(auction.nft).transferFrom(address(this), auction.seller, auction.tokenId);

        emit AuctionSettled(auctionId, auction.seller, address(0), 0, false);
    }

    /// @notice Withdraw ETH proceeds from successful auctions.
    function withdrawProceeds() external nonReentrant {
        uint256 amount = sellerProceeds[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        sellerProceeds[msg.sender] = 0;

        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit ProceedsWithdrawn(msg.sender, amount);
    }

    function _getAuction(uint256 auctionId) internal view returns (Auction storage auction) {
        auction = auctions[auctionId];
        if (auction.seller == address(0)) revert AuctionNotFound();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
