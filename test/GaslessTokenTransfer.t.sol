// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {console} from "forge-std@1.14.0/console.sol";

import {ERC20Permit} from "../src/02-erc20/ERC20Permit.sol";
import {GaslessTokenTransfer} from "../src/02-erc20/GaslessTokenTransfer.sol";

contract GaslessTokenTransferTest is Test {
    ERC20Permit private token;
    GaslessTokenTransfer private gasless;

    uint256 constant SENDER_PRIVATE_KEY = 111;
    address sender;
    address receiver;
    uint256 constant AMOUNT = 1000;
    uint256 constant FEE = 10;

    function setUp() public {
        sender = vm.addr(SENDER_PRIVATE_KEY);
        receiver = address(2);

        token = new ERC20Permit("Test", "TEST", 18);
        token.mint(sender, AMOUNT + FEE);

        gasless = new GaslessTokenTransfer();
    }

    function test_ValidSignature() public {
        uint256 deadline = block.timestamp + 60;

        // Sender - prepare permit signature
        bytes32 permitHash = _getPermitHash(sender, address(gasless), AMOUNT + FEE, token.nonces(sender), deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SENDER_PRIVATE_KEY, permitHash);

        // Execute transfer
        gasless.send(address(token), sender, receiver, AMOUNT, FEE, deadline, v, r, s);

        // Check balances
        assertEq(token.balanceOf(sender), 0, "sender balance");
        assertEq(token.balanceOf(receiver), AMOUNT, "receiver balance");
        assertEq(token.balanceOf(address(this)), FEE, "fee");
    }

    /// @notice Compare gas: Traditional approve+transferFrom vs Gasless Permit
    function test_GasComparison() public {
        // --- Traditional flow: User approve (pays gas) + Relayer transferFrom (pays gas) ---
        uint256 gasBeforeApprove = gasleft();
        vm.prank(sender);
        token.approve(address(this), AMOUNT + FEE);
        uint256 gasUsedApprove = gasBeforeApprove - gasleft();

        uint256 gasBeforeTransfer = gasleft();
        bool success1 = token.transferFrom(sender, receiver, AMOUNT);
        bool success2 = token.transferFrom(sender, address(this), FEE);
        require(success1 && success2, "transfer failed");
        uint256 gasUsedTransferFrom = gasBeforeTransfer - gasleft();

        assertEq(token.balanceOf(sender), 0);
        assertEq(token.balanceOf(receiver), AMOUNT);
        assertEq(token.balanceOf(address(this)), FEE);

        // --- Gasless flow: Relayer send with permit (user pays 0 gas) ---
        // Reset: new token for gasless test
        token = new ERC20Permit("Test2", "TEST2", 18);
        token.mint(sender, AMOUNT + FEE);

        uint256 deadline = block.timestamp + 60;
        bytes32 permitHash = _getPermitHash(sender, address(gasless), AMOUNT + FEE, token.nonces(sender), deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SENDER_PRIVATE_KEY, permitHash);

        uint256 gasBeforeGasless = gasleft();
        gasless.send(address(token), sender, receiver, AMOUNT, FEE, deadline, v, r, s);
        uint256 gasUsedGasless = gasBeforeGasless - gasleft();

        // --- Log comparison ---
        console.log("=== Gas Comparison: Traditional vs Gasless ===");
        console.log("Traditional - User (approve):      ", gasUsedApprove);
        console.log("Traditional - Relayer (transfer):  ", gasUsedTransferFrom);
        console.log("Traditional - Total (2 txs):       ", gasUsedApprove + gasUsedTransferFrom);
        console.log("");
        console.log("Gasless - User:                    0 (off-chain signature only)");
        console.log("Gasless - Relayer (send):          ", gasUsedGasless);
        console.log("");
        console.log("User saves (gasless for user):     ", gasUsedApprove);
        console.log("Relayer: gasless combines permit+transfer, single tx");
    }

    function _getPermitHash(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        spender,
                        value,
                        nonce,
                        deadline
                    )
                )
            )
        );
    }
}
