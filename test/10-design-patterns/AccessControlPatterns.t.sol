// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {EscrowJudge, EmbeddedPermission, DynamicBinding} from "../../src/10-design-patterns/AccessControlPatterns.sol";

contract MockLogic {
    address public logicDelegate;
    address public owner;
    uint256 public val;

    function setVal(uint256 _val) external {
        val = _val;
    }
}

contract AccessControlPatternsTest is Test {
    EscrowJudge internal escrow;
    EmbeddedPermission internal perm;
    DynamicBinding internal proxy;
    MockLogic internal logic1;
    MockLogic internal logic2;

    address internal buyer = address(0x1);
    address internal seller = address(0x2);
    address internal judge = address(0x3);

    function setUp() public {
        vm.prank(buyer);
        escrow = new EscrowJudge(seller, judge);

        perm = new EmbeddedPermission();

        logic1 = new MockLogic();
        logic2 = new MockLogic();
        proxy = new DynamicBinding(address(logic1));
    }

    function test_EscrowHappyPath() public {
        vm.deal(buyer, 1 ether);
        vm.prank(buyer);
        escrow.deposit{value: 1 ether}();

        uint256 sellerBal = seller.balance;
        vm.prank(buyer);
        escrow.confirmDelivery();

        assertEq(seller.balance, sellerBal + 1 ether);
        assertEq(uint256(escrow.state()), uint256(EscrowJudge.State.Completed));
    }

    function test_EscrowDispute() public {
        vm.deal(buyer, 1 ether);
        vm.prank(buyer);
        escrow.deposit{value: 1 ether}();

        vm.prank(seller);
        escrow.raiseDispute();

        uint256 buyerBal = buyer.balance;
        vm.prank(judge);
        escrow.resolveDispute(true); // refund buyer

        assertEq(buyer.balance, buyerBal + 1 ether);
    }

    function test_EmbeddedPermission() public {
        (address user, uint256 pk) = makeAddrAndKey("user");

        string memory action = "vote_yes";
        uint256 nonce = perm.nonces(user);

        bytes32 messageHash = keccak256(abi.encodePacked(user, action, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethSignedMessageHash);

        perm.executeWithSignature(user, action, v, r, s);
        assertEq(perm.nonces(user), 1);
    }

    function test_DynamicBinding() public {
        MockLogic proxied = MockLogic(address(proxy));
        proxied.setVal(100);
        assertEq(proxied.val(), 100);

        proxy.updateLogic(address(logic2));

        // Storage remains, logic changes
        assertEq(proxied.val(), 100);
        proxied.setVal(200);
        assertEq(proxied.val(), 200);
    }
}
