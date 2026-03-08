// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {CloudCoin} from "../../src/14-stake-together/CloudCoin.sol";
import {StakeTogether} from "../../src/14-stake-together/StakeTogether.sol";

contract StakeTogetherTest is Test {
    StakeTogether public staking;
    CloudCoin public cloudCoin;

    address internal alice = address(0xA1);
    address internal bob = address(0xB2);
    address internal carol = address(0xC3);
    address internal deployer = address(0xD1);

    uint64 internal beginDate;
    uint64 internal expiration;
    uint256 internal constant REWARD_POOL = 1_000_000 * 10 ** 18;

    function setUp() public {
        cloudCoin = new CloudCoin();
        cloudCoin.mint(deployer, 2_000_000 * 10 ** 18);
        cloudCoin.mint(alice, 100_000 * 10 ** 18);
        cloudCoin.mint(bob, 100_000 * 10 ** 18);
        cloudCoin.mint(carol, 100_000 * 10 ** 18);

        beginDate = uint64(block.timestamp + 1 days);
        expiration = uint64(beginDate + 14 days);

        vm.prank(deployer);
        cloudCoin.transfer(address(this), REWARD_POOL);

        staking = new StakeTogether(IERC20(address(cloudCoin)), beginDate, expiration);
        cloudCoin.transfer(address(staking), REWARD_POOL);
    }

    function test_Constructor_SetsParams() public view {
        assertEq(address(staking.token()), address(cloudCoin));
        assertEq(staking.beginDate(), beginDate);
        assertEq(staking.expiration(), expiration);
        assertEq(cloudCoin.balanceOf(address(staking)), REWARD_POOL);
    }

    function test_Stake_HappyPath() public {
        vm.warp(beginDate);
        vm.prank(alice);
        cloudCoin.approve(address(staking), 5_000 * 10 ** 18);

        vm.prank(alice);
        staking.stake(5_000 * 10 ** 18);

        assertEq(staking.stakeOf(alice), 5_000 * 10 ** 18);
        assertEq(staking.totalStaked(), 5_000 * 10 ** 18);
        assertEq(cloudCoin.balanceOf(alice), 95_000 * 10 ** 18);
        assertEq(cloudCoin.balanceOf(address(staking)), REWARD_POOL + 5_000 * 10 ** 18);
    }

    function test_Stake_ProportionalReward_ExampleFromIssue() public {
        vm.warp(beginDate);
        vm.prank(alice);
        cloudCoin.approve(address(staking), 5_000 * 10 ** 18);
        vm.prank(bob);
        cloudCoin.approve(address(staking), 20_000 * 10 ** 18);

        vm.prank(alice);
        staking.stake(5_000 * 10 ** 18);

        vm.prank(bob);
        staking.stake(20_000 * 10 ** 18);

        assertEq(staking.totalStaked(), 25_000 * 10 ** 18);

        vm.warp(expiration + 1);

        uint256 aliceBalanceBefore = cloudCoin.balanceOf(alice);
        vm.prank(alice);
        staking.withdraw();
        uint256 aliceReceived = cloudCoin.balanceOf(alice) - aliceBalanceBefore;

        assertEq(aliceReceived, 5_000 * 10 ** 18 + 200_000 * 10 ** 18);
        assertEq(staking.stakeOf(alice), 0);
    }

    function test_Withdraw_ProportionalRewards() public {
        vm.warp(beginDate);
        vm.prank(alice);
        cloudCoin.approve(address(staking), 5_000 * 10 ** 18);
        vm.prank(bob);
        cloudCoin.approve(address(staking), 15_000 * 10 ** 18);
        vm.prank(alice);
        staking.stake(5_000 * 10 ** 18);
        vm.prank(bob);
        staking.stake(15_000 * 10 ** 18);

        vm.warp(expiration + 1);

        vm.prank(alice);
        staking.withdraw();
        assertEq(cloudCoin.balanceOf(alice), 95_000 * 10 ** 18 + 5_000 * 10 ** 18 + 250_000 * 10 ** 18);

        vm.prank(bob);
        staking.withdraw();
        assertEq(cloudCoin.balanceOf(bob), 85_000 * 10 ** 18 + 15_000 * 10 ** 18 + 750_000 * 10 ** 18);
    }

    function test_Stake_RevertsBeforeBeginDate() public {
        vm.warp(beginDate - 1);
        vm.prank(alice);
        cloudCoin.approve(address(staking), 1_000 * 10 ** 18);
        vm.prank(alice);
        vm.expectRevert(StakeTogether.StakingNotOpen.selector);
        staking.stake(1_000 * 10 ** 18);
    }

    function test_Stake_RevertsInLast7Days() public {
        vm.warp(beginDate);
        vm.prank(alice);
        cloudCoin.approve(address(staking), 1_000 * 10 ** 18);
        vm.prank(alice);
        staking.stake(1_000 * 10 ** 18);

        vm.warp(expiration - 6 days);
        vm.prank(bob);
        cloudCoin.approve(address(staking), 1_000 * 10 ** 18);
        vm.prank(bob);
        vm.expectRevert(StakeTogether.StakingWindowClosed.selector);
        staking.stake(1_000 * 10 ** 18);
    }

    function test_Stake_RevertsZeroAmount() public {
        vm.warp(beginDate);
        vm.prank(alice);
        vm.expectRevert(StakeTogether.ZeroAmount.selector);
        staking.stake(0);
    }

    function test_Withdraw_RevertsBeforeExpiration() public {
        vm.warp(beginDate);
        vm.prank(alice);
        cloudCoin.approve(address(staking), 1_000 * 10 ** 18);
        vm.prank(alice);
        staking.stake(1_000 * 10 ** 18);

        vm.warp(expiration - 1);
        vm.prank(alice);
        vm.expectRevert(StakeTogether.NotExpired.selector);
        staking.withdraw();
    }

    function test_Withdraw_RevertsNothingStaked() public {
        vm.warp(expiration + 1);
        vm.prank(alice);
        vm.expectRevert(StakeTogether.NothingToWithdraw.selector);
        staking.withdraw();
    }

    function test_Withdraw_RevertsDoubleWithdraw() public {
        vm.warp(beginDate);
        vm.prank(alice);
        cloudCoin.approve(address(staking), 1_000 * 10 ** 18);
        vm.prank(alice);
        staking.stake(1_000 * 10 ** 18);

        vm.warp(expiration + 1);
        vm.prank(alice);
        staking.withdraw();

        vm.prank(alice);
        vm.expectRevert(StakeTogether.NothingToWithdraw.selector);
        staking.withdraw();
    }

    function test_Stake_RevertsInsufficientRewardPool() public {
        CloudCoin cc = new CloudCoin();
        cc.mint(alice, 100_000 * 10 ** 18);
        StakeTogether s = new StakeTogether(IERC20(address(cc)), beginDate, expiration);
        vm.warp(beginDate);
        vm.prank(alice);
        vm.expectRevert(StakeTogether.InsufficientRewardPool.selector);
        s.stake(1_000 * 10 ** 18);
    }

    function test_Constructor_RevertsExpirationBeforeBeginDate() public {
        vm.expectRevert(StakeTogether.StakingNotOpen.selector);
        new StakeTogether(IERC20(address(cloudCoin)), beginDate, uint64(beginDate));
    }

    function test_Constructor_RevertsPeriodShorterThan7Days() public {
        uint64 shortExpiration = uint64(beginDate + 6 days);
        cloudCoin.transfer(address(this), REWARD_POOL);
        vm.expectRevert(StakeTogether.StakingNotOpen.selector);
        new StakeTogether(IERC20(address(cloudCoin)), beginDate, shortExpiration);
    }

    function test_Attack_LastMinuteStake_Blocked() public {
        vm.warp(beginDate);
        vm.prank(alice);
        cloudCoin.approve(address(staking), 10_000 * 10 ** 18);
        vm.prank(alice);
        staking.stake(10_000 * 10 ** 18);

        vm.warp(expiration - 1);
        vm.prank(bob);
        cloudCoin.approve(address(staking), 1_000_000 * 10 ** 18);
        vm.prank(bob);
        vm.expectRevert(StakeTogether.StakingWindowClosed.selector);
        staking.stake(1_000_000 * 10 ** 18);
    }

    function test_Attack_StakeExactlyAtDeadline_Blocked() public {
        vm.warp(beginDate);
        vm.prank(alice);
        cloudCoin.approve(address(staking), 1_000 * 10 ** 18);
        vm.prank(alice);
        staking.stake(1_000 * 10 ** 18);

        vm.warp(expiration - 7 days + 1);
        vm.prank(bob);
        cloudCoin.approve(address(staking), 1_000 * 10 ** 18);
        vm.prank(bob);
        vm.expectRevert(StakeTogether.StakingWindowClosed.selector);
        staking.stake(1_000 * 10 ** 18);
    }

    function test_PreviewReward_AfterExpiration() public {
        vm.warp(beginDate);
        vm.prank(alice);
        cloudCoin.approve(address(staking), 5_000 * 10 ** 18);
        vm.prank(bob);
        cloudCoin.approve(address(staking), 20_000 * 10 ** 18);
        vm.prank(alice);
        staking.stake(5_000 * 10 ** 18);
        vm.prank(bob);
        staking.stake(20_000 * 10 ** 18);

        vm.warp(expiration + 1);
        assertEq(staking.previewReward(alice), 200_000 * 10 ** 18);
        assertEq(staking.previewReward(bob), 800_000 * 10 ** 18);
    }

    function test_MultipleStakes_Accumulate() public {
        vm.warp(beginDate);
        vm.prank(alice);
        cloudCoin.approve(address(staking), 5_000 * 10 ** 18);
        vm.prank(alice);
        staking.stake(2_000 * 10 ** 18);
        vm.prank(alice);
        staking.stake(3_000 * 10 ** 18);

        assertEq(staking.stakeOf(alice), 5_000 * 10 ** 18);
        assertEq(staking.totalStaked(), 5_000 * 10 ** 18);
    }
}
