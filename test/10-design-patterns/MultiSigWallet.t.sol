// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {MultiSigWallet} from "../../src/10-design-patterns/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet internal wallet;
    address[] internal owners;
    address internal owner1 = address(0x1);
    address internal owner2 = address(0x2);
    address internal owner3 = address(0x3);
    address internal nonOwner = address(0x4);
    address internal receiver = address(0x5);

    function setUp() public {
        owners.push(owner1);
        owners.push(owner2);
        owners.push(owner3);
        wallet = new MultiSigWallet(owners, 2);
        vm.deal(address(wallet), 10 ether);
    }

    function test_SubmitTransaction() public {
        vm.prank(owner1);
        wallet.submitTransaction(receiver, 1 ether, "");
        assertEq(wallet.getTransactionCount(), 1);
    }

    function test_SubmitTransactionUnauthorized() public {
        vm.prank(nonOwner);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        wallet.submitTransaction(receiver, 1 ether, "");
    }

    function test_ConfirmAndExecuteTransaction() public {
        vm.prank(owner1);
        wallet.submitTransaction(receiver, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        uint256 receiverBalBefore = receiver.balance;

        vm.prank(owner1);
        wallet.executeTransaction(0);

        assertEq(receiver.balance, receiverBalBefore + 1 ether);
    }

    function test_ExecuteWithoutEnoughConfirmationsReverts() public {
        vm.prank(owner1);
        wallet.submitTransaction(receiver, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(MultiSigWallet.CannotExecuteTx.selector);
        wallet.executeTransaction(0);
    }

    function test_RevokeConfirmation() public {
        vm.prank(owner1);
        wallet.submitTransaction(receiver, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        wallet.revokeConfirmation(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(MultiSigWallet.CannotExecuteTx.selector);
        wallet.executeTransaction(0);
    }
}
