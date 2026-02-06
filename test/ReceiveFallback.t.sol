// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {
    ReceiveFallbackDemo,
    OnlyReceive,
    OnlyFallback,
    NeitherReceiveNorFallback,
    CallTarget
} from "../src/05-receive-fallback/ReceiveFallback.sol";

contract ReceiveFallbackTest is Test {
    ReceiveFallbackDemo public demo;
    OnlyReceive public onlyReceive;
    OnlyFallback public onlyFallback;
    NeitherReceiveNorFallback public neither;
    CallTarget public callTarget;

    address public owner;
    address public user1;

    event Received(address indexed sender, uint256 amount);
    event FallbackTriggered(address indexed sender, uint256 value, bytes data);

    function setUp() public {
        owner = address(this);
        user1 = address(0xabc1); // Not a precompile address

        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);

        demo = new ReceiveFallbackDemo();
        onlyReceive = new OnlyReceive();
        onlyFallback = new OnlyFallback();
        neither = new NeitherReceiveNorFallback();
        callTarget = new CallTarget();
    }

    function test_ShouldTriggerReceiveViaCall() public {
        address payable demoAddress = payable(address(demo));

        demo.resetFlags();

        (bool success,) = demoAddress.call{value: 1 ether}("");
        assertTrue(success);

        assertTrue(demo.receiveCalled());
        assertFalse(demo.fallbackCalled());
        assertEq(address(demo).balance, 1 ether);
    }

    function test_ShouldTriggerFallbackViaNonExistentFunction() public {
        address payable demoAddress = payable(address(demo));

        demo.resetFlags();

        bytes memory fakeFuncData = abi.encodePacked(bytes4(keccak256("nonExistentFunction(uint256,address)")));

        (bool success,) = demoAddress.call(fakeFuncData);
        assertTrue(success);

        assertFalse(demo.receiveCalled());
        assertTrue(demo.fallbackCalled());
        assertEq(demo.lastCalldata(), fakeFuncData);
    }

    function test_ShouldTriggerFallbackWithETHAndNonExistentFunction() public {
        demo.resetFlags();

        address payable demoAddress = payable(address(demo));

        bytes memory fakeFuncData = abi.encodePacked(bytes4(keccak256("someFakeFunction()")));

        (bool success,) = demoAddress.call{value: 0.3 ether}(fakeFuncData);
        assertTrue(success);

        assertFalse(demo.receiveCalled());
        assertTrue(demo.fallbackCalled());
        assertEq(demo.valueReceived(), 0.3 ether);
    }

    function test_OnlyReceive_PureETH() public {
        address payable onlyReceiveAddress = payable(address(onlyReceive));

        (bool success,) = onlyReceiveAddress.call{value: 1 ether}("");
        assertTrue(success);

        assertEq(onlyReceive.getBalance(), 1 ether);

        bytes memory fakeFuncData = abi.encodePacked(bytes4(keccak256("fake()")));

        (success,) = onlyReceiveAddress.call(fakeFuncData);
        assertFalse(success);
    }

    function test_OnlyFallback_PureETH() public {
        address payable onlyFallbackAddress = payable(address(onlyFallback));

        (bool success,) = onlyFallbackAddress.call{value: 1 ether}("");
        assertTrue(success);

        assertEq(onlyFallback.getBalance(), 1 ether);

        bytes memory fakeFuncData = abi.encodePacked(bytes4(keccak256("fake()")));

        (success,) = onlyFallbackAddress.call(fakeFuncData);
        assertTrue(success);
    }

    function test_NeitherReceiveNorFallback_PureETH() public {
        address payable neitherAddress = payable(address(neither));

        (bool success,) = neitherAddress.call{value: 1 ether}("");
        assertFalse(success);

        bytes memory fakeFuncData = abi.encodePacked(bytes4(keccak256("fake()")));

        (success,) = neitherAddress.call(fakeFuncData);
        assertFalse(success);

        // But can receive ETH via deposit() function
        (success,) = neitherAddress.call{value: 1 ether}(abi.encodeWithSignature("deposit()"));
        assertTrue(success);

        assertEq(neither.getBalance(), 1 ether);
    }

    function test_Priority_ReceiveAndFallback() public {
        address payable demoAddress = payable(address(demo));

        // Pure ETH transfer -> receive()
        demo.resetFlags();
        (bool success,) = demoAddress.call{value: 0.5 ether}("");
        assertTrue(success);

        assertTrue(demo.receiveCalled());
        assertFalse(demo.fallbackCalled());

        // Call non-existent function -> fallback()
        demo.resetFlags();
        bytes memory fakeFuncData = abi.encodePacked(bytes4(keccak256("fake()")));
        (success,) = demoAddress.call(fakeFuncData);
        assertTrue(success);

        assertFalse(demo.receiveCalled());
        assertTrue(demo.fallbackCalled());

        // Non-existent function + ETH -> fallback() (not receive!)
        demo.resetFlags();
        uint256 prevValue = demo.valueReceived();
        (success,) = demoAddress.call{value: 0.3 ether}(fakeFuncData);
        assertTrue(success);

        assertFalse(demo.receiveCalled());
        assertTrue(demo.fallbackCalled());
        assertEq(demo.valueReceived(), prevValue + 0.3 ether);
    }

    function test_CallTarget_SendEther() public {
        address payable onlyReceiveAddress = payable(address(onlyReceive));

        vm.deal(address(callTarget), 2 ether);
        callTarget.sendEther(onlyReceiveAddress, 1 ether);
        assertEq(onlyReceive.getBalance(), 1 ether);
    }

    function test_CallTarget_CallNonExistentFunction() public {
        callTarget.callNonExistentFunction(address(demo));

        assertTrue(demo.fallbackCalled());
    }

    function test_CallTarget_SendWithSend_ToEOA() public {
        vm.deal(address(callTarget), 2 ether);

        callTarget.sendWithSend(payable(user1), 1 ether);

        assertGt(user1.balance, 0);
    }

    function test_CallTarget_SendWithSend_ToNoFallback() public {
        address payable neitherAddress = payable(address(neither));

        vm.expectRevert("send failed");
        callTarget.sendWithSend(neitherAddress, 1 ether);
    }

    function test_CallTarget_Receive() public {
        address payable callTargetAddress = payable(address(callTarget));

        (bool success,) = callTargetAddress.call{value: 1 ether}("");
        assertTrue(success);

        assertEq(address(callTarget).balance, 1 ether);
    }

    function test_SetValueAndGetValue() public {
        demo.setValue(42);

        uint256 value = demo.getValue();
        assertEq(value, 0);
    }

    function test_Withdraw() public {
        address payable demoAddress = payable(address(demo));

        (bool success,) = demoAddress.call{value: 1 ether}("");
        assertTrue(success);

        assertEq(demoAddress.balance, 1 ether);

        uint256 ownerBalanceBefore = owner.balance;

        demo.withdraw();

        assertEq(demoAddress.balance, 0);
        assertGt(owner.balance, ownerBalanceBefore);
    }

    function test_Withdraw_OnlyOwner() public {
        address payable demoAddress = payable(address(demo));

        (bool success,) = demoAddress.call{value: 1 ether}("");
        assertTrue(success);

        vm.prank(user1);
        vm.expectRevert("not owner");
        demo.withdraw();
    }

    function test_GetBalance() public {
        address payable demoAddress = payable(address(demo));

        (bool success,) = demoAddress.call{value: 2.5 ether}("");
        assertTrue(success);

        assertEq(demo.getBalance(), 2.5 ether);
    }

    function test_ResetFlags() public {
        address payable demoAddress = payable(address(demo));
        (bool success,) = demoAddress.call{value: 1 ether}("");
        assertTrue(success);

        assertTrue(demo.receiveCalled());

        demo.resetFlags();

        assertFalse(demo.receiveCalled());
        assertFalse(demo.fallbackCalled());
    }

    // Receive function to accept ETH when withdraw sends to owner (this contract)
    receive() external payable {}
}
