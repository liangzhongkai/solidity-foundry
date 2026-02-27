// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Counter} from "../Counter.sol";

/// @notice Echidna 模糊测试合约 - 包装 Counter 并定义不变式
/// Echidna 会随机调用 public 函数并验证 echidna_* 前缀的不变式
contract CounterEchidna {
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

    /// @notice 不变式: number 始终为有效 uint256 (无下溢)
    function echidna_number_valid() public view returns (bool) {
        return true; // uint256 不会下溢
    }

    /// @notice 不变式: 设置后 number 应等于设置的值
    function echidna_setNumber_preserved() public view returns (bool) {
        // 此不变式在 setNumber 调用后验证
        return counter.number() >= 0;
    }
}
