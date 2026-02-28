// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";

import {FoundryNFT} from "../src/07-foundry-nft/FoundryNFT.sol";

contract FoundryNFTTest is Test {
    FoundryNFT private nft;

    address private user;
    address private owner;

    uint256 constant MINT_PRICE = 0.01 ether;

    receive() external payable {}

    function setUp() public {
        owner = address(this);
        nft = new FoundryNFT();
        user = address(0x1);
    }

    function test_Mint_OwnerOfAndBalanceOf() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        nft.mint{value: MINT_PRICE}();

        // ownerOf: the address that minted owns the NFT
        assertEq(nft.ownerOf(1), user, "ownerOf should be minter");

        // balanceOf: minter's balance becomes 1
        assertEq(nft.balanceOf(user), 1, "balanceOf minter should be 1");
    }

    function test_Mint_ContractBalanceIncreasesByPrice() public {
        vm.deal(user, 1 ether);
        uint256 contractBalanceBefore = address(nft).balance;

        vm.prank(user);
        nft.mint{value: MINT_PRICE}();

        assertEq(
            address(nft).balance, contractBalanceBefore + MINT_PRICE, "contract balance should increase by mint price"
        );
    }

    function test_Withdraw_OwnerBalanceIncreases() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        nft.mint{value: MINT_PRICE}();

        uint256 ownerBalanceBefore = owner.balance;
        uint256 contractBalance = address(nft).balance;

        nft.withdraw();

        assertEq(
            owner.balance,
            ownerBalanceBefore + contractBalance,
            "owner Ether balance should increase by withdrawn amount"
        );
        assertEq(address(nft).balance, 0, "contract balance should be 0 after withdraw");
    }

    function test_MintMultiple() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);

        nft.mint{value: MINT_PRICE}();
        nft.mint{value: MINT_PRICE}();
        nft.mint{value: MINT_PRICE}();

        vm.stopPrank();

        assertEq(nft.totalSupply(), 3);
        assertEq(nft.ownerOf(1), user);
        assertEq(nft.ownerOf(2), user);
        assertEq(nft.ownerOf(3), user);
        assertEq(nft.balanceOf(user), 3);
    }

    function test_Mint_InsufficientPaymentReverts() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert(FoundryNFT.InsufficientPayment.selector);
        nft.mint{value: 0.001 ether}();
    }

    function test_TokenMetadata() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        nft.mint{value: MINT_PRICE}();

        assertEq(nft.name(), "FoundryNFT");
        assertEq(nft.symbol(), "FNFT");
    }
}
