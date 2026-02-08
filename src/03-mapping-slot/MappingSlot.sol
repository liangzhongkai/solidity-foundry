// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title MappingSlot
 * @notice 演示 mapping 底层 storage slot 的计算方式
 *
 * 核心概念：
 * mapping(keyType => valueType) varName;
 *
 * mapping 的 slot 计算：
 * slot = keccak256(abi.encode(key, mapping_slot))
 *
 * 其中 mapping_slot 是该 mapping 变量在合约中的位置编号
 * 第一个状态变量从 slot 0 开始
 */
contract MappingSlot {
    // slot 0
    mapping(address => uint256) public balances;

    // slot 1 (mapping 在 slot 1，但实际数据存储在 keccak256(key, 1))
    mapping(address => uint256) public allowances;

    // slot 2
    uint256 public totalSupply;

    // slot 3 - nested mapping
    mapping(address => mapping(address => uint256)) public nestedAllowances;

    // slot 4
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    // 设置余额
    function setBalance(address user, uint256 amount) external {
        balances[user] = amount;
    }

    // 设置授权额度
    function setAllowance(address tokenOwner, address spender, uint256 amount) external {
        allowances[spender] = amount;
        nestedAllowances[tokenOwner][spender] = amount;
    }

    // 直接操作 storage（用内联汇编验证 slot 计算）
    function writeDirectlyToSlot(uint256 slot, uint256 value) external {
        assembly {
            sstore(slot, value)
        }
    }

    function readDirectlyFromSlot(uint256 slot) external view returns (uint256 value) {
        assembly {
            value := sload(slot)
        }
    }

    // 辅助函数：在链上计算 mapping slot
    // 注意：这个函数返回的是 mapping 中某个 key 对应的 storage slot
    function getBalanceSlot(address user) external pure returns (bytes32) {
        // balances 在 slot 0
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(user, uint256(0)));
    }

    function getAllowanceSlot(address spender) external pure returns (bytes32) {
        // allowances 在 slot 1
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(spender, uint256(1)));
    }

    // nested mapping slot: keccak256(abi.encode(key2, keccak256(abi.encode(key1, slot))))
    function getNestedAllowanceSlot(address tokenOwner, address spender) external pure returns (bytes32) {
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 outerSlot = keccak256(abi.encode(tokenOwner, uint256(3)));
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encode(spender, outerSlot));
    }
}
