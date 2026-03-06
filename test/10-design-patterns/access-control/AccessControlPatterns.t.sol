// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {
    EscrowJudge,
    EmbeddedPermission,
    DynamicBinding
} from "../../../src/10-design-patterns/access-control/AccessControlPatterns.sol";

interface IProxyLogic {
    function val() external view returns (uint256);
    function setVal(uint256 _val) external;
    function version() external view returns (uint256);
}

contract MockLogicV1 is IProxyLogic {
    uint256 public val;

    function setVal(uint256 _val) external {
        val = _val;
    }

    function version() external pure returns (uint256) {
        return 1;
    }
}

contract MockLogicV2 is IProxyLogic {
    uint256 public val;

    function setVal(uint256 _val) external {
        val = _val + 1;
    }

    function version() external pure returns (uint256) {
        return 2;
    }
}

contract Mock1271Signer {
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    address public immutable owner;

    constructor(address owner_) {
        owner = owner_;
    }

    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4) {
        if (signature.length != 65) {
            return bytes4(0);
        }

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        return ecrecover(hash, v, r, s) == owner ? MAGICVALUE : bytes4(0);
    }
}

contract AccessControlPatternsTest is Test {
    EscrowJudge internal escrow;
    EmbeddedPermission internal perm;
    DynamicBinding internal proxy;
    MockLogicV1 internal logic1;
    MockLogicV2 internal logic2;
    Mock1271Signer internal contractSigner;

    address internal buyer = address(0x1);
    address internal seller = address(0x2);
    address internal judge = address(0x3);
    address internal signerOwner;
    uint256 internal signerOwnerPk;

    function setUp() public {
        vm.prank(buyer);
        escrow = new EscrowJudge(seller, judge);

        perm = new EmbeddedPermission();
        (signerOwner, signerOwnerPk) = makeAddrAndKey("erc1271-owner");
        contractSigner = new Mock1271Signer(signerOwner);

        logic1 = new MockLogicV1();
        logic2 = new MockLogicV2();
        proxy = new DynamicBinding(address(this), address(logic1), "");
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

        bytes32 actionHash = keccak256("vote_yes");
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = perm.permissionDigest(user, actionHash, perm.nonces(user), deadline);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        perm.executeWithSignature(user, actionHash, deadline, signature);
        assertEq(perm.nonces(user), 1);
    }

    function test_EmbeddedPermission_ERC1271ContractSignature() public {
        bytes32 actionHash = keccak256("delegate_vote");
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest =
            perm.permissionDigest(address(contractSigner), actionHash, perm.nonces(address(contractSigner)), deadline);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerOwnerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        perm.executeWithSignature(address(contractSigner), actionHash, deadline, signature);
        assertEq(perm.nonces(address(contractSigner)), 1);
    }

    function test_EmbeddedPermission_ExpiredSignatureReverts() public {
        (address user, uint256 pk) = makeAddrAndKey("user");

        bytes32 actionHash = keccak256("vote_yes");
        uint256 deadline = block.timestamp + 1;
        bytes32 digest = perm.permissionDigest(user, actionHash, perm.nonces(user), deadline);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.warp(deadline + 1);
        vm.expectRevert(abi.encodeWithSelector(EmbeddedPermission.SignatureExpired.selector, deadline + 1, deadline));
        perm.executeWithSignature(user, actionHash, deadline, signature);
    }

    function test_EmbeddedPermission_InvalidERC1271SignatureReverts() public {
        bytes32 actionHash = keccak256("delegate_vote");
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest =
            perm.permissionDigest(address(contractSigner), actionHash, perm.nonces(address(contractSigner)), deadline);

        (address wrongSigner, uint256 wrongPk) = makeAddrAndKey("wrong-signer");
        wrongSigner;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(EmbeddedPermission.InvalidSignature.selector);
        perm.executeWithSignature(address(contractSigner), actionHash, deadline, signature);
    }

    function test_DynamicBinding() public {
        IProxyLogic proxied = IProxyLogic(address(proxy));
        proxied.setVal(100);
        assertEq(proxied.val(), 100);
        assertEq(proxied.version(), 1);

        proxy.upgradeTo(address(logic2), "");

        // Storage remains, logic changes
        assertEq(proxied.val(), 100);
        proxied.setVal(200);
        assertEq(proxied.val(), 201);
        assertEq(proxied.version(), 2);
    }

    function test_DynamicBinding_OnlyAdminCanUpgrade() public {
        vm.prank(buyer);
        vm.expectRevert(DynamicBinding.Unauthorized.selector);
        proxy.upgradeTo(address(logic2), "");
    }
}
