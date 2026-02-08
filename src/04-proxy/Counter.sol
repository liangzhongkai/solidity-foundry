// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title CounterV1
 * @notice 逻辑合约 V1 - 通过 Proxy.delegatecall 调用
 *
 * 重要提示：
 * 这个合约从不直接部署使用，而是被 Proxy 通过 delegatecall 调用
 *
 * Storage 布局必须与 Proxy 保持一致！
 * 由于使用 delegatecall，本合约的 slot 0 映射到 Proxy 的 slot 0
 *
 * 因此我们需要预留 slot 0, 1 给 Proxy 的 impl 和 admin 变量
 */
contract CounterV1 {
    // 注意：delegatecall 时，本合约的 slot N 映射到 Proxy 的 slot N
    // 必须预留与 Proxy 相同的 slot 布局

    // slot 0 - 预留给 Proxy 的 impl（占位，不实际使用）
    uint256 private _gap0Impl;

    // slot 1 - 预留给 Proxy 的 admin（占位，不实际使用）
    address private _gap1Admin;

    // slot 2 - 计数器
    uint256 private count;

    // slot 3 - 所有者
    address private owner;

    // slot 4 - 最后更新时间
    uint256 private lastUpdated;

    event Incremented(uint256 newCount, address indexed by);
    event Decremented(uint256 newCount, address indexed by);
    event Initialized(address indexed owner);
    event ETHReceived(address indexed sender, uint256 amount);

    /**
     * @notice 初始化函数（替代构造函数）
     *
     * 构造函数在 delegatecall 中不会执行
     * 所以需要手动初始化
     */
    function initialize(address _owner) external {
        // Check if already initialized by checking if lastUpdated was set
        require(lastUpdated == 0, "already initialized");
        require(_owner != address(0), "invalid owner");
        owner = _owner;
        lastUpdated = block.timestamp;
        emit Initialized(_owner);
    }

    function increment() external {
        count += 1;
        lastUpdated = block.timestamp;
        emit Incremented(count, msg.sender);
    }

    function decrement() external {
        require(count > 0, "count cannot go below zero");
        count -= 1;
        lastUpdated = block.timestamp;
        emit Decremented(count, msg.sender);
    }

    function incrementBy(uint256 amount) external {
        count += amount;
        lastUpdated = block.timestamp;
        emit Incremented(count, msg.sender);
    }

    function getCount() external view returns (uint256) {
        return count;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function getLastUpdated() external view returns (uint256) {
        return lastUpdated;
    }

    function getVersion() external pure returns (string memory) {
        return "V1";
    }

    // 允许接收 ETH
    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }
}

/**
 * @title CounterV2
 * @notice 逻辑合约 V2 - 演示合约升级
 *
 * 升级说明：
 * 1. 新增功能：add, multiply
 * 2. 修改功能：increment 增加 emit
 * 3. 保持 storage 布局兼容（只能追加，不能修改现有变量顺序）
 */
contract CounterV2 {
    // Storage 布局必须与 V1 完全一致！
    // slot 0 - 预留给 Proxy 的 impl（占位）
    uint256 private _gap0Impl;

    // slot 1 - 预留给 Proxy 的 admin（占位）
    address private _gap1Admin;

    // slot 2 - 计数器
    uint256 private count;

    // slot 3 - 所有者
    address private owner;

    // slot 4 - 最后更新时间
    uint256 private lastUpdated;

    // slot 5 - 新增变量（只能追加！）
    uint256 private totalOperations;

    event Incremented(uint256 newCount, address indexed by);
    event Decremented(uint256 newCount, address indexed by);
    event Added(uint256 amount, uint256 newCount);
    event Multiplied(uint256 factor, uint256 newCount);
    event Initialized(address indexed owner);

    function initialize(address _owner) external {
        // Check if already initialized by checking if lastUpdated was set
        require(lastUpdated == 0, "already initialized");
        require(_owner != address(0), "invalid owner");
        owner = _owner;
        lastUpdated = block.timestamp;
        emit Initialized(_owner);
    }

    function increment() external {
        count += 1;
        totalOperations += 1;
        lastUpdated = block.timestamp;
        emit Incremented(count, msg.sender);
    }

    function decrement() external {
        require(count > 0, "count cannot go below zero");
        count -= 1;
        totalOperations += 1;
        lastUpdated = block.timestamp;
        emit Decremented(count, msg.sender);
    }

    function incrementBy(uint256 amount) external {
        count += amount;
        totalOperations += 1;
        lastUpdated = block.timestamp;
        emit Incremented(count, msg.sender);
    }

    // V2 新增功能
    function add(uint256 amount) external {
        count += amount;
        totalOperations += 1;
        lastUpdated = block.timestamp;
        emit Added(amount, count);
    }

    function multiply(uint256 factor) external {
        count *= factor;
        totalOperations += 1;
        lastUpdated = block.timestamp;
        emit Multiplied(factor, count);
    }

    function reset() external {
        require(msg.sender == owner, "only owner");
        count = 0;
        totalOperations += 1;
        lastUpdated = block.timestamp;
    }

    function getCount() external view returns (uint256) {
        return count;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function getLastUpdated() external view returns (uint256) {
        return lastUpdated;
    }

    function getTotalOperations() external view returns (uint256) {
        return totalOperations;
    }

    function getVersion() external pure returns (string memory) {
        return "V2";
    }

    // V2 新增：获取统计信息
    // 注意：不能使用 view，因为 delegatecall 与 staticcall 不兼容
    function getStats() external view returns (uint256 _count, uint256 _totalOps, uint256 _lastUpdated) {
        return (count, totalOperations, lastUpdated);
    }
}

/**
 * @title BrokenCounter
 * @notice 错误示例：storage 布局不兼容
 *
 * 这个合约演示了如果 storage 布局改变会发生什么
 * 没有预留 slot 0、1 给 Proxy，且变量顺序与 V1 不一致，会导致数据混乱！
 */
contract BrokenCounter {
    // ⚠️ 错误！没有预留 slot 0、1，且变量顺序与 V1 不同
    // 本合约 slot 0 -> 对应 Proxy slot 0（原是 impl），会破坏 proxy 的 impl 指针！
    uint256 public count;

    // 本合约 slot 1 -> 对应 Proxy slot 1（原是 admin）
    address public owner;

    // 本合约 slot 2 -> 对应 Proxy slot 2（原是 V1 的 count）
    uint256 public lastUpdated;

    function increment() external {
        count += 1; // 实际写的是 Proxy 的 slot 0（impl），会破坏 proxy！
    }

    function getVersion() external pure returns (string memory) {
        return "BROKEN";
    }
}
