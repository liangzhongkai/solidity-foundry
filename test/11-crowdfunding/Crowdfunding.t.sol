// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {ERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/ERC20.sol";

import {Crowdfunding} from "../../src/11-crowdfunding/Crowdfunding.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract CrowdfundingTest is Test {
    Crowdfunding internal crowdfunding;
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;

    address internal creatorA = address(0xA1);
    address internal creatorB = address(0xB2);
    address internal donorA = address(0xD1);
    address internal donorB = address(0xD2);
    address internal outsider = address(0xEE);

    function setUp() public {
        crowdfunding = new Crowdfunding();
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");

        vm.deal(creatorA, 10 ether);
        vm.deal(creatorB, 10 ether);
        vm.deal(donorA, 10 ether);
        vm.deal(donorB, 10 ether);
        vm.deal(outsider, 10 ether);

        tokenA.mint(donorA, 1000e18);
        tokenA.mint(donorB, 1000e18);
        tokenB.mint(donorA, 1000e18);
        tokenB.mint(donorB, 1000e18);
    }

    function test_CreateEthFundraiser_SetsFields() public {
        uint256 deadline = block.timestamp + 7 days;

        vm.prank(creatorA);
        uint256 fundraiserId = crowdfunding.createFundraiser(5 ether, deadline);

        (address creator, address token, uint256 goal, uint256 storedDeadline, uint256 totalRaised, bool withdrawn) =
            crowdfunding.fundraisers(fundraiserId);

        assertEq(fundraiserId, 1);
        assertEq(creator, creatorA);
        assertEq(token, address(0));
        assertEq(goal, 5 ether);
        assertEq(storedDeadline, deadline);
        assertEq(totalRaised, 0);
        assertFalse(withdrawn);
    }

    function test_CreateTokenFundraiser_SetsFields() public {
        uint256 deadline = block.timestamp + 7 days;

        vm.prank(creatorA);
        uint256 fundraiserId = crowdfunding.createFundraiser(address(tokenA), 500e18, deadline);

        (address creator, address token, uint256 goal, uint256 storedDeadline, uint256 totalRaised, bool withdrawn) =
            crowdfunding.fundraisers(fundraiserId);

        assertEq(fundraiserId, 1);
        assertEq(creator, creatorA);
        assertEq(token, address(tokenA));
        assertEq(goal, 500e18);
        assertEq(storedDeadline, deadline);
        assertEq(totalRaised, 0);
        assertFalse(withdrawn);
    }

    function test_EthDonate_MultipleTimesSameDonorAccumulates() public {
        uint256 fundraiserId = _createEthFundraiser(creatorA, 5 ether, block.timestamp + 7 days);

        vm.prank(donorA);
        crowdfunding.donate{value: 1 ether}(fundraiserId);

        vm.prank(donorA);
        crowdfunding.donate{value: 2 ether}(fundraiserId);

        assertEq(crowdfunding.donationOf(fundraiserId, donorA), 3 ether);
        (,,,, uint256 totalRaised,) = crowdfunding.fundraisers(fundraiserId);
        assertEq(totalRaised, 3 ether);
    }

    function test_EthDonate_SameDonorDifferentCampaignsStayIsolated() public {
        uint256 firstId = _createEthFundraiser(creatorA, 5 ether, block.timestamp + 7 days);
        uint256 secondId = _createEthFundraiser(creatorB, 3 ether, block.timestamp + 10 days);

        vm.startPrank(donorA);
        crowdfunding.donate{value: 1 ether}(firstId);
        crowdfunding.donate{value: 2 ether}(secondId);
        vm.stopPrank();

        assertEq(crowdfunding.donationOf(firstId, donorA), 1 ether);
        assertEq(crowdfunding.donationOf(secondId, donorA), 2 ether);
    }

    function test_EthWithdraw_CreatorGetsAllFundsAfterGoalReached() public {
        uint256 fundraiserId = _createEthFundraiser(creatorA, 5 ether, block.timestamp + 7 days);

        vm.prank(donorA);
        crowdfunding.donate{value: 2 ether}(fundraiserId);
        vm.prank(donorA);
        crowdfunding.donate{value: 1 ether}(fundraiserId);
        vm.prank(donorB);
        crowdfunding.donate{value: 2 ether}(fundraiserId);

        uint256 creatorBalanceBefore = creatorA.balance;

        vm.prank(creatorA);
        crowdfunding.withdraw(fundraiserId);

        assertEq(creatorA.balance, creatorBalanceBefore + 5 ether);
        assertEq(address(crowdfunding).balance, 0);
    }

    function test_EthRefund_ReturnsAccumulatedDonationAfterFailedCampaign() public {
        uint256 fundraiserId = _createEthFundraiser(creatorA, 5 ether, block.timestamp + 1 days);

        vm.prank(donorA);
        crowdfunding.donate{value: 1 ether}(fundraiserId);
        vm.prank(donorA);
        crowdfunding.donate{value: 2 ether}(fundraiserId);
        vm.prank(donorB);
        crowdfunding.donate{value: 1 ether}(fundraiserId);

        vm.warp(block.timestamp + 1 days + 1);

        uint256 donorBalanceBefore = donorA.balance;

        vm.prank(donorA);
        crowdfunding.refund(fundraiserId);

        assertEq(donorA.balance, donorBalanceBefore + 3 ether);
        assertEq(crowdfunding.donationOf(fundraiserId, donorA), 0);
        assertEq(address(crowdfunding).balance, 1 ether);
    }

    function test_Erc20Donate_MultipleTimesSameDonorAccumulates() public {
        uint256 fundraiserId = _createTokenFundraiser(creatorA, address(tokenA), 500e18, block.timestamp + 7 days);

        vm.startPrank(donorA);
        tokenA.approve(address(crowdfunding), type(uint256).max);
        crowdfunding.donate(fundraiserId, 100e18);
        crowdfunding.donate(fundraiserId, 200e18);
        vm.stopPrank();

        assertEq(crowdfunding.donationOf(fundraiserId, donorA), 300e18);
        (,,,, uint256 totalRaised,) = crowdfunding.fundraisers(fundraiserId);
        assertEq(totalRaised, 300e18);
        assertEq(tokenA.balanceOf(address(crowdfunding)), 300e18);
    }

    function test_Erc20Donate_SameDonorDifferentCampaignsStayIsolated() public {
        uint256 firstId = _createTokenFundraiser(creatorA, address(tokenA), 500e18, block.timestamp + 7 days);
        uint256 secondId = _createTokenFundraiser(creatorB, address(tokenB), 400e18, block.timestamp + 7 days);

        vm.startPrank(donorA);
        tokenA.approve(address(crowdfunding), type(uint256).max);
        tokenB.approve(address(crowdfunding), type(uint256).max);
        crowdfunding.donate(firstId, 100e18);
        crowdfunding.donate(secondId, 200e18);
        vm.stopPrank();

        assertEq(crowdfunding.donationOf(firstId, donorA), 100e18);
        assertEq(crowdfunding.donationOf(secondId, donorA), 200e18);
        assertEq(tokenA.balanceOf(address(crowdfunding)), 100e18);
        assertEq(tokenB.balanceOf(address(crowdfunding)), 200e18);
    }

    function test_Erc20Withdraw_CreatorGetsAllFundsAfterGoalReached() public {
        uint256 fundraiserId = _createTokenFundraiser(creatorA, address(tokenA), 500e18, block.timestamp + 7 days);

        vm.startPrank(donorA);
        tokenA.approve(address(crowdfunding), type(uint256).max);
        crowdfunding.donate(fundraiserId, 200e18);
        crowdfunding.donate(fundraiserId, 100e18);
        vm.stopPrank();

        vm.startPrank(donorB);
        tokenA.approve(address(crowdfunding), type(uint256).max);
        crowdfunding.donate(fundraiserId, 200e18);
        vm.stopPrank();

        uint256 creatorBalanceBefore = tokenA.balanceOf(creatorA);

        vm.prank(creatorA);
        crowdfunding.withdraw(fundraiserId);

        assertEq(tokenA.balanceOf(creatorA), creatorBalanceBefore + 500e18);
        assertEq(tokenA.balanceOf(address(crowdfunding)), 0);
    }

    function test_Erc20Refund_ReturnsAccumulatedDonationAfterFailedCampaign() public {
        uint256 fundraiserId = _createTokenFundraiser(creatorA, address(tokenA), 500e18, block.timestamp + 1 days);

        vm.startPrank(donorA);
        tokenA.approve(address(crowdfunding), type(uint256).max);
        crowdfunding.donate(fundraiserId, 100e18);
        crowdfunding.donate(fundraiserId, 200e18);
        vm.stopPrank();

        vm.startPrank(donorB);
        tokenA.approve(address(crowdfunding), 100e18);
        crowdfunding.donate(fundraiserId, 100e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days + 1);

        uint256 donorBalanceBefore = tokenA.balanceOf(donorA);

        vm.prank(donorA);
        crowdfunding.refund(fundraiserId);

        assertEq(tokenA.balanceOf(donorA), donorBalanceBefore + 300e18);
        assertEq(crowdfunding.donationOf(fundraiserId, donorA), 0);
        assertEq(tokenA.balanceOf(address(crowdfunding)), 100e18);
    }

    function test_UnauthorizedWithdrawReverts() public {
        uint256 ethFundraiserId = _createEthFundraiser(creatorA, 1 ether, block.timestamp + 7 days);
        uint256 tokenFundraiserId = _createTokenFundraiser(creatorB, address(tokenA), 100e18, block.timestamp + 7 days);

        vm.prank(donorA);
        crowdfunding.donate{value: 1 ether}(ethFundraiserId);

        vm.startPrank(donorA);
        tokenA.approve(address(crowdfunding), 100e18);
        crowdfunding.donate(tokenFundraiserId, 100e18);
        vm.stopPrank();

        vm.prank(outsider);
        vm.expectRevert(Crowdfunding.Unauthorized.selector);
        crowdfunding.withdraw(ethFundraiserId);

        vm.prank(outsider);
        vm.expectRevert(Crowdfunding.Unauthorized.selector);
        crowdfunding.withdraw(tokenFundraiserId);
    }

    function test_WrongAssetTypeReverts() public {
        uint256 ethFundraiserId = _createEthFundraiser(creatorA, 1 ether, block.timestamp + 7 days);
        uint256 tokenFundraiserId = _createTokenFundraiser(creatorB, address(tokenA), 100e18, block.timestamp + 7 days);

        vm.prank(donorA);
        vm.expectRevert(Crowdfunding.WrongAssetType.selector);
        crowdfunding.donate(ethFundraiserId, 100e18);

        vm.prank(donorA);
        vm.expectRevert(Crowdfunding.WrongAssetType.selector);
        crowdfunding.donate{value: 1 ether}(tokenFundraiserId);
    }

    function test_Refund_BeforeDeadlineReverts() public {
        uint256 deadline = block.timestamp + 1 days;
        uint256 fundraiserId = _createEthFundraiser(creatorA, 5 ether, deadline);

        vm.prank(donorA);
        crowdfunding.donate{value: 1 ether}(fundraiserId);

        vm.prank(donorA);
        vm.expectRevert(abi.encodeWithSelector(Crowdfunding.FundraiserActive.selector, block.timestamp, deadline));
        crowdfunding.refund(fundraiserId);
    }

    function test_Donate_AfterDeadlineReverts() public {
        uint256 deadline = block.timestamp + 1 days;
        uint256 fundraiserId = _createTokenFundraiser(creatorA, address(tokenA), 100e18, deadline);

        vm.warp(deadline + 1);

        vm.startPrank(donorA);
        tokenA.approve(address(crowdfunding), 100e18);
        vm.expectRevert(abi.encodeWithSelector(Crowdfunding.FundraiserEnded.selector, deadline + 1, deadline));
        crowdfunding.donate(fundraiserId, 100e18);
        vm.stopPrank();
    }

    function _createEthFundraiser(address creator, uint256 goal, uint256 deadline)
        internal
        returns (uint256 fundraiserId)
    {
        vm.prank(creator);
        fundraiserId = crowdfunding.createFundraiser(goal, deadline);
    }

    function _createTokenFundraiser(address creator, address token, uint256 goal, uint256 deadline)
        internal
        returns (uint256 fundraiserId)
    {
        vm.prank(creator);
        fundraiserId = crowdfunding.createFundraiser(token, goal, deadline);
    }
}
