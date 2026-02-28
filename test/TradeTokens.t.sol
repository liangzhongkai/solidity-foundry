// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";

import {SkillsCoin} from "../src/06-trade-tokens/SkillsCoin.sol";
import {RareCoin} from "../src/06-trade-tokens/RareCoin.sol";

contract TradeTokensTest is Test {
    SkillsCoin private skillsCoin;
    RareCoin private rareCoin;

    address private user;
    uint256 constant AMOUNT = 1000e18;

    function setUp() public {
        skillsCoin = new SkillsCoin();
        rareCoin = new RareCoin(address(skillsCoin));
        user = address(0x1);
    }

    function test_FullWorkflow() public {
        // 1. User mints SkillsCoin to themselves
        vm.prank(user);
        skillsCoin.mint(user, AMOUNT);
        assertEq(skillsCoin.balanceOf(user), AMOUNT, "user should have SkillsCoin");

        // 2. User approves RareCoin to spend their SkillsCoin
        vm.prank(user);
        skillsCoin.approve(address(rareCoin), AMOUNT);

        // 3. User calls trade
        vm.prank(user);
        rareCoin.trade(AMOUNT);

        // 4. Assert: RareCoin.balanceOf(user) == original SkillsCoin balance
        assertEq(rareCoin.balanceOf(user), AMOUNT, "user should have RareCoin equal to traded amount");

        // 5. Assert: RareCoin contract holds the SkillsCoin
        assertEq(skillsCoin.balanceOf(address(rareCoin)), AMOUNT, "RareCoin contract should hold SkillsCoin");

        // 6. Assert: User has no SkillsCoin left
        assertEq(skillsCoin.balanceOf(user), 0, "user should have no SkillsCoin");
    }

    function test_TradeWithoutApprovalReverts() public {
        vm.prank(user);
        skillsCoin.mint(user, AMOUNT);

        vm.prank(user);
        vm.expectRevert("call failed");
        rareCoin.trade(AMOUNT);
    }

    function test_TradePartialAmount() public {
        vm.prank(user);
        skillsCoin.mint(user, AMOUNT);

        uint256 tradeAmount = AMOUNT / 2;
        vm.prank(user);
        skillsCoin.approve(address(rareCoin), tradeAmount);

        vm.prank(user);
        rareCoin.trade(tradeAmount);

        assertEq(rareCoin.balanceOf(user), tradeAmount, "user should have half RareCoin");
        assertEq(skillsCoin.balanceOf(user), AMOUNT - tradeAmount, "user should have half SkillsCoin left");
        assertEq(skillsCoin.balanceOf(address(rareCoin)), tradeAmount, "RareCoin should hold half");
    }

    function test_AnyoneCanMintSkillsCoin() public {
        address alice = address(0xA11CE);
        address bob = address(0xB0B);

        vm.prank(alice);
        skillsCoin.mint(alice, 100e18);
        vm.prank(bob);
        skillsCoin.mint(bob, 200e18);

        assertEq(skillsCoin.balanceOf(alice), 100e18);
        assertEq(skillsCoin.balanceOf(bob), 200e18);
    }
}
