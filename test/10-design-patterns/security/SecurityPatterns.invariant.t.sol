// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {CommonBase} from "forge-std@1.14.0/Base.sol";
import {StdCheats} from "forge-std@1.14.0/StdCheats.sol";
import {StdUtils} from "forge-std@1.14.0/StdUtils.sol";
import {SecurityPatterns} from "../../../src/10-design-patterns/security/SecurityPatterns.sol";

contract SecurityPatternsHandler is CommonBase, StdCheats, StdUtils {
    SecurityPatterns internal immutable sec;
    address internal immutable owner;
    address internal immutable guardian;
    address[] internal recipients;

    constructor(SecurityPatterns sec_, address owner_, address guardian_, address[] memory recipients_) {
        sec = sec_;
        owner = owner_;
        guardian = guardian_;
        recipients = recipients_;
    }

    function deposit(uint256 rawAmount) external {
        uint256 amount = bound(rawAmount, 1, 5 ether);
        hoax(owner, amount);
        try sec.deposit{value: amount}() {} catch {}
    }

    function queue(uint256 recipientSeed, uint256 rawAmount) external {
        address recipient = recipients[bound(recipientSeed, 0, recipients.length - 1)];
        uint256 surplus = address(sec).balance - sec.totalLiabilities();
        if (surplus == 0) return;

        uint256 amount = bound(rawAmount, 1, _min(surplus, 3 ether));
        vm.prank(guardian);
        try sec.queueWithdrawal(recipient, amount) {} catch {}
    }

    function withdraw(uint256 recipientSeed, uint64 warpBy) external {
        address recipient = recipients[bound(recipientSeed, 0, recipients.length - 1)];
        uint64 availableAt = sec.withdrawAvailableAt(recipient);
        if (availableAt == 0) return;

        vm.warp(block.timestamp + bound(uint256(warpBy), 0, 2 days));
        vm.prank(recipient);
        try sec.withdraw() {} catch {}
    }

    function setPauseFlags(uint8 flags) external {
        vm.prank(guardian);
        try sec.setPauseFlags(flags % 4) {} catch {}
    }

    function scheduleTermination() external {
        vm.prank(owner);
        try sec.scheduleTermination() {} catch {}
    }

    function terminate(uint256 rawAmount, uint64 warpBy) external {
        vm.warp(block.timestamp + bound(uint256(warpBy), 0, 3 days));
        uint256 surplus = address(sec).balance - sec.totalLiabilities();
        if (surplus == 0) return;

        uint256 amount = bound(rawAmount, 1, surplus);
        vm.prank(owner);
        try sec.terminateAndSweep(payable(owner), amount) {} catch {}
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

contract SecurityPatternsInvariantTest is Test {
    SecurityPatterns internal sec;
    SecurityPatternsHandler internal handler;

    address internal owner = address(0xAA01);
    address internal guardian = address(0xAA02);
    address internal alice = address(0xAA03);
    address internal bob = address(0xAA04);
    address internal carol = address(0xAA05);

    function setUp() public {
        SecurityPatterns.Config memory cfg = SecurityPatterns.Config({
            balanceCap: uint96(100 ether),
            epochLimit: uint96(10 ether),
            epochDuration: uint64(1 hours),
            withdrawalDelay: uint64(1 days),
            terminateDelay: uint64(2 days),
            deprecationTime: uint64(block.timestamp + 365 days)
        });

        vm.prank(owner);
        sec = new SecurityPatterns(guardian, cfg);

        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = carol;

        handler = new SecurityPatternsHandler(sec, owner, guardian, recipients);
        targetContract(address(handler));
    }

    function invariant_balance_covers_liabilities() public view {
        assertGe(address(sec).balance, sec.totalLiabilities());
    }

    function invariant_known_pending_sum_matches_liabilities() public view {
        uint256 knownLiabilities =
            sec.pendingWithdrawals(alice) + sec.pendingWithdrawals(bob) + sec.pendingWithdrawals(carol);
        assertEq(knownLiabilities, sec.totalLiabilities());
    }

    function invariant_termination_never_leaves_liabilities() public view {
        if (sec.isTerminated()) {
            assertEq(sec.totalLiabilities(), 0);
        }
    }

    function invariant_roles_are_stable() public view {
        assertEq(sec.owner(), owner);
        assertEq(sec.guardian(), guardian);
    }
}
