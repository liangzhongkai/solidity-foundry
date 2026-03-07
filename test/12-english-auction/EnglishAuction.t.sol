// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {ERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/ERC721.sol";
import {EnglishAuction} from "../../src/12-english-auction/EnglishAuction.sol";

contract MockERC721 is ERC721 {
    uint256 internal _nextId;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function mint(address to) external returns (uint256 tokenId) {
        tokenId = _nextId++;
        _safeMint(to, tokenId);
    }
}

contract BidderWithoutReceiver {
    function placeBid(address auction, uint256 auctionId) external payable {
        EnglishAuction(auction).bid{value: msg.value}(auctionId);
    }
}

contract NonPayableSeller {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0x150b7a02;
    }

    function approveAuction(address nft, address auction) external {
        ERC721(nft).setApprovalForAll(auction, true);
    }

    function depositAuction(address auction, address nft, uint256 tokenId, uint256 deadline, uint256 reservePrice)
        external
        returns (uint256 auctionId)
    {
        auctionId = EnglishAuction(auction).deposit(nft, tokenId, deadline, reservePrice);
    }

    function endAuction(address auction, uint256 auctionId) external {
        EnglishAuction(auction).sellerEndAuction(auctionId);
    }

    function withdrawAuctionProceeds(address auction) external {
        EnglishAuction(auction).withdrawProceeds();
    }
}

