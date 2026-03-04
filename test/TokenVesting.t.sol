// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {ERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";

import {TokenVesting} from "../src/08-vesting/TokenVesting.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenVestingTest is Test {
    MockERC20 private token;
    TokenVesting private vesting;

    address private payer;
    address private receiver;

    uint256 constant DEPOSIT_AMOUNT = 1000 * 10 ** 18;
    uint256 constant VESTING_DAYS = 10;

    function setUp() public {
        token = new MockERC20();
        payer = address(0x1);
        receiver = address(0x2);

        token.mint(payer, DEPOSIT_AMOUNT);
    }

    function _deployAndDeposit() internal returns (TokenVesting) {
        TokenVesting v = new TokenVesting(IERC20(address(token)), receiver, VESTING_DAYS);
        vm.startPrank(payer);
        token.approve(address(v), DEPOSIT_AMOUNT);
        v.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        return v;
    }

    function test_Deposit_StartsVesting() public {
        vesting = _deployAndDeposit();

        assertEq(vesting.totalAmount(), DEPOSIT_AMOUNT);
        assertEq(vesting.startTime(), block.timestamp);
        assertEq(vesting.vestingDays(), VESTING_DAYS);
        assertEq(token.balanceOf(address(vesting)), DEPOSIT_AMOUNT);
    }

    function test_VestedAmount_ZeroBeforeStart() public {
        vesting = new TokenVesting(IERC20(address(token)), receiver, VESTING_DAYS);
        uint256 t = block.timestamp;
        vm.startPrank(payer);
        token.approve(address(vesting), DEPOSIT_AMOUNT);
        vesting.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        assertEq(vesting.vestedAmountAt(t - 1), 0);
    }

    function test_VestedAmount_DiscretePerDay() public {
        vesting = _deployAndDeposit();
        uint256 start = vesting.startTime();
        uint256 duration = VESTING_DAYS * 1 days;

        // After 1 day: 1/10 vested
        assertEq(vesting.vestedAmountAt(start + 1 days), DEPOSIT_AMOUNT / 10);
        // After 5 days: 5/10 vested
        assertEq(vesting.vestedAmountAt(start + 5 days), DEPOSIT_AMOUNT * 5 / 10);
        // After 10 days: 100% vested
        assertEq(vesting.vestedAmountAt(start + duration), DEPOSIT_AMOUNT);
    }

    function test_VestedAmount_DiscreteNotContinuous() public {
        vesting = _deployAndDeposit();
        uint256 start = vesting.startTime();

        // Discrete: after 1.5 days, still only 1/10 vested (not 15%)
        assertEq(vesting.vestedAmountAt(start + 1 days + 12 hours), DEPOSIT_AMOUNT / 10);

        // After 9.9 days: still 9/10 vested
        assertEq(vesting.vestedAmountAt(start + 9 days + 23 hours), DEPOSIT_AMOUNT * 9 / 10);

        // Exactly 10 days: 100% vested
        assertEq(vesting.vestedAmountAt(start + 10 days), DEPOSIT_AMOUNT);
    }

    function test_Withdraw_AfterOneDay() public {
        vesting = _deployAndDeposit();
        uint256 start = vesting.startTime();

        vm.warp(start + 1 days);
        uint256 releasable = vesting.releasable();
        assertEq(releasable, DEPOSIT_AMOUNT / 10);

        uint256 receiverBalanceBefore = token.balanceOf(receiver);
        vm.prank(receiver);
        vesting.withdraw();

        assertEq(token.balanceOf(receiver), receiverBalanceBefore + releasable);
        assertEq(vesting.released(), releasable);
    }

    function test_Withdraw_1OverN_PerDay() public {
        vesting = _deployAndDeposit();
        uint256 start = vesting.startTime();

        vm.startPrank(receiver);

        for (uint256 day = 1; day <= VESTING_DAYS; day++) {
            vm.warp(start + day * 1 days);
            uint256 expected = (DEPOSIT_AMOUNT * day) / VESTING_DAYS - vesting.released();
            assertEq(vesting.releasable(), expected);

            vesting.withdraw();
            assertEq(vesting.released(), (DEPOSIT_AMOUNT * day) / VESTING_DAYS);
        }

        vm.stopPrank();
        assertEq(token.balanceOf(receiver), DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(address(vesting)), 0);
    }

    function test_Withdraw_NonReceiverReverts() public {
        vesting = _deployAndDeposit();
        vm.warp(vesting.startTime() + 1 days);

        vm.prank(payer);
        vm.expectRevert(TokenVesting.Unauthorized.selector);
        vesting.withdraw();
    }

    function test_Withdraw_NothingToReleaseReverts() public {
        vesting = _deployAndDeposit();
        // No time passed - nothing vested
        vm.prank(receiver);
        vm.expectRevert(bytes("nothing to release"));
        vesting.withdraw();
    }

    function test_Deposit_TwiceReverts() public {
        vesting = _deployAndDeposit();
        vm.prank(payer);
        token.mint(payer, DEPOSIT_AMOUNT);
        token.approve(address(vesting), DEPOSIT_AMOUNT);
        vm.expectRevert(TokenVesting.AlreadyDeposited.selector);
        vesting.deposit(DEPOSIT_AMOUNT);
    }

    function test_Withdraw_PartialReleases() public {
        vesting = _deployAndDeposit();
        uint256 start = vesting.startTime();

        vm.startPrank(receiver);

        vm.warp(start + 3 days);
        vesting.withdraw();
        uint256 after3 = token.balanceOf(receiver);
        assertEq(after3, DEPOSIT_AMOUNT * 3 / 10);

        vm.warp(start + 7 days);
        vesting.withdraw();
        uint256 after7 = token.balanceOf(receiver);
        assertEq(after7 - after3, DEPOSIT_AMOUNT * 4 / 10);

        vm.warp(start + 10 days);
        vesting.withdraw();
        assertEq(token.balanceOf(receiver), DEPOSIT_AMOUNT);

        vm.stopPrank();
    }
}
