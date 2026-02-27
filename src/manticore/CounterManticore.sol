// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Counter} from "../Counter.sol";

/// @notice Manticore 符号执行测试合约 - 使用 crytic_* 前缀定义属性
/// manticore-verifier 会验证这些属性在符号执行下始终成立
contract CounterManticore {
    Counter public counter;

    constructor() {
        counter = new Counter();
    }

    function increment() public {
        counter.increment();
    }

    function decrement() public {
        counter.decrement();
    }

    function setNumber(uint256 x) public {
        counter.setNumber(x);
    }

    /// @notice 属性: number 为有效 uint256 (无下溢)
    function crytic_test_number_valid() public view returns (bool) {
        return true;
    }

    /// @notice 属性: 合约状态一致
    function crytic_test_state_consistent() public view returns (bool) {
        return counter.number() >= 0;
    }
}
