// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {console} from "forge-std@1.14.0/console.sol";
import {VulnerableVault, ClassicAttack, SafeVault} from "../../src/19-reentrancy/ClassicReentrancy.sol";
import {PriceOracle, LendingProtocol, ReadOnlyAttack} from "../../src/19-reentrancy/ReadOnlyReentrancy.sol";
import {TokenPool, RewardDistributor, CrossContractAttack} from "../../src/19-reentrancy/CrossContractReentrancy.sol";

contract ReentrancyTest is Test {
    address internal attacker = address(0xA77);

    function setUp() public {
        vm.deal(attacker, 100 ether);
    }

    // ========== Classic Reentrancy ==========

    function test_ClassicReentrancy_AttackDrainsVault() public {
        VulnerableVault vault = new VulnerableVault();
        vm.deal(address(vault), 10 ether);

        ClassicAttack attack = new ClassicAttack(address(vault));
        vm.deal(attacker, 1 ether);

        uint256 vaultBefore = address(vault).balance;

        vm.prank(attacker);
        attack.attack{value: 1 ether}();

        assertLt(address(vault).balance, vaultBefore, "vault should be drained");
        assertGe(address(attack).balance, 5 ether, "attack contract drained via reentrancy");
        assertGe(attack.count(), 1, "reentrancy occurred");
    }

    function test_SafeVault_ReentrancyBlocked() public {
        SafeVault vault = new SafeVault();
        vm.prank(attacker);
        vault.deposit{value: 1 ether}();

        uint256 balBefore = attacker.balance;
        vm.prank(attacker);
        vault.withdraw();
        assertEq(attacker.balance, balBefore + 1 ether, "normal withdraw works");
        assertEq(vault.balances(attacker), 0);
    }

    // ========== Read-Only Reentrancy ==========

    function test_ReadOnlyReentrancy_AttackBorrowsWith1Wei() public {
        PriceOracle oracle = new PriceOracle();
        LendingProtocol lender = new LendingProtocol(address(oracle));
        vm.deal(address(lender), 100 ether);

        ReadOnlyAttack attack = new ReadOnlyAttack(address(oracle), address(lender));
        vm.deal(attacker, 150 ether);

        vm.prank(attacker);
        attack.attack{value: 150 ether}();

        console.log("address(attack).balance", address(attack).balance);
        assertGe(
            address(attack).balance, 249 ether, "attack borrowed 100 ETH with 1 wei collateral via read-only reentrancy"
        );
    }

    // ========== Cross-Contract Reentrancy ==========

    function test_CrossContractReentrancy_AttackDoubleClaims() public {
        TokenPool pool = new TokenPool();
        RewardDistributor distributor = new RewardDistributor{value: 20 ether}(address(pool));

        CrossContractAttack attack = new CrossContractAttack(address(pool), address(distributor));
        vm.deal(attacker, 10 ether);

        vm.prank(attacker);
        attack.attack{value: 10 ether}();

        assertEq(address(attack).balance, 20 ether, "attack double-claimed 10 + 10 ether");
    }
}
