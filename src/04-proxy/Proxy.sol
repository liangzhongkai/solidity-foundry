// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Proxy
 * @notice 最小化可升级代理合约 - 不使用 OpenZeppelin
 *
 * 核心概念：
 * 1. delegatecall 让被调用的合约在调用者的上下文中执行
 * 2. 代码在 impl 合约，但数据存储在 Proxy 合约
 * 3. 通过修改 impl 地址实现合约升级
 */
contract Proxy {
    // slot 0 - 实现合约地址
    address public impl;

    // slot 1 - 管理员地址（可选：用于控制升级权限）
    address public admin;

    // slot 2 - 防止存储冲突的标识（可选安全措施）
    uint256 public constant PROXY_ID = 0x12345678;

    event Upgraded(address indexed oldImpl, address indexed newImpl);
    event DelegateCallFailed(bytes reason);

    constructor(address _impl, address _admin) {
        impl = _impl;
        admin = _admin;
    }

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal view {
        require(msg.sender == admin, "Proxy: not admin");
    }

    /**
     * @notice 升级实现合约
     * @param newImpl 新的实现合约地址
     */
    function upgrade(address newImpl) external onlyAdmin {
        address oldImpl = impl;
        impl = newImpl;
        emit Upgraded(oldImpl, newImpl);
    }

    /**
     * @notice fallback 函数 - 处理所有未匹配的调用
     *
     * 核心逻辑：
     * 1. 接收所有调用数据
     * 2. 使用 delegatecall 将调用转发到 impl 合约
     * 3. delegatecall 在 Proxy 的 storage 上执行 impl 的代码
     */
    fallback() external payable virtual {
        _delegate(impl);
    }

    /**
     * @notice receive 函数 - 处理纯 ETH 转账
     *
     * 注意：只有当 msg.data 为空时才会触发 receive
     * 如果 impl 没有接收 ETH 的能力，交易会失败
     */
    receive() external payable virtual {
        // 对于纯 ETH 转账，我们尝试 delegatecall 到 impl
        // 如果 impl 没有 payable 的 receive/fallback，会 revert
        _delegate(impl);
    }

    /**
     * @notice 执行 delegatecall
     * @param impl_ 实现合约地址
     *
     * delegatecall 语义：
     * - 在当前合约的 storage 上执行代码
     * - msg.sender 保持为原始调用者
     * - msg.value 也保持不变
     */
    function _delegate(address impl_) internal {
        assembly {
            // 复制 calldata 到 memory
            calldatacopy(0, 0, calldatasize())

            // 执行 delegatecall
            // gas(): 剩余 gas
            // impl_: 目标合约地址
            // 0: calldata 在 memory 中的起始位置
            // calldatasize(): calldata 大小
            // 0: 返回数据在 memory 中的起始位置
            // 0: 返回数据大小（0 表示复制所有）
            let result := delegatecall(gas(), impl_, 0, calldatasize(), 0, 0)

            // 复制返回数据到 memory
            returndatacopy(0, 0, returndatasize())

            // 根据结果决定返回或回滚
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @notice 直接转发到 impl 的备用实现
     * 这个函数使用标准的 delegatecall 语法
     */
    function _fallback(address impl_) internal {
        (bool success, bytes memory data) = impl_.delegatecall(msg.data);
        require(success, string(data));
        assembly {
            return(add(data, 0x20), mload(data))
        }
    }
}

/**
 * @title AdminUpgradeabilityProxy
 * @notice 带权限控制的代理合约
 */
contract AdminUpgradeabilityProxy is Proxy {
    constructor(address _impl, address _admin) Proxy(_impl, _admin) {}

    /**
     * @notice 升级到新的实现合约
     * @param newImpl 新实现合约地址
     */
    function upgradeTo(address newImpl) external onlyAdmin {
        _upgradeTo(newImpl);
    }

    /**
     * @notice 升级并调用初始化函数（防止 storage 冲突）
     * @param newImpl 新实现合约
     * @param data 初始化调用数据
     *
     * 这是为了防止新实现合约的构造函数无法在 delegatecall 中执行
     * 需要手动调用初始化函数
     */
    function upgradeToAndCall(address newImpl, bytes memory data) external payable onlyAdmin {
        _upgradeTo(newImpl);
        // 如果 data 为空，跳过 delegatecall（用于已经初始化的场景）
        if (data.length > 0) {
            (bool success,) = newImpl.delegatecall(data);
            require(success, "Proxy: initialization failed");
        }
    }

    function _upgradeTo(address newImpl) internal {
        address oldImpl = impl;
        impl = newImpl;
        emit Upgraded(oldImpl, newImpl);
    }
}

/**
 * @title ProxyUsingFallback
 * @notice 测试合约 - 使用 _fallback 而不是 _delegate
 *
 * 这个合约仅用于演示和测试 _fallback 的实现方式
 * 它展示了使用标准 Solidity delegatecall 语法而不是内联汇编的替代方案
 */
contract ProxyUsingFallback is Proxy {
    constructor(address _impl, address _admin) Proxy(_impl, _admin) {}

    /**
     * @notice fallback 函数 - 使用 _fallback 实现
     */
    fallback() external payable override {
        _fallback(impl);
    }

    /**
     * @notice receive 函数 - 使用 _fallback 实现
     */
    receive() external payable override {
        _fallback(impl);
    }
}
