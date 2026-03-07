// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "openzeppelin-contracts@5.4.0/utils/ReentrancyGuard.sol";

/// @title Simple NFT Marketplace
/// @notice Lets sellers list ERC721 tokens via approval without escrowing the NFT.
/// @dev Listings are keyed by `seller + nft + tokenId`; repeated sells overwrite the active listing.
contract SimpleNFTMarketplace is ReentrancyGuard {
    struct Listing {
        uint256 price;
        uint64 expiresAt;
    }

    mapping(address seller => mapping(address nft => mapping(uint256 tokenId => Listing listing))) public listings;

    event Listed(address indexed seller, address indexed nft, uint256 indexed tokenId, uint256 price, uint64 expiresAt);
    event Cancelled(address indexed seller, address indexed nft, uint256 indexed tokenId);
    event Purchased(address indexed seller, address indexed buyer, address indexed nft, uint256 tokenId, uint256 price);

    error EthTransferFailed();
    error IncorrectPayment(uint256 sent, uint256 expected);
    error InvalidExpiration();
    error InvalidPrice();
    error ListingExpired(uint256 currentTime, uint256 expiresAt);
    error ListingNotFound();
    error MarketplaceNotApproved();
    error NotTokenOwner(address expectedOwner, address actualOwner);
    error ZeroAddress();

    /// @notice Create or overwrite a listing for an owned NFT.
    /// @param nft ERC721 contract address.
    /// @param tokenId Token id to list.
    /// @param price Fixed sale price in wei.
    /// @param expiresAt Unix timestamp after which the listing can no longer be bought.
    function sell(address nft, uint256 tokenId, uint256 price, uint64 expiresAt) external {
        if (nft == address(0)) revert ZeroAddress();
        if (price == 0) revert InvalidPrice();
        if (expiresAt <= block.timestamp) revert InvalidExpiration();

        _requireOwnedAndApproved(msg.sender, nft, tokenId);

        listings[msg.sender][nft][tokenId] = Listing({price: price, expiresAt: expiresAt});

        emit Listed(msg.sender, nft, tokenId, price, expiresAt);
    }

    /// @notice Cancel the caller's active listing.
    /// @param nft ERC721 contract address.
    /// @param tokenId Token id to cancel.
    function cancel(address nft, uint256 tokenId) external {
        Listing memory listing = listings[msg.sender][nft][tokenId];
        if (listing.price == 0) revert ListingNotFound();

        delete listings[msg.sender][nft][tokenId];

        emit Cancelled(msg.sender, nft, tokenId);
    }

    /// @notice Buy an active listing by paying the exact listed price in Ether.
    /// @param seller Address that created the listing.
    /// @param nft ERC721 contract address.
    /// @param tokenId Token id being purchased.
    function buy(address seller, address nft, uint256 tokenId) external payable nonReentrant {
        Listing memory listing = listings[seller][nft][tokenId];
        if (listing.price == 0) revert ListingNotFound();
        if (block.timestamp >= listing.expiresAt) revert ListingExpired(block.timestamp, listing.expiresAt);
        if (msg.value != listing.price) revert IncorrectPayment(msg.value, listing.price);

        _requireOwnedAndApproved(seller, nft, tokenId);

        // Invalidate before external calls so the listing cannot be purchased twice.
        delete listings[seller][nft][tokenId];

        IERC721(nft).safeTransferFrom(seller, msg.sender, tokenId);

        (bool ok,) = seller.call{value: msg.value}("");
        if (!ok) revert EthTransferFailed();

        emit Purchased(seller, msg.sender, nft, tokenId, listing.price);
    }

    /// @notice Read the current listing for a seller's NFT.
    /// @param seller Listing owner.
    /// @param nft ERC721 contract address.
    /// @param tokenId Token id.
    /// @return listing Active listing data; zero values mean no listing exists.
    function getListing(address seller, address nft, uint256 tokenId) external view returns (Listing memory listing) {
        listing = listings[seller][nft][tokenId];
    }

    function _requireOwnedAndApproved(address seller, address nft, uint256 tokenId) internal view {
        IERC721 token = IERC721(nft);
        address owner = token.ownerOf(tokenId);
        if (owner != seller) revert NotTokenOwner(seller, owner);

        bool approved = token.getApproved(tokenId) == address(this) || token.isApprovedForAll(seller, address(this));
        if (!approved) revert MarketplaceNotApproved();
    }
}
