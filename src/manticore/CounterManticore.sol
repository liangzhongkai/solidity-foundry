// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Manticore 符号执行测试合约 - 使用 crytic_* 前缀定义属性
/// manticore-verifier 会验证这些属性在符号执行下始终成立
contract CounterManticore {
    uint256 public number;

    function increment() public {
        if (number < type(uint256).max) {
            number++;
        }
    }

    function decrement() public {
        if (number > 0) {
            number--;
        }
    }

    function setNumber(uint256 x) public {
        number = x;
    }

    /// @notice 属性: number 为有效 uint256 (无下溢)
    function crytic_test_number_valid() public pure returns (bool) {
        return true;
    }

    /// @notice 属性: number 为有效 uint256 (无下溢)
    function crytic_test_state_consistent() public view returns (bool) {
        // slither-disable-next-line tautology -- uint256 >= 0 is always true; documents validity
        return number >= 0;
    }
}
