// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {ERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/ERC20.sol";

import {FoundryNFT} from "../src/07-foundry-nft/FoundryNFT.sol";

/// @notice Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FoundryNFTTest is Test {
    FoundryNFT private nft;
    MockERC20 private token;

    address private user;
    address private owner;

    uint256 constant MINT_PRICE = 10 * 10 ** 18; // 10 tokens

    receive() external payable {}

    function setUp() public {
        owner = address(this);
        token = new MockERC20();
        nft = new FoundryNFT(address(token));
        user = address(0x1);

        // Give user some tokens
        token.mint(user, 1000 * 10 ** 18);
    }

    function test_Mint_OwnerOfAndBalanceOf() public {
        vm.startPrank(user);
        token.approve(address(nft), MINT_PRICE);
        nft.mint();
        vm.stopPrank();

        // ownerOf: the address that minted owns the NFT
        assertEq(nft.ownerOf(1), user, "ownerOf should be minter");

        // balanceOf: minter's balance becomes 1
        assertEq(nft.balanceOf(user), 1, "balanceOf minter should be 1");
    }

    function test_Mint_ContractBalanceIncreasesByPrice() public {
        uint256 contractBalanceBefore = token.balanceOf(address(nft));

        vm.startPrank(user);
        token.approve(address(nft), MINT_PRICE);
        nft.mint();
        vm.stopPrank();

        assertEq(
            token.balanceOf(address(nft)),
            contractBalanceBefore + MINT_PRICE,
            "contract balance should increase by mint price"
        );
    }

    function test_Withdraw_OwnerBalanceIncreases() public {
        vm.startPrank(user);
        token.approve(address(nft), MINT_PRICE);
        nft.mint();
        vm.stopPrank();

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 contractBalance = token.balanceOf(address(nft));

        nft.withdraw();

        assertEq(
            token.balanceOf(owner),
            ownerBalanceBefore + contractBalance,
            "owner token balance should increase by withdrawn amount"
        );
        assertEq(token.balanceOf(address(nft)), 0, "contract balance should be 0 after withdraw");
    }

    function test_MintMultiple() public {
        vm.startPrank(user);
        token.approve(address(nft), MINT_PRICE * 3);

        nft.mint();
        nft.mint();
        nft.mint();

        vm.stopPrank();

        assertEq(nft.totalSupply(), 3);
        assertEq(nft.ownerOf(1), user);
        assertEq(nft.ownerOf(2), user);
        assertEq(nft.ownerOf(3), user);
        assertEq(nft.balanceOf(user), 3);
    }

    function test_Mint_InsufficientBalanceReverts() public {
        address poorUser = address(0x2);
        // poorUser has no tokens

        vm.prank(poorUser);
        vm.expectRevert(FoundryNFT.InsufficientBalance.selector);
        nft.mint();
    }

    function test_Mint_InsufficientAllowanceReverts() public {
        vm.prank(user);
        // User has tokens but didn't approve
        vm.expectRevert(FoundryNFT.InsufficientAllowance.selector);
        nft.mint();
    }

    function test_TokenMetadata() public {
        vm.startPrank(user);
        token.approve(address(nft), MINT_PRICE);
        nft.mint();
        vm.stopPrank();

        assertEq(nft.name(), "FoundryNFT");
        assertEq(nft.symbol(), "FNFT");
    }

    function test_PaymentTokenIsSet() public view {
        assertEq(address(nft.paymentToken()), address(token));
    }
}
