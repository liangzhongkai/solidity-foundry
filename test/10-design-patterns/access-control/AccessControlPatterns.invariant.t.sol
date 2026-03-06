// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {CommonBase} from "forge-std@1.14.0/Base.sol";
import {StdCheats} from "forge-std@1.14.0/StdCheats.sol";
import {StdUtils} from "forge-std@1.14.0/StdUtils.sol";
import {
    EscrowJudge,
    EmbeddedPermission,
    DynamicBinding
} from "../../../src/10-design-patterns/access-control/AccessControlPatterns.sol";

interface IInvariantProxyLogic {
    function val() external view returns (uint256);
    function setVal(uint256 newVal) external;
    function version() external view returns (uint256);
}

contract InvariantLogicV1 is IInvariantProxyLogic {
    uint256 public val;

    function setVal(uint256 newVal) external {
        val = newVal;
    }

    function version() external pure returns (uint256) {
        return 1;
    }
}

contract InvariantLogicV2 is IInvariantProxyLogic {
    uint256 public val;

    function setVal(uint256 newVal) external {
        val = newVal + 1;
    }

    function version() external pure returns (uint256) {
        return 2;
    }
}

contract AccessControlHandler is CommonBase, StdCheats, StdUtils {
    EscrowJudge internal immutable escrow;
    EmbeddedPermission internal immutable perm;
    DynamicBinding internal immutable proxy;
    address internal immutable buyer;
    address internal immutable seller;
    address internal immutable judge;
    address internal immutable permissionUser;
    uint256 internal immutable permissionUserPk;
    address internal immutable logic1;
    address internal immutable logic2;

    uint256 public successfulPermissionExecutions;

    constructor(
        EscrowJudge escrow_,
        EmbeddedPermission perm_,
        DynamicBinding proxy_,
        address buyer_,
        address seller_,
        address judge_,
        address permissionUser_,
        uint256 permissionUserPk_,
        address logic1_,
        address logic2_
    ) {
        escrow = escrow_;
        perm = perm_;
        proxy = proxy_;
        buyer = buyer_;
        seller = seller_;
        judge = judge_;
        permissionUser = permissionUser_;
        permissionUserPk = permissionUserPk_;
        logic1 = logic1_;
        logic2 = logic2_;
    }

    function escrowDeposit(uint256 rawAmount) external {
        uint256 amount = bound(rawAmount, 1, 5 ether);
        hoax(buyer, amount);
        try escrow.deposit{value: amount}() {} catch {}
    }

    function escrowRaiseDispute(bool sellerSide) external {
        vm.prank(sellerSide ? seller : buyer);
        try escrow.raiseDispute() {} catch {}
    }

    function escrowResolve(bool refundBuyer) external {
        vm.prank(judge);
        try escrow.resolveDispute(refundBuyer) {} catch {}
    }

    function escrowConfirmDelivery() external {
        vm.prank(buyer);
        try escrow.confirmDelivery() {} catch {}
    }

    function executePermission(bytes32 actionHash, uint64 ttl) external {
        uint256 deadline = block.timestamp + bound(uint256(ttl), 1, 7 days);
        uint256 nonce = perm.nonces(permissionUser);
        bytes32 digest = perm.permissionDigest(permissionUser, actionHash, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionUserPk, digest);

        try perm.executeWithSignature(permissionUser, actionHash, deadline, abi.encodePacked(r, s, v)) {
            unchecked {
                ++successfulPermissionExecutions;
            }
        } catch {}
    }

    function proxySetVal(uint256 newVal) external {
        IInvariantProxyLogic(address(proxy)).setVal(newVal);
    }

    function proxyUpgrade(bool useV2) external {
        address nextImplementation = useV2 ? logic2 : logic1;
        try proxy.upgradeTo(nextImplementation, "") {} catch {}
    }
}

contract AccessControlPatternsInvariantTest is Test {
    EscrowJudge internal escrow;
    EmbeddedPermission internal perm;
    DynamicBinding internal proxy;
    InvariantLogicV1 internal logic1;
    InvariantLogicV2 internal logic2;
    AccessControlHandler internal handler;

    address internal buyer = address(0x111);
    address internal seller = address(0x222);
    address internal judge = address(0x333);
    address internal permissionUser;
    uint256 internal permissionUserPk;

    function setUp() public {
        (permissionUser, permissionUserPk) = makeAddrAndKey("permission-user");

        vm.prank(buyer);
        escrow = new EscrowJudge(seller, judge);
        perm = new EmbeddedPermission();

        logic1 = new InvariantLogicV1();
        logic2 = new InvariantLogicV2();
        proxy = new DynamicBinding(address(this), address(logic1), "");

        handler = new AccessControlHandler(
            escrow,
            perm,
            proxy,
            buyer,
            seller,
            judge,
            permissionUser,
            permissionUserPk,
            address(logic1),
            address(logic2)
        );

        targetContract(address(handler));
    }

    function invariant_proxy_admin_is_stable() public view {
        assertEq(proxy.admin(), address(this));
    }

    function invariant_proxy_implementation_is_known() public view {
        address implementation = proxy.implementation();
        assertTrue(implementation == address(logic1) || implementation == address(logic2));

        uint256 version = IInvariantProxyLogic(address(proxy)).version();
        if (implementation == address(logic1)) {
            assertEq(version, 1);
        } else {
            assertEq(version, 2);
        }
    }

    function invariant_permission_nonce_matches_successes() public view {
        assertEq(perm.nonces(permissionUser), handler.successfulPermissionExecutions());
    }

    function invariant_escrow_roles_are_stable() public view {
        assertEq(escrow.buyer(), buyer);
        assertEq(escrow.seller(), seller);
        assertEq(escrow.judge(), judge);
    }

    function invariant_completed_or_empty_escrow_has_no_locked_amount() public view {
        EscrowJudge.State state = escrow.state();
        if (state == EscrowJudge.State.AwaitingPayment || state == EscrowJudge.State.Completed) {
            assertEq(escrow.amount(), 0);
        }
    }
}
