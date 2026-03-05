// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {ERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/ERC721.sol";
import {NFTSwap} from "../../src/09-nft-swap/NFTSwap.sol";

contract MockERC721 is ERC721 {
    uint256 internal _nextId;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function mint(address to) external returns (uint256 tokenId) {
        tokenId = _nextId++;
        _safeMint(to, tokenId);
    }
}

contract NFTSwapTest is Test {
    NFTSwap internal swapContract;
    MockERC721 internal nftA;
    MockERC721 internal nftB;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal charlie = makeAddr("charlie");

    uint256 internal aliceTokenA;
    uint256 internal bobTokenB;

    function setUp() public {
        swapContract = new NFTSwap();
        nftA = new MockERC721("NFTA", "NFTA");
        nftB = new MockERC721("NFTB", "NFTB");

        aliceTokenA = nftA.mint(alice);
        bobTokenB = nftB.mint(bob);

        vm.prank(alice);
        nftA.setApprovalForAll(address(swapContract), true);
        vm.prank(bob);
        nftB.setApprovalForAll(address(swapContract), true);
    }

    function _createSwap(address taker, uint64 lockPeriod) internal returns (uint256) {
        vm.prank(alice);
        return swapContract.createSwap(taker, address(nftA), aliceTokenA, address(nftB), bobTokenB, lockPeriod);
    }

    function test_CreateSwap() public {
        uint256 swapId = _createSwap(bob, 3 days);
        NFTSwap.Swap memory s = swapContract.getSwap(swapId);

        assertEq(s.maker, alice);
        assertEq(s.taker, bob);
        assertEq(s.makerNft.nft, address(nftA));
        assertEq(s.makerNft.tokenId, aliceTokenA);
        assertEq(s.takerNft.nft, address(nftB));
        assertEq(s.takerNft.tokenId, bobTokenB);
        assertEq(s.withdrawAfter, uint64(block.timestamp + 3 days));
    }

    function test_Revert_CreateSwapWithTooLargeLock() public {
        vm.prank(alice);
        vm.expectRevert(NFTSwap.InvalidLockPeriod.selector);
        swapContract.createSwap(bob, address(nftA), aliceTokenA, address(nftB), bobTokenB, type(uint64).max);
    }

    function test_MakerAndTakerDepositThenEitherCanSwap() public {
        uint256 swapId = _createSwap(bob, 0);

        vm.prank(alice);
        swapContract.depositMaker(swapId);
        vm.prank(bob);
        swapContract.depositTaker(swapId);

        vm.prank(bob);
        swapContract.swap(swapId);

        assertEq(nftA.ownerOf(aliceTokenA), bob);
        assertEq(nftB.ownerOf(bobTokenB), alice);
    }

    function test_OpenSwapFirstTakerGetsLocked() public {
        uint256 swapId = _createSwap(address(0), 0);

        vm.prank(bob);
        swapContract.depositTaker(swapId);

        NFTSwap.Swap memory s = swapContract.getSwap(swapId);
        assertEq(s.taker, bob);
    }

    function test_Revert_DepositMakerByOtherAddress() public {
        uint256 swapId = _createSwap(bob, 0);

        vm.prank(charlie);
        vm.expectRevert(NFTSwap.Unauthorized.selector);
        swapContract.depositMaker(swapId);
    }

    function test_Revert_DepositTakerByWrongAddress() public {
        uint256 swapId = _createSwap(bob, 0);

        vm.prank(charlie);
        vm.expectRevert(NFTSwap.Unauthorized.selector);
        swapContract.depositTaker(swapId);
    }

    function test_Revert_SwapWhenNotReady() public {
        uint256 swapId = _createSwap(bob, 0);

        vm.prank(alice);
        swapContract.depositMaker(swapId);

        vm.prank(alice);
        vm.expectRevert(NFTSwap.SwapNotReady.selector);
        swapContract.swap(swapId);
    }

    function test_TimeoutWithdrawalWhenCounterpartyNeverDeposits() public {
        uint256 swapId = _createSwap(bob, 2 days);

        vm.prank(alice);
        swapContract.depositMaker(swapId);

        vm.prank(alice);
        vm.expectRevert(NFTSwap.WithdrawalNotAllowedYet.selector);
        swapContract.withdraw(swapId);

        vm.warp(block.timestamp + 2 days + 1);

        vm.prank(alice);
        swapContract.withdraw(swapId);

        assertEq(nftA.ownerOf(aliceTokenA), alice);
    }

    function test_BothCanWithdrawOwnNFTAfterTimeoutIfNoSwap() public {
        uint256 swapId = _createSwap(bob, 1 days);

        vm.prank(alice);
        swapContract.depositMaker(swapId);
        vm.prank(bob);
        swapContract.depositTaker(swapId);

        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(alice);
        swapContract.withdraw(swapId);
        assertEq(nftA.ownerOf(aliceTokenA), alice);

        vm.prank(bob);
        swapContract.withdraw(swapId);
        assertEq(nftB.ownerOf(bobTokenB), bob);

        vm.expectRevert(NFTSwap.InvalidSwapId.selector);
        swapContract.getSwap(swapId);
    }
}
