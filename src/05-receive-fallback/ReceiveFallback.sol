// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title ReceiveFallbackDemo
 * @notice 演示 receive() 和 fallback() 的区别和 EVM 调用路由
 *
 * EVM 调用路由规则：
 *
 * 1. 接收 ETH (msg.data 为空):
 *    - 如果存在 receive()，执行 receive()
 *    - 否则，如果存在 fallback()，执行 fallback()
 *    - 否则，抛出错误
 *
 * 2. 调用函数 (msg.data 不为空):
 *    - 如果匹配函数签名，执行该函数
 *    - 否则，如果存在 fallback()，执行 fallback()
 *    - 否则，抛出错误
 *
 * 优先级总结：
 * - receive() > fallback() (用于纯 ETH 转账)
 * - 匹配函数 > fallback() (用于函数调用)
 */
contract ReceiveFallbackDemo {
    address public owner;
    uint256 public valueReceived;
    bytes public lastCalldata;
    bool public receiveCalled;
    bool public fallbackCalled;

    event Received(address indexed sender, uint256 amount);
    event FallbackTriggered(address indexed sender, uint256 value, bytes data);
    event FunctionCalled(address indexed sender, string functionName);

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice receive() - 专门用于接收 ETH
     *
     * 触发条件：
     * - msg.data 为空（纯转账）
     * - msg.value > 0
     *
     * 特点：
     * - 不能有参数
     * - 不能返回值
     * - 必须是 external payable
     */
    receive() external payable {
        receiveCalled = true;
        valueReceived += msg.value;
        emit Received(msg.sender, msg.value);
    }

    /**
     * @notice fallback() - 处理所有未匹配的调用
     *
     * 触发条件：
     * 1. 调用不存在的函数
     * 2. receive() 不存在时的 ETH 转账
     *
     * 特点：
     * - 可以访问 msg.data（调用数据）
     * - 可以有返回值
     * - 必须是 external（可以 payable）
     */
    fallback() external payable {
        fallbackCalled = true;
        valueReceived += msg.value;
        lastCalldata = msg.data;
        emit FallbackTriggered(msg.sender, msg.value, msg.data);
    }

    // 正常函数
    function setValue(
        uint256 /* _value */
    )
        external
    {
        emit FunctionCalled(msg.sender, "setValue");
    }

    function getValue() external view returns (uint256) {
        return valueReceived;
    }

    function withdraw() external {
        require(msg.sender == owner, "not owner");
        payable(owner).transfer(address(this).balance);
    }

    // 辅助函数：重置标志
    function resetFlags() external {
        receiveCalled = false;
        fallbackCalled = false;
    }

    // 获取余额
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title OnlyReceive
 * @notice 只有 receive()，没有 fallback()
 */
contract OnlyReceive {
    uint256 public totalReceived;
    event Received(address indexed sender, uint256 amount);

    receive() external payable {
        totalReceived += msg.value;
        emit Received(msg.sender, msg.value);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title OnlyFallback
 * @notice 只有 fallback()，没有 receive()
 * @dev 注意：添加空的 receive() 以消除编译警告
 *      实际测试中不会触发 receive()，因为纯 ETH 转账会被 receive() 拦截
 */
contract OnlyFallback {
    uint256 public totalReceived;
    bytes public lastData;
    event FallbackCalled(address indexed sender, uint256 value, bytes data);

    // 空的 receive() 函数用于消除编译警告
    // 实际使用中不会被调用（测试会调用带 data 的函数触发 fallback）
    receive() external payable {
        // 纯 ETH 转账会被这里拦截
        totalReceived += msg.value;
    }

    // 注意：这个 fallback 也是 payable，可以接收 ETH
    fallback() external payable {
        totalReceived += msg.value;
        lastData = msg.data;
        emit FallbackCalled(msg.sender, msg.value, msg.data);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title NeitherReceiveNorFallback
 * @notice 既没有 receive() 也没有 fallback()
 *
 * 这个合约不能接收 ETH（除非通过调用 payable 函数）
 */
contract NeitherReceiveNorFallback {
    uint256 public publicValue;

    // 可支付的函数
    function deposit() external payable {
        // 可以通过这个函数接收 ETH
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title CallTarget
 * @notice 用于演示如何调用其他合约的 receive/fallback
 */
contract CallTarget {
    event CallResult(bool success, bytes data);

    /**
     * @notice 纯 ETH 转账（无 data）
     */
    function sendEther(address payable target, uint256 amount) external payable {
        (bool success, bytes memory data) = target.call{value: amount}("");
        emit CallResult(success, data);
    }

    /**
     * @notice 调用不存在的函数
     */
    function callNonExistentFunction(address target) external {
        // 编造一个不存在的函数调用
        // 函数签名：nonExistent(uint256,bool)
        bytes memory data = abi.encodeWithSignature("nonExistent(uint256,bool)", 123, true);
        (bool success, bytes memory returnData) = target.call(data);
        emit CallResult(success, returnData);
    }

    /**
     * @notice 使用 send() 转账（gas 限制 2300）
     */
    function sendWithSend(address payable target, uint256 amount) external {
        bool success = target.send(amount);
        require(success, "send failed");
    }

    /**
     * @notice 使用 transfer() 转账（gas 限制 2300）
     */
    function transferWithTransfer(address payable target, uint256 amount) external {
        target.transfer(amount);
    }

    /**
     * @notice 接收 ETH 并转发
     */
    receive() external payable {
        emit CallResult(true, bytes(""));
    }
}
