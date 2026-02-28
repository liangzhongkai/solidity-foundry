// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {ProductionERC20} from "../src/02-erc20/ProductionERC20.sol";

contract ProductionERC20Test is Test {
    ProductionERC20 public token;
    address public owner;
    address public addr1;
    address public addr2;

    string constant TOKEN_NAME = "Production Token";
    string constant TOKEN_SYMBOL = "PRD";
    uint8 constant TOKEN_DECIMALS = 18;
    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        owner = address(this);
        addr1 = address(0x1);
        addr2 = address(0x2);

        vm.deal(owner, 100 ether);
        vm.deal(addr1, 100 ether);
        vm.deal(addr2, 100 ether);

        token = new ProductionERC20(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS, INITIAL_SUPPLY, owner);
    }

    // ============================================================
    // 1. Transfer 基础功能测试
    // ============================================================

    function test_Transfer_ShouldUpdateBalance() public {
        uint256 transferAmount = 100 ether;

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 addr1BalanceBefore = token.balanceOf(addr1);

        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, transferAmount);

        assertEq(token.balanceOf(owner), ownerBalanceBefore - transferAmount);
        assertEq(token.balanceOf(addr1), addr1BalanceBefore + transferAmount);
    }

    function test_Transfer_ShouldEmitTransferEvent() public {
        uint256 transferAmount = 100 ether;

        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, addr1, transferAmount);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, transferAmount);
    }

    function test_Transfer_InsufficientBalance() public {
        uint256 transferAmount = 999_999_999 ether;

        vm.expectRevert(abi.encodeWithSelector(ProductionERC20.InsufficientBalance.selector, addr1, transferAmount, 0));
        vm.prank(addr1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr2, transferAmount);
    }

    function test_Transfer_ToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ProductionERC20.InvalidRecipient.selector, address(0)));
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(address(0), 1 ether);
    }

    // ============================================================
    // 2. Approve & TransferFrom 完整流程
    // ============================================================

    uint256 constant DEFAULT_APPROVE_AMOUNT = 1000 ether;
    uint256 constant DEFAULT_TRANSFER_AMOUNT = 500 ether;

    function test_ApproveAndTransferFrom_CompleteFlow() public {
        token.approve(addr1, DEFAULT_APPROVE_AMOUNT);
        assertEq(token.allowance(owner, addr1), DEFAULT_APPROVE_AMOUNT);

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 addr2BalanceBefore = token.balanceOf(addr2);

        vm.prank(addr1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(owner, addr2, DEFAULT_TRANSFER_AMOUNT);

        assertEq(token.balanceOf(owner), ownerBalanceBefore - DEFAULT_TRANSFER_AMOUNT);
        assertEq(token.balanceOf(addr2), addr2BalanceBefore + DEFAULT_TRANSFER_AMOUNT);
    }

    function test_TransferFrom_ShouldDecreaseAllowance() public {
        token.approve(addr1, DEFAULT_APPROVE_AMOUNT);

        vm.prank(addr1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(owner, addr2, DEFAULT_TRANSFER_AMOUNT);

        assertEq(token.allowance(owner, addr1), DEFAULT_APPROVE_AMOUNT - DEFAULT_TRANSFER_AMOUNT);
    }

    function test_TransferFrom_ShouldEmitTransferEvent() public {
        token.approve(addr1, DEFAULT_APPROVE_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, addr2, DEFAULT_TRANSFER_AMOUNT);
        vm.prank(addr1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(owner, addr2, DEFAULT_TRANSFER_AMOUNT);
    }

    function test_TransferFrom_InsufficientAllowance() public {
        uint256 tooMuchAmount = 2000 ether;
        token.approve(addr1, DEFAULT_APPROVE_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                ProductionERC20.InsufficientAllowance.selector, owner, addr1, tooMuchAmount, DEFAULT_APPROVE_AMOUNT
            )
        );
        vm.prank(addr1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(owner, addr2, tooMuchAmount);
    }

    function test_Approve_ToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ProductionERC20.ApprovalToZeroAddress.selector));
        token.approve(address(0), DEFAULT_APPROVE_AMOUNT);
    }

    // ============================================================
    // 3. Allowance 变化测试
    // ============================================================

    uint256 constant INITIAL_AMOUNT = 500 ether;
    uint256 constant INCREASE_AMOUNT = 300 ether;
    uint256 constant DECREASE_AMOUNT = 200 ether;

    function test_IncreaseAllowance_ShouldIncrease() public {
        token.approve(addr1, INITIAL_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit Approval(owner, addr1, INITIAL_AMOUNT + INCREASE_AMOUNT);
        token.increaseAllowance(addr1, INCREASE_AMOUNT);

        assertEq(token.allowance(owner, addr1), INITIAL_AMOUNT + INCREASE_AMOUNT);
    }

    function test_DecreaseAllowance_ShouldDecrease() public {
        token.approve(addr1, INITIAL_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit Approval(owner, addr1, INITIAL_AMOUNT - DECREASE_AMOUNT);
        token.decreaseAllowance(addr1, DECREASE_AMOUNT);

        assertEq(token.allowance(owner, addr1), INITIAL_AMOUNT - DECREASE_AMOUNT);
    }

    function test_DecreaseAllowance_BelowZero() public {
        uint256 tooMuchDecrease = 1000 ether;
        token.approve(addr1, INITIAL_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                ProductionERC20.InsufficientAllowance.selector, owner, addr1, tooMuchDecrease, INITIAL_AMOUNT
            )
        );
        token.decreaseAllowance(addr1, tooMuchDecrease);
    }

    // ============================================================
    // 4. 事件触发测试
    // ============================================================

    function test_Transfer_Event() public {
        uint256 amount = 100 ether;

        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, addr1, amount);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, amount);
    }

    function test_Approval_Event() public {
        uint256 amount = 500 ether;

        vm.expectEmit(true, true, false, true);
        emit Approval(owner, addr1, amount);
        token.approve(addr1, amount);
    }

    // ============================================================
    // 5. 边界条件测试
    // ============================================================

    function test_Transfer_ZeroAmount() public {
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 addr1BalanceBefore = token.balanceOf(addr1);

        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, 0);

        assertEq(token.balanceOf(owner), ownerBalanceBefore);
        assertEq(token.balanceOf(addr1), addr1BalanceBefore);
    }

    function test_Transfer_AllBalance() public {
        uint256 fullBalance = token.balanceOf(owner);

        uint256 addr1BalanceBefore = token.balanceOf(addr1);

        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, fullBalance);

        assertEq(token.balanceOf(owner), 0);
        assertEq(token.balanceOf(addr1), addr1BalanceBefore + fullBalance);
    }

    function test_Approve_MaxUint256() public {
        uint256 maxUint256 = type(uint256).max;

        token.approve(addr1, maxUint256);
        assertEq(token.allowance(owner, addr1), maxUint256);
    }

    function test_Approve_ZeroAmount() public {
        token.approve(addr1, 0);
        assertEq(token.allowance(owner, addr1), 0);
    }

    // ============================================================
    // 6. 复杂业务场景
    // ============================================================

    function test_MultiTransfer() public {
        uint256 amount1 = 100 ether;
        uint256 amount2 = 200 ether;
        uint256 amount3 = 50 ether;

        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, amount1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr2, amount2);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, amount3);

        assertEq(token.balanceOf(addr1), amount1 + amount3);
        assertEq(token.balanceOf(addr2), amount2);
    }

    function test_Repeated_Approve() public {
        uint256 firstApprove = 100 ether;
        uint256 secondApprove = 200 ether;

        token.approve(addr1, firstApprove);
        token.approve(addr1, secondApprove);

        assertEq(token.allowance(owner, addr1), secondApprove);
    }

    // ============================================================
    // 7. Burn 功能测试
    // ============================================================

    uint256 constant BURN_AMOUNT = 100 ether;

    function test_Burn_OwnTokens() public {
        // 给 addr1 转账用于测试
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, 1000 ether);

        uint256 addr1BalanceBefore = token.balanceOf(addr1);
        uint256 totalSupplyBefore = token.totalSupply();

        vm.prank(addr1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(addr1, address(0), BURN_AMOUNT);
        token.burn(BURN_AMOUNT);

        assertEq(token.balanceOf(addr1), addr1BalanceBefore - BURN_AMOUNT);
        assertEq(token.totalSupply(), totalSupplyBefore - BURN_AMOUNT);
    }

    function test_Burn_InsufficientBalance() public {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, 1000 ether);

        uint256 hugeAmount = 999_999 ether;

        vm.expectRevert(
            abi.encodeWithSelector(ProductionERC20.InsufficientBalance.selector, addr1, hugeAmount, 1000 ether)
        );
        vm.prank(addr1);
        token.burn(hugeAmount);
    }

    function test_Burn_AllBalance() public {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, 1000 ether);

        uint256 balance = token.balanceOf(addr1);
        uint256 totalSupplyBefore = token.totalSupply();

        vm.prank(addr1);
        token.burn(balance);

        assertEq(token.balanceOf(addr1), 0);
        assertEq(token.totalSupply(), totalSupplyBefore - balance);
    }

    function test_Burn_ZeroAmount() public {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, 1000 ether);

        vm.prank(addr1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(addr1, address(0), 0);
        token.burn(0);
    }

    function test_BurnFrom_WithAllowance() public {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, 1000 ether);

        vm.prank(addr1);
        token.approve(owner, BURN_AMOUNT);

        uint256 addr1BalanceBefore = token.balanceOf(addr1);
        uint256 totalSupplyBefore = token.totalSupply();

        vm.expectEmit(true, true, false, true);
        emit Transfer(addr1, address(0), BURN_AMOUNT);
        token.burnFrom(addr1, BURN_AMOUNT);

        assertEq(token.balanceOf(addr1), addr1BalanceBefore - BURN_AMOUNT);
        assertEq(token.totalSupply(), totalSupplyBefore - BURN_AMOUNT);
        assertEq(token.allowance(addr1, owner), 0);
    }

    function test_BurnFrom_InsufficientAllowance() public {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, 1000 ether);

        uint256 smallApproval = 50 ether;
        vm.prank(addr1);
        token.approve(owner, smallApproval);

        vm.expectRevert(
            abi.encodeWithSelector(
                ProductionERC20.InsufficientAllowance.selector, addr1, owner, BURN_AMOUNT, smallApproval
            )
        );
        token.burnFrom(addr1, BURN_AMOUNT);
    }

    function test_BurnFrom_InsufficientBalance() public {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, 1000 ether);

        uint256 hugeAmount = 999_999 ether;
        vm.prank(addr1);
        token.approve(owner, hugeAmount);

        vm.expectRevert(
            abi.encodeWithSelector(ProductionERC20.InsufficientBalance.selector, addr1, hugeAmount, 1000 ether)
        );
        token.burnFrom(addr1, hugeAmount);
    }

    // ============================================================
    // 8. Gas 优化版本测试
    // ============================================================

    function test_TransferOptimized() public {
        uint256 transferAmount = 100 ether;

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 addr1BalanceBefore = token.balanceOf(addr1);

        token.transferOptimized(addr1, transferAmount);

        assertEq(token.balanceOf(owner), ownerBalanceBefore - transferAmount);
        assertEq(token.balanceOf(addr1), addr1BalanceBefore + transferAmount);
    }

    function test_TransferFromOptimized() public {
        token.approve(addr1, DEFAULT_APPROVE_AMOUNT);

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 addr2BalanceBefore = token.balanceOf(addr2);

        vm.prank(addr1);
        token.transferFromOptimized(owner, addr2, DEFAULT_TRANSFER_AMOUNT);

        assertEq(token.balanceOf(owner), ownerBalanceBefore - DEFAULT_TRANSFER_AMOUNT);
        assertEq(token.balanceOf(addr2), addr2BalanceBefore + DEFAULT_TRANSFER_AMOUNT);
    }

    // ============================================================
    // 9. EIP-2612 Permit
    // ============================================================

    function test_Permit_ThenTransferFrom() public {
        uint256 signerPk = 0xBEEF;
        address signer = vm.addr(signerPk);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(signer, 1000 ether);

        uint256 value = 500 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(signer);

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, signer, addr1, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);

        token.permit(signer, addr1, value, deadline, v, r, s);

        assertEq(token.allowance(signer, addr1), value);
        assertEq(token.nonces(signer), 1);

        vm.prank(addr1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(signer, addr2, value);

        assertEq(token.balanceOf(signer), 500 ether);
        assertEq(token.balanceOf(addr2), value);
    }

    function test_Permit_DeadlineExpired() public {
        uint256 signerPk = 0xBEEF;
        address signer = vm.addr(signerPk);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(signer, 1000 ether);

        uint256 value = 500 ether;
        uint256 deadline = block.timestamp - 1;
        uint256 nonce = token.nonces(signer);

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, signer, addr1, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);

        vm.expectRevert(ProductionERC20.PermitDeadlineExpired.selector);
        token.permit(signer, addr1, value, deadline, v, r, s);
    }

    function test_Permit_InvalidSigner() public {
        uint256 signerPk = 0xBEEF;
        address signer = vm.addr(signerPk);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(signer, 1000 ether);

        uint256 value = 500 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(signer);
        // Sign with wrong key (addr1's key) so recovered address != signer
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, signer, addr1, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest); // wrong key

        vm.expectRevert(ProductionERC20.InvalidSigner.selector);
        token.permit(signer, addr1, value, deadline, v, r, s);
    }

    function test_Permit_NonceIncrements() public {
        uint256 signerPk = 0xBEEF;
        address signer = vm.addr(signerPk);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(signer, 1000 ether);

        uint256 value = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;

        for (uint256 i = 0; i < 3; i++) {
            uint256 nonce = token.nonces(signer);
            bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, signer, addr1, value, nonce, deadline));
            bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
            token.permit(signer, addr1, value, deadline, v, r, s);
            assertEq(token.nonces(signer), i + 1);
        }
    }

    // ============================================================
    // 10. EIP-5805 Vote delegation
    // ============================================================

    function test_Delegate_ToSelf() public {
        token.delegate(owner);
        assertEq(token.delegates(owner), owner);
        assertEq(token.getVotes(owner), token.balanceOf(owner));
    }

    function test_Delegate_ToOther() public {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, 300 ether);
        vm.prank(addr1);
        token.delegate(addr2);

        assertEq(token.delegates(addr1), addr2);
        assertEq(token.getVotes(addr2), 300 ether);
        assertEq(token.getVotes(addr1), 0);
    }

    function test_Delegate_ToZero() public {
        token.delegate(owner);
        assertEq(token.getVotes(owner), token.balanceOf(owner));

        token.delegate(address(0));
        assertEq(token.delegates(owner), address(0));
        assertEq(token.getVotes(owner), 0);
    }

    function test_Delegate_Transfer_UpdatesVotes() public {
        token.delegate(owner);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, 200 ether);

        vm.prank(addr1);
        token.delegate(addr1);

        assertEq(token.getVotes(owner), token.balanceOf(owner));
        assertEq(token.getVotes(addr1), 200 ether);
    }

    function test_GetPastVotes() public {
        token.delegate(owner);
        uint256 block1 = block.number;
        assertEq(token.getPastVotes(owner, block1 - 1), 0);

        vm.roll(block.number + 1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(addr1, 100 ether);
        vm.prank(addr1);
        token.delegate(addr2);
        uint256 block2 = block.number;

        vm.roll(block.number + 1); // advance so we can query block2 (getPastVotes requires timepoint < block.number)
        assertEq(token.getPastVotes(owner, block1), INITIAL_SUPPLY);
        assertEq(token.getPastVotes(owner, block2), INITIAL_SUPPLY - 100 ether);
        assertEq(token.getPastVotes(addr2, block2), 100 ether);
    }

    function test_GetPastVotes_FutureReverts() public {
        token.delegate(owner);
        vm.expectRevert(
            abi.encodeWithSelector(ProductionERC20.ERC5805FutureLookup.selector, block.number + 1, block.number)
        );
        token.getPastVotes(owner, block.number + 1);
    }

    function test_Delegate_EmitsDelegateChanged() public {
        vm.expectEmit(true, true, true, false);
        emit DelegateChanged(owner, address(0), owner);
        token.delegate(owner);
    }

    function test_DelegateBySig() public {
        uint256 signerPk = 0xBEEF;
        address signer = vm.addr(signerPk);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(signer, 500 ether);

        uint256 nonce = token.nonces(signer);
        uint256 expiry = block.timestamp + 1 hours;
        address delegatee = addr2;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)"), delegatee, nonce, expiry
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);

        token.delegateBySig(delegatee, nonce, expiry, v, r, s);

        assertEq(token.delegates(signer), delegatee);
        assertEq(token.getVotes(delegatee), 500 ether);
        assertEq(token.nonces(signer), 1);
    }

    function test_DelegateBySig_ExpiredReverts() public {
        uint256 signerPk = 0xBEEF;
        address signer = vm.addr(signerPk);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(signer, 500 ether);

        uint256 nonce = token.nonces(signer);
        uint256 expiry = block.timestamp - 1;
        bytes32 structHash = keccak256(
            abi.encode(keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)"), addr2, nonce, expiry)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);

        vm.expectRevert(ProductionERC20.PermitDeadlineExpired.selector);
        token.delegateBySig(addr2, nonce, expiry, v, r, s);
    }

    function test_GetVotes_ZeroAddress() public view {
        assertEq(token.getVotes(address(0)), 0);
    }
}
