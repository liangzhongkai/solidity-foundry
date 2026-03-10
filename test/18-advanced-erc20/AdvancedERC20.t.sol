// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {AdvancedERC20} from "../../src/18-advanced-erc20/AdvancedERC20.sol";
import {ECDSA} from "openzeppelin-contracts@5.4.0/utils/cryptography/ECDSA.sol";

/// @title AdvancedERC20Test
/// @notice Comprehensive tests for AdvancedERC20 contract
contract AdvancedERC20Test is Test {
    using ECDSA for bytes32;

    AdvancedERC20 public token;

    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    address public minter = address(0x5);
    address public pauser = address(0x6);

    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    function setUp() public {
        vm.prank(owner);
        token = new AdvancedERC20("Advanced Token", "ADV", 18, INITIAL_SUPPLY, owner);

        // Setup roles
        vm.startPrank(owner);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.PAUSER_ROLE(), pauser);
        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_Constructor() public view {
        assertEq(token.name(), "Advanced Token");
        assertEq(token.symbol(), "ADV");
        assertEq(token.DECIMALS(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.owner(), owner);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.MINTER_ROLE(), owner));
        assertTrue(token.hasRole(token.PAUSER_ROLE(), owner));
    }

    function test_RevertWhen_DecimalsZero() public {
        vm.expectRevert(abi.encodeWithSelector(AdvancedERC20.InvalidRecipient.selector, address(0)));
        new AdvancedERC20("Test", "TST", 0, 100, owner);
    }

    function test_RevertWhen_InitialOwnerZero() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new AdvancedERC20("Test", "TST", 18, 100, address(0));
    }

    // ============ ERC20 Transfer Tests ============

    function test_Transfer() public {
        vm.prank(owner);
        token.transfer(alice, 100);

        assertEq(token.balanceOf(alice), 100);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - 100);
    }

    function test_TransferFullBalance() public {
        vm.prank(owner);
        token.transfer(alice, INITIAL_SUPPLY);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), 0);
    }

    function test_RevertWhen_TransferToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(AdvancedERC20.InvalidRecipient.selector, address(0)));
        token.transfer(address(0), 100);
    }

    function test_RevertWhen_TransferInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AdvancedERC20.InsufficientBalance.selector, alice, 100, 0));
        token.transfer(bob, 100);
    }

    function test_RevertWhen_TransferWhenPaused() public {
        vm.prank(pauser);
        token.pause();

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.transfer(alice, 100);
    }

    // ============ ERC20 Approve Tests ============

    function test_Approve() public {
        vm.prank(owner);
        assertTrue(token.approve(alice, 100));

        assertEq(token.allowance(owner, alice), 100);
    }

    function test_RevertWhen_ApproveToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(AdvancedERC20.ApprovalToZeroAddress.selector);
        token.approve(address(0), 100);
    }

    function test_IncreaseAllowance() public {
        vm.prank(owner);
        token.approve(alice, 100);

        vm.prank(owner);
        assertTrue(token.increaseAllowance(alice, 50));

        assertEq(token.allowance(owner, alice), 150);
    }

    function test_DecreaseAllowance() public {
        vm.prank(owner);
        token.approve(alice, 100);

        vm.prank(owner);
        assertTrue(token.decreaseAllowance(alice, 50));

        assertEq(token.allowance(owner, alice), 50);
    }

    function test_RevertWhen_DecreaseAllowanceInsufficient() public {
        vm.prank(owner);
        token.approve(alice, 50);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(AdvancedERC20.InsufficientAllowance.selector, owner, alice, 100, 50));
        token.decreaseAllowance(alice, 100);
    }

    // ============ ERC20 TransferFrom Tests ============

    function test_TransferFrom() public {
        vm.prank(owner);
        token.approve(alice, 100);

        vm.prank(alice);
        assertTrue(token.transferFrom(owner, bob, 100));

        assertEq(token.balanceOf(bob), 100);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - 100);
        assertEq(token.allowance(owner, alice), 0);
    }

    function test_TransferFromPartialAllowance() public {
        vm.prank(owner);
        token.approve(alice, 200);

        vm.prank(alice);
        token.transferFrom(owner, bob, 100);

        assertEq(token.allowance(owner, alice), 100);
    }

    function test_RevertWhen_TransferFromInsufficientAllowance() public {
        vm.prank(owner);
        token.approve(alice, 50);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AdvancedERC20.InsufficientAllowance.selector, owner, alice, 100, 50));
        token.transferFrom(owner, bob, 100);
    }

    function test_RevertWhen_TransferFromWhenPaused() public {
        vm.prank(owner);
        token.approve(alice, 100);

        vm.prank(pauser);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.transferFrom(owner, bob, 100);
    }

    // ============ Mint Tests ============

    function test_Mint() public {
        vm.prank(minter);
        token.mint(alice, 1000);

        assertEq(token.balanceOf(alice), 1000);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 1000);
    }

    function test_MintAsOwner() public {
        vm.prank(owner);
        token.mint(alice, 1000);

        assertEq(token.balanceOf(alice), 1000);
    }

    function test_RevertWhen_MintWithoutRole() public {
        // Anyone without MINTER_ROLE cannot mint
        vm.prank(alice);
        vm.expectRevert(); // AccessControlUnauthorizedAccount
        token.mint(bob, 100);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(AdvancedERC20.MintToZeroAddress.selector);
        token.mint(address(0), 100);
    }

    function test_RevertWhen_MintWhenPaused() public {
        vm.prank(pauser);
        token.pause();

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.mint(alice, 100);
    }

    // ============ Burn Tests ============

    function test_Burn() public {
        vm.prank(owner);
        token.transfer(alice, 1000);

        vm.prank(alice);
        token.burn(500);

        assertEq(token.balanceOf(alice), 500);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - 500);
    }

    function test_BurnFrom() public {
        vm.prank(owner);
        token.transfer(alice, 1000);

        vm.prank(alice);
        token.approve(bob, 500);

        vm.prank(bob);
        token.burnFrom(alice, 500);

        assertEq(token.balanceOf(alice), 500);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - 500);
    }

    function test_RevertWhen_BurnInsufficientBalance() public {
        vm.prank(owner);
        token.transfer(alice, 100);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AdvancedERC20.InsufficientBalance.selector, alice, 200, 100));
        token.burn(200);
    }

    function test_RevertWhen_BurnWhenPaused() public {
        vm.prank(owner);
        token.transfer(alice, 1000);

        vm.prank(pauser);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.burn(100);
    }

    // ============ Pause Tests ============

    function test_Pause() public {
        vm.prank(pauser);
        token.pause();

        assertTrue(token.paused());
    }

    function test_Unpause() public {
        vm.prank(pauser);
        token.pause();

        vm.prank(pauser);
        token.unpause();

        assertFalse(token.paused());
    }

    function test_PauseAsOwner() public {
        vm.prank(owner);
        token.pause();

        assertTrue(token.paused());
    }

    function test_RevertWhen_PauseWithoutRole() public {
        // Anyone without PAUSER_ROLE cannot pause
        vm.prank(alice);
        vm.expectRevert(); // AccessControlUnauthorizedAccount
        token.pause();
    }

    // ============ EIP-2612 Permit Tests ============

    function test_Permit() public {
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);

        // Give signer some tokens
        vm.prank(owner);
        token.transfer(signer, 1000);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        signer,
                        bob,
                        500,
                        0,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        token.permit(signer, bob, 500, deadline, v, r, s);

        assertEq(token.allowance(signer, bob), 500);
        assertEq(token.nonces(signer), 1);
    }

    function test_RevertWhen_PermitExpired() public {
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);

        uint256 deadline = block.timestamp - 1;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        signer,
                        bob,
                        500,
                        0,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert(AdvancedERC20.PermitDeadlineExpired.selector);
        token.permit(signer, bob, 500, deadline, v, r, s);
    }

    function test_RevertWhen_PermitInvalidSigner() public {
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        signer,
                        bob,
                        500,
                        0,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Use wrong owner address
        vm.expectRevert(AdvancedERC20.InvalidSigner.selector);
        token.permit(alice, bob, 500, deadline, v, r, s);
    }

    // ============ EIP-5805 Vote Delegation Tests ============

    function test_Delegate() public {
        vm.prank(owner);
        token.delegate(alice);

        assertEq(token.delegates(owner), alice);
        assertEq(token.getVotes(alice), INITIAL_SUPPLY);
    }

    function test_DelegateChangesVotes() public {
        vm.prank(owner);
        token.delegate(alice);

        assertEq(token.getVotes(alice), INITIAL_SUPPLY);

        vm.prank(owner);
        token.delegate(bob);

        assertEq(token.getVotes(alice), 0);
        assertEq(token.getVotes(bob), INITIAL_SUPPLY);
    }

    function test_DelegateSelf() public {
        vm.prank(owner);
        token.delegate(owner);

        assertEq(token.delegates(owner), owner);
        assertEq(token.getVotes(owner), INITIAL_SUPPLY);
    }

    function test_TransferUpdatesVotes() public {
        vm.prank(owner);
        token.delegate(alice);

        vm.prank(owner);
        token.transfer(bob, 1000);

        assertEq(token.getVotes(alice), INITIAL_SUPPLY - 1000);
    }

    function test_GetPastVotes() public {
        vm.prank(owner);
        token.delegate(alice);

        uint256 blockNumber = block.number;

        vm.roll(blockNumber + 1);

        vm.prank(owner);
        token.transfer(bob, 1000);

        vm.roll(blockNumber + 2);

        // Check past votes at original block (before transfer)
        assertEq(token.getPastVotes(alice, blockNumber), INITIAL_SUPPLY);
        // Check past votes after transfer (at blockNumber + 1)
        assertEq(token.getPastVotes(alice, blockNumber + 1), INITIAL_SUPPLY - 1000);
    }

    function test_RevertWhen_GetPastVotesFutureBlock() public {
        vm.expectRevert(
            abi.encodeWithSelector(AdvancedERC20.ERC5805FutureLookup.selector, block.number + 10, block.number)
        );
        token.getPastVotes(alice, block.number + 10);
    }

    function test_DelegateBySig() public {
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);

        // Give signer some tokens
        vm.prank(owner);
        token.transfer(signer, 1000);

        uint256 nonce = 0;
        uint256 expiry = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(
            abi.encode(keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)"), alice, nonce, expiry)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        token.delegateBySig(alice, nonce, expiry, v, r, s);

        assertEq(token.delegates(signer), alice);
        assertEq(token.getVotes(alice), 1000);
        assertEq(token.nonces(signer), 1);
    }

    // ============ AccessControl Tests ============

    function test_GrantRole() public view {
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
    }

    function test_RoleManagement() public {
        // Verify minter has the role initially
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));

        // Owner has all admin roles
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.MINTER_ROLE(), owner));
        assertTrue(token.hasRole(token.PAUSER_ROLE(), owner));

        // Verify role admin setup
        assertEq(token.getRoleAdmin(token.MINTER_ROLE()), token.DEFAULT_ADMIN_ROLE());
        assertEq(token.getRoleAdmin(token.PAUSER_ROLE()), token.DEFAULT_ADMIN_ROLE());
    }

    function test_RenounceRole() public {
        // renounceRole requires the caller to be the confirmation address
        // Since minter has MINTER_ROLE, they can renounce it themselves
        vm.startPrank(minter);
        token.renounceRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();

        assertFalse(token.hasRole(token.MINTER_ROLE(), minter));
    }

    // ============ Ownable Tests ============

    function test_TransferOwnership() public {
        vm.prank(owner);
        token.transferOwnership(alice);

        assertEq(token.owner(), alice);
    }

    function test_RenounceOwnership() public {
        vm.prank(owner);
        token.renounceOwnership();

        assertEq(token.owner(), address(0));
    }

    function test_RevertWhen_NonOwnerCallsOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        token.transferOwnership(bob);
    }

    // ============ ReentrancyGuard Tests ============

    // Note: Standard ERC20 doesn't have external calls that could trigger reentrancy,
    // but the guard is implemented for demonstration and future extensibility.

    function test_ReentrancyGuardError() public view {
        // The ReentrancyGuard is in place but ERC20 transfers don't trigger it
        // This test verifies the error selector is correct
        assertEq(bytes4(keccak256("Reentrancy()")), AdvancedERC20.Reentrancy.selector);
    }

    // ============ Domain Separator Tests ============

    function test_DomainSeparator() public view {
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        assertTrue(domainSeparator != bytes32(0));
    }

    function test_DomainSeparatorChangesOnChainIdChange() public {
        bytes32 originalDomain = token.DOMAIN_SEPARATOR();

        vm.chainId(31338);
        bytes32 newDomain = token.DOMAIN_SEPARATOR();

        // Domain separator should be computed on-the-fly when chainId changes
        assertNotEq(originalDomain, newDomain);
    }

    // ============ Edge Cases ============

    function test_TransferZeroAmount() public {
        vm.prank(owner);
        token.transfer(alice, 0);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    function test_ApproveZeroAmount() public {
        vm.prank(owner);
        token.approve(alice, 0);

        assertEq(token.allowance(owner, alice), 0);
    }

    function test_MintZeroAmount() public {
        uint256 supplyBefore = token.totalSupply();

        vm.prank(minter);
        token.mint(alice, 0);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), supplyBefore);
    }

    function test_BurnZeroAmount() public {
        vm.prank(owner);
        token.transfer(alice, 100);

        vm.prank(alice);
        token.burn(0);

        assertEq(token.balanceOf(alice), 100);
    }

    // ============ Fuzz Tests ============

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 0, INITIAL_SUPPLY);

        vm.prank(owner);
        token.transfer(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
    }

    function testFuzz_Approve(uint256 amount) public {
        vm.assume(amount > 0);

        vm.prank(owner);
        token.approve(alice, amount);

        assertEq(token.allowance(owner, alice), amount);
    }

    function testFuzz_Mint(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max - INITIAL_SUPPLY);

        vm.prank(minter);
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + amount);
    }

    function testFuzz_Burn(uint256 amount) public {
        amount = bound(amount, 0, INITIAL_SUPPLY);

        vm.prank(owner);
        token.burn(amount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }
}
