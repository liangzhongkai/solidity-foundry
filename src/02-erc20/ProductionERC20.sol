// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title ProductionERC20
/// @notice Full-featured ERC20 with EIP-2612 permit and EIP-5805 delegation
contract ProductionERC20 {
    error InsufficientBalance(address account, uint256 required, uint256 available);
    error InsufficientAllowance(address owner, address spender, uint256 required, uint256 available);
    error InvalidRecipient(address recipient);
    error InvalidSpender(address spender);
    error MintToZeroAddress();
    error BurnFromZeroAddress();
    error ApprovalToZeroAddress();
    error PermitDeadlineExpired();
    error InvalidSigner();
    error ERC5805FutureLookup(uint256 timepoint, uint256 currentBlock);

    uint256 private constant BALANCES_SLOT = 3;

    string public name;
    string public symbol;
    uint8 public immutable DECIMALS;
    uint256 public totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 internal immutable INITIAL_CHAIN_ID;
    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces; // slot 5

    struct Checkpoint {
        uint32 fromBlock;
        uint224 votes;
    }
    mapping(address => address) private _delegates;
    // slither-disable-next-line uninitialized-state -- mapping is auto-initialized in Solidity
    mapping(address => Checkpoint[]) private _delegateCheckpoints;

    // Events with indexed parameters
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

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
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
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

    function transferFromOptimized(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert InvalidRecipient(to);
        if (from == address(0)) revert InvalidRecipient(from);

        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(from, msg.sender, amount, currentAllowance);
        }

        unchecked {
            _allowances[from][msg.sender] = currentAllowance - amount;
        }

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

    /// @dev EIP-2612 requires DOMAIN_SEPARATOR as function name
    // forge-lint: disable-next-line(mixed-case-function)
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view returns (bytes32 result) {
        bytes memory data = abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256("1"),
            block.chainid,
            address(this)
        );
        assembly {
            result := keccak256(add(data, 32), mload(data))
        }
    }

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        if (deadline < block.timestamp) revert PermitDeadlineExpired();

        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );
            if (recoveredAddress == address(0) || recoveredAddress != owner) revert InvalidSigner();
            _approve(owner, spender, value);
        }
    }

    function delegates(address account) external view returns (address) {
        return _delegates[account];
    }

    function getVotes(address account) external view returns (uint256) {
        Checkpoint[] storage ckpts = _delegateCheckpoints[account];
        uint256 len = ckpts.length;
        if (len == 0) return 0;
        return ckpts[len - 1].votes;
    }

    function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {
        if (timepoint >= block.number) revert ERC5805FutureLookup(timepoint, block.number);
        Checkpoint[] storage ckpts = _delegateCheckpoints[account];
        uint256 len = ckpts.length;
        if (len == 0) return 0;
        if (uint256(ckpts[len - 1].fromBlock) <= timepoint) return ckpts[len - 1].votes;
        if (uint256(ckpts[0].fromBlock) > timepoint) return 0;
        uint256 low = 0;
        uint256 high = len - 1;
        while (low < high) {
            uint256 mid = (low + high + 1) / 2;
            if (uint256(ckpts[mid].fromBlock) <= timepoint) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }
        return ckpts[low].votes;
    }

    function delegate(address delegatee) external {
        address fromDelegate = _delegates[msg.sender];
        if (fromDelegate == delegatee) return;

        _delegates[msg.sender] = delegatee;
        uint256 balance = _balances[msg.sender];

        if (fromDelegate != address(0)) {
            uint256 oldVotes = _getVotesAt(fromDelegate);
            uint256 newVotes = oldVotes - balance;
            _pushCheckpoint(fromDelegate, oldVotes, newVotes);
        }
        if (delegatee != address(0)) {
            uint256 oldVotes = _getVotesAt(delegatee);
            uint256 newVotes = oldVotes + balance;
            _pushCheckpoint(delegatee, oldVotes, newVotes);
        }
        emit DelegateChanged(msg.sender, fromDelegate, delegatee);
    }

    function delegateBySig(address delegatee, uint256 nonce_, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external {
        if (expiry < block.timestamp) revert PermitDeadlineExpired();

        bytes memory structEncoded = abi.encode(
            keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)"), delegatee, nonce_, expiry
        );
        bytes32 structHash;
        assembly {
            structHash := keccak256(add(structEncoded, 32), mload(structEncoded))
        }
        bytes memory digestEncoded = abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash);
        bytes32 digest;
        assembly {
            digest := keccak256(add(digestEncoded, 32), mload(digestEncoded))
        }
        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) revert InvalidSigner();
        if (nonces[signer] != nonce_) revert InvalidSigner();

        unchecked {
            nonces[signer]++;
        }

        address fromDelegate = _delegates[signer];
        if (fromDelegate == delegatee) return;

        _delegates[signer] = delegatee;
        uint256 balance = _balances[signer];

        if (fromDelegate != address(0)) {
            uint256 oldVotes = _getVotesAt(fromDelegate);
            uint256 newVotes = oldVotes - balance;
            _pushCheckpoint(fromDelegate, oldVotes, newVotes);
        }
        if (delegatee != address(0)) {
            uint256 oldVotes = _getVotesAt(delegatee);
            uint256 newVotes = oldVotes + balance;
            _pushCheckpoint(delegatee, oldVotes, newVotes);
        }
        emit DelegateChanged(signer, fromDelegate, delegatee);
    }

    function _getVotesAt(address account) internal view returns (uint256) {
        Checkpoint[] storage ckpts = _delegateCheckpoints[account];
        uint256 len = ckpts.length;
        if (len == 0) return 0;
        return ckpts[len - 1].votes;
    }

    function _pushCheckpoint(address delegatee, uint256 oldVotes, uint256 newVotes) internal {
        if (oldVotes == newVotes) return;
        Checkpoint[] storage ckpts = _delegateCheckpoints[delegatee];
        uint32 blockNumber = uint32(block.number);
        if (blockNumber != 0 && ckpts.length > 0 && ckpts[ckpts.length - 1].fromBlock == blockNumber) {
            // forge-lint: disable-next-line(unsafe-typecast) -- votes fit in uint224 (supply << 2^224)
            ckpts[ckpts.length - 1].votes = uint224(newVotes);
        } else {
            // forge-lint: disable-next-line(unsafe-typecast) -- votes fit in uint224 (supply << 2^224)
            ckpts.push(Checkpoint({fromBlock: blockNumber, votes: uint224(newVotes)}));
        }
        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function _moveVotingPower(address fromDelegate, address toDelegate, uint256 amount) internal {
        if (fromDelegate != address(0)) {
            uint256 oldVotes = _getVotesAt(fromDelegate);
            uint256 newVotes = oldVotes - amount;
            _pushCheckpoint(fromDelegate, oldVotes, newVotes);
        }
        if (toDelegate != address(0)) {
            uint256 oldVotes = _getVotesAt(toDelegate);
            uint256 newVotes = oldVotes + amount;
            _pushCheckpoint(toDelegate, oldVotes, newVotes);
        }
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
        _moveVotingPower(_delegates[from], _delegates[to], amount);
    }

    function _transferOptimized(address from, address to, uint256 amount) internal {
        assembly {
            mstore(0x00, from)
            mstore(0x20, BALANCES_SLOT)
            let fromSlot := keccak256(0x00, 0x40)
            mstore(0x00, to)
            mstore(0x20, BALANCES_SLOT)
            let toSlot := keccak256(0x00, 0x40)
            let fromBalance := sload(fromSlot)
            if lt(fromBalance, amount) {
                revert(0x00, 0x00)
            }
            sstore(fromSlot, sub(fromBalance, amount))
            let toBalance := sload(toSlot)
            sstore(toSlot, add(toBalance, amount))
            mstore(0x00, amount)
            log3(0x00, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, from, to)
        }
        _moveVotingPower(_delegates[from], _delegates[to], amount);
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
        _moveVotingPower(address(0), _delegates[account], amount);
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
        _moveVotingPower(_delegates[account], address(0), amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

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