contract EnglishAuctionTest is Test {
    EnglishAuction internal auction;
    MockERC721 internal nft;

    address internal seller = makeAddr("seller");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 internal sellerToken0;
    uint256 internal sellerToken1;

    function setUp() public {
        auction = new EnglishAuction();
        nft = new MockERC721("Auction NFT", "ANFT");

        sellerToken0 = nft.mint(seller);
        sellerToken1 = nft.mint(seller);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);

        vm.prank(seller);
        nft.setApprovalForAll(address(auction), true);
    }

    function _deposit(uint256 tokenId, uint256 reservePrice, uint256 duration) internal returns (uint256 auctionId) {
        vm.prank(seller);
        auctionId = auction.deposit(address(nft), tokenId, block.timestamp + duration, reservePrice);
    }

    function _bid(address bidder, uint256 auctionId, uint256 amount) internal {
        vm.prank(bidder);
        auction.bid{value: amount}(auctionId);
    }

    function test_DepositEscrowsNFTAndStoresAuction() public {
        uint256 deadline = block.timestamp + 3 days;

        vm.prank(seller);
        uint256 auctionId = auction.deposit(address(nft), sellerToken0, deadline, 2 ether);

        (
            address auctionSeller,
            address auctionNft,
            uint256 auctionTokenId,
            uint256 auctionDeadline,
            uint256 reservePrice,
            address highestBidder,
            uint256 highestBid,
            bool settled
        ) = auction.auctions(auctionId);

        assertEq(auctionSeller, seller);
        assertEq(auctionNft, address(nft));
        assertEq(auctionTokenId, sellerToken0);
        assertEq(auctionDeadline, deadline);
        assertEq(reservePrice, 2 ether);
        assertEq(highestBidder, address(0));
        assertEq(highestBid, 0);
        assertFalse(settled);
        assertEq(nft.ownerOf(sellerToken0), address(auction));
    }

    function test_Revert_DepositWithPastDeadline() public {
        vm.prank(seller);
        vm.expectRevert(EnglishAuction.DeadlineNotInFuture.selector);
        auction.deposit(address(nft), sellerToken0, block.timestamp, 1 ether);
    }

    function test_Revert_BidOnMissingAuction() public {
        vm.prank(alice);
        vm.expectRevert(EnglishAuction.AuctionNotFound.selector);
        auction.bid{value: 1 ether}(999);
    }

    function test_Revert_BidWithZeroAmount() public {
        uint256 auctionId = _deposit(sellerToken0, 1 ether, 1 days);

        vm.prank(alice);
        vm.expectRevert(EnglishAuction.AmountZero.selector);
        auction.bid{value: 0}(auctionId);
    }

    function test_Revert_BidTooLow() public {
        uint256 auctionId = _deposit(sellerToken0, 1 ether, 1 days);

        _bid(alice, auctionId, 2 ether);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(EnglishAuction.BidTooLow.selector, 2 ether, 2 ether));
        auction.bid{value: 2 ether}(auctionId);
    }

    function test_Revert_BidAfterDeadline() public {
        uint256 auctionId = _deposit(sellerToken0, 1 ether, 1 days);

        vm.warp(block.timestamp + 1 days);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(EnglishAuction.AuctionExpired.selector, block.timestamp, block.timestamp)
        );
        auction.bid{value: 1 ether}(auctionId);
    }

    function test_OutbidBidderCanWithdraw() public {
        uint256 auctionId = _deposit(sellerToken0, 3 ether, 2 days);

        _bid(alice, auctionId, 1 ether);
        _bid(bob, auctionId, 2 ether);

        assertEq(auction.refundableBids(auctionId, alice), 1 ether);

        uint256 aliceBalanceBefore = alice.balance;
        vm.prank(alice);
        auction.withdrawBid(auctionId);

        assertEq(alice.balance, aliceBalanceBefore + 1 ether);
        assertEq(auction.refundableBids(auctionId, alice), 0);
    }

    function test_Revert_CurrentHighestBidderCannotWithdraw() public {
        uint256 auctionId = _deposit(sellerToken0, 1 ether, 2 days);

        _bid(alice, auctionId, 1 ether);

        vm.prank(alice);
        vm.expectRevert(EnglishAuction.NothingToWithdraw.selector);
        auction.withdrawBid(auctionId);
    }

    function test_ExpiredHighestBidderCanWithdrawWithoutSellerCooperationWhenReserveNotMet() public {
        uint256 auctionId = _deposit(sellerToken0, 5 ether, 2 days);

        _bid(alice, auctionId, 3 ether);

        vm.warp(block.timestamp + 2 days + 1);

        uint256 aliceBalanceBefore = alice.balance;
        vm.prank(alice);
        auction.withdrawBid(auctionId);

        assertEq(alice.balance, aliceBalanceBefore + 3 ether);
        assertEq(auction.refundableBids(auctionId, alice), 0);

        (,,,,, address highestBidder, uint256 highestBid, bool settled) = auction.auctions(auctionId);
        assertEq(highestBidder, address(0));
        assertEq(highestBid, 0);
        assertFalse(settled);
        assertEq(nft.ownerOf(sellerToken0), address(auction));
    }

    function test_SellerEndAuctionTransfersNFTAndCreditsProceedsWhenReserveMet() public {
        uint256 auctionId = _deposit(sellerToken0, 2 ether, 2 days);

        _bid(alice, auctionId, 2 ether);
        _bid(bob, auctionId, 3 ether);

        vm.warp(block.timestamp + 2 days + 1);

        vm.prank(seller);
        auction.sellerEndAuction(auctionId);

        assertEq(nft.ownerOf(sellerToken0), bob);
        assertEq(auction.sellerProceeds(seller), 3 ether);
        assertEq(address(auction).balance, 5 ether);
        assertEq(auction.refundableBids(auctionId, alice), 2 ether);

        (,,,,,, uint256 highestBid, bool settled) = auction.auctions(auctionId);
        assertEq(highestBid, 3 ether);
        assertTrue(settled);
    }

    function test_SellerCanWithdrawProceedsAfterSuccessfulAuction() public {
        uint256 auctionId = _deposit(sellerToken0, 2 ether, 2 days);

        _bid(alice, auctionId, 3 ether);

        vm.warp(block.timestamp + 2 days + 1);

        vm.prank(seller);
        auction.sellerEndAuction(auctionId);

        uint256 sellerBalanceBefore = seller.balance;
        vm.prank(seller);
        auction.withdrawProceeds();

        assertEq(seller.balance, sellerBalanceBefore + 3 ether);
        assertEq(auction.sellerProceeds(seller), 0);
        assertEq(address(auction).balance, 0);
    }

    function test_ReclaimUnsoldAuctionReturnsNFTAndCreditsTopBidder() public {
        uint256 auctionId = _deposit(sellerToken0, 5 ether, 2 days);

        _bid(alice, auctionId, 3 ether);

        vm.warp(block.timestamp + 2 days + 1);

        vm.prank(seller);
        auction.reclaimUnsoldAuction(auctionId);

        assertEq(nft.ownerOf(sellerToken0), seller);
        assertEq(auction.refundableBids(auctionId, alice), 3 ether);

        uint256 aliceBalanceBefore = alice.balance;
        vm.prank(alice);
        auction.withdrawBid(auctionId);
        assertEq(alice.balance, aliceBalanceBefore + 3 ether);
    }

    function test_ReclaimUnsoldAuctionReturnsNFTWhenNoBidsWerePlaced() public {
        uint256 auctionId = _deposit(sellerToken0, 5 ether, 2 days);

        vm.warp(block.timestamp + 2 days + 1);

        vm.prank(seller);
        auction.reclaimUnsoldAuction(auctionId);

        assertEq(nft.ownerOf(sellerToken0), seller);
        (,,,,,, uint256 highestBid, bool settled) = auction.auctions(auctionId);
        assertEq(highestBid, 0);
        assertTrue(settled);
    }

    function test_SettlementCannotBeBrickedByWinningContractWithoutERC721Receiver() public {
        BidderWithoutReceiver badWinner = new BidderWithoutReceiver();
        vm.deal(address(badWinner), 10 ether);

        uint256 auctionId = _deposit(sellerToken0, 2 ether, 2 days);

        badWinner.placeBid{value: 3 ether}(address(auction), auctionId);

        vm.warp(block.timestamp + 2 days + 1);

        vm.prank(seller);
        auction.sellerEndAuction(auctionId);

        assertEq(nft.ownerOf(sellerToken0), address(badWinner));
        assertEq(auction.sellerProceeds(seller), 3 ether);
    }

    function test_SettlementCreditsProceedsEvenIfSellerCannotReceiveETHDuringSettlement() public {
        NonPayableSeller sellerContract = new NonPayableSeller();
        MockERC721 sellerNft = new MockERC721("Seller Contract NFT", "SCNFT");
        uint256 sellerContractToken = sellerNft.mint(address(sellerContract));

        sellerContract.approveAuction(address(sellerNft), address(auction));
        uint256 deadline = block.timestamp + 2 days;
        uint256 auctionId =
            sellerContract.depositAuction(address(auction), address(sellerNft), sellerContractToken, deadline, 2 ether);

        _bid(alice, auctionId, 3 ether);

        vm.warp(block.timestamp + 2 days + 1);

        sellerContract.endAuction(address(auction), auctionId);

        assertEq(sellerNft.ownerOf(sellerContractToken), alice);
        assertEq(auction.sellerProceeds(address(sellerContract)), 3 ether);

        vm.expectRevert(EnglishAuction.TransferFailed.selector);
        sellerContract.withdrawAuctionProceeds(address(auction));
    }

    function test_Revert_OnlySellerCanEndAuction() public {
        uint256 auctionId = _deposit(sellerToken0, 1 ether, 1 days);

        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(alice);
        vm.expectRevert(EnglishAuction.Unauthorized.selector);
        auction.sellerEndAuction(auctionId);
    }

    function test_Revert_CannotEndAuctionBeforeDeadline() public {
        uint256 auctionId = _deposit(sellerToken0, 1 ether, 1 days);

        vm.prank(seller);
        vm.expectRevert(
            abi.encodeWithSelector(EnglishAuction.AuctionActive.selector, block.timestamp, block.timestamp + 1 days)
        );
        auction.sellerEndAuction(auctionId);
    }

    function test_Revert_SellerEndAuctionWhenReserveNotMet() public {
        uint256 auctionId = _deposit(sellerToken0, 5 ether, 1 days);

        _bid(alice, auctionId, 3 ether);
        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(EnglishAuction.ReserveNotMet.selector, 3 ether, 5 ether));
        auction.sellerEndAuction(auctionId);
    }

    function test_Revert_ReclaimUnsoldAuctionByNonSeller() public {
        uint256 auctionId = _deposit(sellerToken0, 5 ether, 1 days);

        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(alice);
        vm.expectRevert(EnglishAuction.Unauthorized.selector);
        auction.reclaimUnsoldAuction(auctionId);
    }

    function test_MultipleAuctionsStayIndependent() public {
        uint256 firstAuctionId = _deposit(sellerToken0, 2 ether, 2 days);
        uint256 secondAuctionId = _deposit(sellerToken1, 4 ether, 4 days);

        _bid(alice, firstAuctionId, 2 ether);
        _bid(bob, secondAuctionId, 3 ether);
        _bid(carol, secondAuctionId, 5 ether);

        assertEq(nft.ownerOf(sellerToken0), address(auction));
        assertEq(nft.ownerOf(sellerToken1), address(auction));
        assertEq(auction.refundableBids(secondAuctionId, bob), 3 ether);
        assertEq(auction.refundableBids(firstAuctionId, bob), 0);

        vm.warp(block.timestamp + 2 days + 1);
        vm.prank(seller);
        auction.sellerEndAuction(firstAuctionId);

        assertEq(nft.ownerOf(sellerToken0), alice);
        assertEq(nft.ownerOf(sellerToken1), address(auction));

        vm.warp(block.timestamp + 2 days);
        vm.prank(seller);
        auction.sellerEndAuction(secondAuctionId);

        assertEq(nft.ownerOf(sellerToken1), carol);
        assertEq(auction.sellerProceeds(seller), 7 ether);
    }
}
