// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {console} from "forge-std@1.14.0/console.sol";
import {Wallet} from "../src/Wallet.sol";

// forge test --match-path test/Wallet.t.sol -vvvv

contract WalletTest is Test {
    Wallet public wallet;

    function setUp() public {
        // msg.sender = address(this)
        wallet = new Wallet{value: 1e18}();
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

    // Receive ETH from wallet
    receive() external payable {}

    // Check how much ETH available for test
    function test_LogBalance() public view {
        console.log("ETH balance", address(this).balance / 1e18);
    }

    function _sendETH(uint256 _amount) internal {
        (bool success,) = payable(address(wallet)).call{value: _amount}("");
        require(success, "send ETH failed");
    }

    function test_SendETH() public {
        uint256 bal = address(wallet).balance;

        // deal
        deal(address(1), 100);
        assertEq(address(1).balance, 100);

        deal(address(1), 10);
        assertEq(address(1).balance, 10);

        // hoax = deal + prank
        // deal(address, uint) - Set balance of address
        // hoax(address, uint) - deal + prank, Sets up a prank and set balance
        deal(address(1), 124);
        vm.prank(address(1));
        _sendETH(124);

        hoax(address(1), 234);
        _sendETH(234);

        assertEq(address(wallet).balance, bal + 124 + 234);
    }
}
