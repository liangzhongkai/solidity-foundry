// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ProductionERC20 {
    // Custom errors
    error InsufficientBalance(address account, uint256 required, uint256 available);
    error InsufficientAllowance(address owner, address spender, uint256 required, uint256 available);
    error InvalidRecipient(address recipient);
    error InvalidSpender(address spender);
    error MintToZeroAddress();
    error BurnFromZeroAddress();
    error ApprovalToZeroAddress();

    // Assembly 优化常量
    uint256 private constant BALANCES_SLOT = 3; // _balances mapping 的存储槽位

    // State variables
    string public name; // slot 0
    string public symbol; // slot 1
    uint8 public immutable DECIMALS; // 不占slot  calldata 存储
    uint256 public totalSupply; // slot 2

    mapping(address => uint256) private _balances; // slot 3
    mapping(address => mapping(address => uint256)) private _allowances; // slot 4

    // Events with indexed parameters
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 initialSupply,
        address initialOwner
    ) {
        if (_decimals == 0) revert InvalidRecipient(address(0));
        name = _name;
        symbol = _symbol;
        DECIMALS = _decimals;

        if (initialOwner == address(0)) revert MintToZeroAddress();
        _mint(initialOwner, initialSupply);
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ApprovalToZeroAddress();

        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert InvalidRecipient(to);

        _transfer(msg.sender, to, amount);
        return true;
    }

    // Assembly 优化版本的公共接口
    function transferOptimized(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert InvalidRecipient(to);

        _transferOptimized(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert InvalidRecipient(to);
        if (from == address(0)) revert InvalidRecipient(from);

        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(from, msg.sender, amount, currentAllowance);
        }

        unchecked {
            _approve(from, msg.sender, currentAllowance - amount);
        }

        _transfer(from, to, amount);
        return true;
    }

    // Assembly 优化版本的 transferFrom
    function transferFromOptimized(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert InvalidRecipient(to);
        if (from == address(0)) revert InvalidRecipient(from);

        // 读取并检查 allowance
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(from, msg.sender, amount, currentAllowance);
        }

        // unchecked 更新 allowance
        unchecked {
            _allowances[from][msg.sender] = currentAllowance - amount;
        }

        // 使用优化版本的 transfer
        _transferOptimized(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ApprovalToZeroAddress();

        uint256 currentAllowance = _allowances[msg.sender][spender];
        _approve(msg.sender, spender, currentAllowance + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert ApprovalToZeroAddress();

        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < subtractedValue) {
            revert InsufficientAllowance(msg.sender, spender, subtractedValue, currentAllowance);
        }

        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) {
            revert InsufficientBalance(from, amount, fromBalance);
        }

        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    // Assembly 优化版本的 transfer
    function _transferOptimized(address from, address to, uint256 amount) internal {
        assembly {
            // === Assembly 优化实现 ===
            // keccak256(abi.encodePacked(address, slot))
            // abi.encodePacked 是紧凑编码：address(20字节) + slot(32字节) = 52字节

            // from 槽位 = keccak256(abi.encode(from, BALANCES_SLOT))
            mstore(0x00, from)
            mstore(0x20, BALANCES_SLOT)
            let fromSlot := keccak256(0x00, 0x40)

            // to 槽位
            mstore(0x00, to)
            mstore(0x20, BALANCES_SLOT)
            let toSlot := keccak256(0x00, 0x40)

            // 读取余额并检查
            let fromBalance := sload(fromSlot)
            if lt(fromBalance, amount) {
                revert(0x00, 0x00)
            }

            // 更新余额
            sstore(fromSlot, sub(fromBalance, amount))
            let toBalance := sload(toSlot)
            sstore(toSlot, add(toBalance, amount))

            // 触发事件
            mstore(0x00, amount)
            log3(0x00, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, from, to)
        }
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _mint(address account, uint256 amount) internal {
        if (account == address(0)) revert MintToZeroAddress();

        totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) revert BurnFromZeroAddress();

        uint256 accountBalance = _balances[account];
        if (accountBalance < amount) {
            revert InsufficientBalance(account, amount, accountBalance);
        }

        unchecked {
            _balances[account] = accountBalance - amount;
            totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
    }

    // 公开的 burn 函数 - 燃烧调用者自己的代币
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    // 公开的 burn 函数 - 燃烧指定账户的代币（需要授权）
    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = _allowances[account][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(account, msg.sender, amount, currentAllowance);
        }

        unchecked {
            _approve(account, msg.sender, currentAllowance - amount);
        }

        _burn(account, amount);
    }
}
