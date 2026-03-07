// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {ERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/ERC721.sol";

import {SimpleNFTMarketplace} from "../../src/13-simple-nft-marketplace/SimpleNFTMarketplace.sol";

contract MockERC721 is ERC721 {
    uint256 internal _nextId;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function mint(address to) external returns (uint256 tokenId) {
        tokenId = _nextId++;
        _safeMint(to, tokenId);
    }
}

contract NonPayableSeller {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0x150b7a02;
    }

    function approveMarketplace(address nft, address marketplace) external {
        ERC721(nft).setApprovalForAll(marketplace, true);
    }

    function list(address marketplace, address nft, uint256 tokenId, uint256 price, uint64 expiresAt) external {
        SimpleNFTMarketplace(marketplace).sell(nft, tokenId, price, expiresAt);
    }
}

contract SimpleNFTMarketplaceTest is Test {
    SimpleNFTMarketplace internal marketplace;
    MockERC721 internal nft;

    address internal seller = makeAddr("seller");
    address internal buyer = makeAddr("buyer");
    address internal otherBuyer = makeAddr("otherBuyer");

    uint256 internal sellerToken0;
    uint256 internal sellerToken1;

    function setUp() public {
        marketplace = new SimpleNFTMarketplace();
        nft = new MockERC721("Marketplace NFT", "MNFT");

        sellerToken0 = nft.mint(seller);
        sellerToken1 = nft.mint(seller);

        vm.deal(buyer, 10 ether);
        vm.deal(otherBuyer, 10 ether);

        vm.prank(seller);
        nft.setApprovalForAll(address(marketplace), true);
    }

    function _sell(address listingSeller, uint256 tokenId, uint256 price, uint64 expiresAt) internal {
        vm.prank(listingSeller);
        marketplace.sell(address(nft), tokenId, price, expiresAt);
    }

    function test_SellStoresListing() public {
        uint64 expiresAt = uint64(block.timestamp + 3 days);

        _sell(seller, sellerToken0, 1 ether, expiresAt);

        (uint256 price, uint64 listingExpiry) = marketplace.listings(seller, address(nft), sellerToken0);
        assertEq(price, 1 ether);
        assertEq(listingExpiry, expiresAt);
    }

    function test_BuyTransfersNFTAndEtherAndClearsListing() public {
        uint64 expiresAt = uint64(block.timestamp + 3 days);
        _sell(seller, sellerToken0, 1 ether, expiresAt);

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);
        marketplace.buy{value: 1 ether}(seller, address(nft), sellerToken0);

        assertEq(nft.ownerOf(sellerToken0), buyer);
        assertEq(seller.balance, sellerBalanceBefore + 1 ether);

        (uint256 price, uint64 listingExpiry) = marketplace.listings(seller, address(nft), sellerToken0);
        assertEq(price, 0);
        assertEq(listingExpiry, 0);
    }

    function testFuzz_BuyTransfersExactPrice(uint96 rawPrice, uint32 rawDuration) public {
        uint256 price = bound(uint256(rawPrice), 1 wei, 5 ether);
        uint64 expiresAt = uint64(block.timestamp + bound(uint256(rawDuration), 1, 30 days));
        _sell(seller, sellerToken0, price, expiresAt);

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);
        marketplace.buy{value: price}(seller, address(nft), sellerToken0);

        assertEq(nft.ownerOf(sellerToken0), buyer);
        assertEq(seller.balance, sellerBalanceBefore + price);
    }

    function test_CancelRemovesListing() public {
        _sell(seller, sellerToken0, 1 ether, uint64(block.timestamp + 3 days));

        vm.prank(seller);
        marketplace.cancel(address(nft), sellerToken0);

        (uint256 price, uint64 listingExpiry) = marketplace.listings(seller, address(nft), sellerToken0);
        assertEq(price, 0);
        assertEq(listingExpiry, 0);
    }

    function test_Revert_BuyAfterCancel() public {
        _sell(seller, sellerToken0, 1 ether, uint64(block.timestamp + 3 days));

        vm.prank(seller);
        marketplace.cancel(address(nft), sellerToken0);

        vm.prank(buyer);
        vm.expectRevert(SimpleNFTMarketplace.ListingNotFound.selector);
        marketplace.buy{value: 1 ether}(seller, address(nft), sellerToken0);
    }

    function test_SecondSellOverwritesExistingListing() public {
        _sell(seller, sellerToken0, 1 ether, uint64(block.timestamp + 1 days));
        _sell(seller, sellerToken0, 2 ether, uint64(block.timestamp + 5 days));

        (uint256 price, uint64 listingExpiry) = marketplace.listings(seller, address(nft), sellerToken0);
        assertEq(price, 2 ether);
        assertEq(listingExpiry, uint64(block.timestamp + 5 days));

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(SimpleNFTMarketplace.IncorrectPayment.selector, 1 ether, 2 ether));
        marketplace.buy{value: 1 ether}(seller, address(nft), sellerToken0);

        vm.prank(buyer);
        marketplace.buy{value: 2 ether}(seller, address(nft), sellerToken0);

        assertEq(nft.ownerOf(sellerToken0), buyer);
    }

    function test_Revert_SellWithoutApproval() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(marketplace), false);

        vm.prank(seller);
        vm.expectRevert(SimpleNFTMarketplace.MarketplaceNotApproved.selector);
        marketplace.sell(address(nft), sellerToken0, 1 ether, uint64(block.timestamp + 1 days));
    }

    function test_Revert_SellWithoutOwnership() public {
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(SimpleNFTMarketplace.NotTokenOwner.selector, buyer, seller));
        marketplace.sell(address(nft), sellerToken0, 1 ether, uint64(block.timestamp + 1 days));
    }

    function test_Revert_BuyWithIncorrectPrice() public {
        _sell(seller, sellerToken0, 1 ether, uint64(block.timestamp + 2 days));

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(SimpleNFTMarketplace.IncorrectPayment.selector, 0.5 ether, 1 ether));
        marketplace.buy{value: 0.5 ether}(seller, address(nft), sellerToken0);
    }

    function test_Revert_BuyAtExpirationTimestamp() public {
        uint64 expiresAt = uint64(block.timestamp + 2 days);
        _sell(seller, sellerToken0, 1 ether, expiresAt);

        vm.warp(expiresAt);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(SimpleNFTMarketplace.ListingExpired.selector, expiresAt, expiresAt));
        marketplace.buy{value: 1 ether}(seller, address(nft), sellerToken0);
    }

    function test_Revert_BuyWhenSellerTransferredNftAway() public {
        _sell(seller, sellerToken0, 1 ether, uint64(block.timestamp + 2 days));

        vm.prank(seller);
        nft.transferFrom(seller, otherBuyer, sellerToken0);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(SimpleNFTMarketplace.NotTokenOwner.selector, seller, otherBuyer));
        marketplace.buy{value: 1 ether}(seller, address(nft), sellerToken0);
    }

    function test_Revert_BuyWhenSellerRevokedApproval() public {
        _sell(seller, sellerToken0, 1 ether, uint64(block.timestamp + 2 days));

        vm.prank(seller);
        nft.setApprovalForAll(address(marketplace), false);

        vm.prank(buyer);
        vm.expectRevert(SimpleNFTMarketplace.MarketplaceNotApproved.selector);
        marketplace.buy{value: 1 ether}(seller, address(nft), sellerToken0);
    }

    function test_Revert_BuyWhenSellerCannotReceiveEther() public {
        NonPayableSeller sellerContract = new NonPayableSeller();
        uint256 sellerContractToken = nft.mint(address(sellerContract));

        sellerContract.approveMarketplace(address(nft), address(marketplace));
        sellerContract.list(
            address(marketplace), address(nft), sellerContractToken, 1 ether, uint64(block.timestamp + 2 days)
        );

        vm.prank(buyer);
        vm.expectRevert(SimpleNFTMarketplace.EthTransferFailed.selector);
        marketplace.buy{value: 1 ether}(address(sellerContract), address(nft), sellerContractToken);

        assertEq(nft.ownerOf(sellerContractToken), address(sellerContract));
    }

    function test_CancelExpiredListingStillWorks() public {
        uint64 expiresAt = uint64(block.timestamp + 1 days);
        _sell(seller, sellerToken1, 2 ether, expiresAt);

        vm.warp(expiresAt + 1);

        vm.prank(seller);
        marketplace.cancel(address(nft), sellerToken1);

        (uint256 price, uint64 listingExpiry) = marketplace.listings(seller, address(nft), sellerToken1);
        assertEq(price, 0);
        assertEq(listingExpiry, 0);
    }
}
