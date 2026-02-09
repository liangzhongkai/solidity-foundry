// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Wallet} from "../src/Wallet.sol";

// forge test --match-path test/Wallet.t.sol -vvvv

contract WalletTest is Test {
    Wallet public wallet;

    function setUp() public {
        // msg.sender = address(this)
        wallet = new Wallet();
    }

    function testSetOwner() public {
        wallet.setOwner(address(1));
        assertEq(wallet.owner(), address(1));
    }

    function test_Revert_WhenCallerIsNotOwner() public {
        vm.expectRevert("caller is not owner in setOwner");
        // set msg.sender to address(1)
        vm.prank(address(1));
        wallet.setOwner(address(1));
    }

    function test_Revert_WhenCallerIsNotOwnerAfterChange() public {
        console.log("owner", wallet.owner());

        // msg.sender = address(this)
        wallet.setOwner(address(1));

        // Set all subsequent msg.sender to address(1)
        vm.startPrank(address(1));

        // all calls made from address(1)
        wallet.setOwner(address(1));
        wallet.setOwner(address(1));
        wallet.setOwner(address(1));

        // Reset all subsequent msg.sender to address(this)
        vm.stopPrank();

        console.log("owner", wallet.owner());

        // call made from address(this) - this will fail since msg.sender is address(1)
        vm.expectRevert("caller is not owner in setOwner");
        wallet.setOwner(address(1));
    }
}
