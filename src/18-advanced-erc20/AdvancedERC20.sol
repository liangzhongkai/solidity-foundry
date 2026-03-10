// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "openzeppelin-contracts@5.4.0/access/Ownable.sol";
import {AccessControl} from "openzeppelin-contracts@5.4.0/access/AccessControl.sol";
import {Pausable} from "openzeppelin-contracts@5.4.0/utils/Pausable.sol";

/// @title AdvancedERC20
/// @notice Full-featured ERC20 with EIP-2612 permit, EIP-5805 vote delegation,
///         Ownable, AccessControl, Pausable, and custom ReentrancyGuard.
/// @dev This contract demonstrates advanced token patterns for learning purposes.
contract AdvancedERC20 is Ownable, AccessControl, Pausable {
    // ============ Errors ============

    error InsufficientBalance(address account, uint256 required, uint256 available);
    error InsufficientAllowance(address owner, address spender, uint256 required, uint256 available);
    error InvalidRecipient(address recipient);
    error MintToZeroAddress();
    error BurnFromZeroAddress();
    error ApprovalToZeroAddress();
    error PermitDeadlineExpired();
    error InvalidSigner();
    error ERC5805FutureLookup(uint256 timepoint, uint256 currentBlock);
    error Reentrancy();

    // ============ Roles ============

    /// @dev Role for accounts allowed to mint tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @dev Role for accounts allowed to pause/unpause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ============ ERC20 Storage ============

    string public name;
    string public symbol;
    uint8 public immutable DECIMALS;
    uint256 public totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ============ EIP-2612 Storage ============

    uint256 internal immutable INITIAL_CHAIN_ID;
    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;

    // ============ EIP-5805 Storage ============

    struct Checkpoint {
        uint32 fromBlock;
        uint224 votes;
    }

    mapping(address => address) private _delegates;
    mapping(address => Checkpoint[]) private _delegateCheckpoints;

    // ============ ReentrancyGuard Storage ============

    uint256 private _entered;

    // ============ Events ============

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    // ============ Modifiers ============

    /// @dev Custom ReentrancyGuard using mutex pattern
    modifier nonReentrant() {
        if (_entered != 0) revert Reentrancy();
        _entered = 1;
        _;
        _entered = 0;
    }

    // ============ Constructor ============

    /// @notice Initializes the token with name, symbol, decimals, and initial supply
    /// @param _name Token name
    /// @param _symbol Token symbol
    /// @param _decimals Token decimals (must be > 0)
    /// @param initialSupply Initial token supply minted to initialOwner
    /// @param initialOwner Address receiving initial supply and admin role
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 initialSupply,
        address initialOwner
    ) Ownable(initialOwner) {
        if (_decimals == 0) revert InvalidRecipient(address(0));
        if (initialOwner == address(0)) revert MintToZeroAddress();

        name = _name;
        symbol = _symbol;
        DECIMALS = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();

        // Grant roles to initial owner
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(MINTER_ROLE, initialOwner);
        _grantRole(PAUSER_ROLE, initialOwner);

        // Mint initial supply
        _mint(initialOwner, initialSupply);
    }

    // ============ ERC20 View Functions ============

    /// @notice Returns the balance of an account
    /// @param account Address to query
    /// @return Balance of the account
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /// @notice Returns the allowance of a spender for an owner
    /// @param owner Token owner address
    /// @param spender Spender address
    /// @return Remaining allowance
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    // ============ ERC20 Mutative Functions ============

    /// @notice Approves a spender to spend tokens on behalf of the caller
    /// @param spender Address to approve
    /// @param amount Amount to approve
    /// @return True if successful
    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ApprovalToZeroAddress();

        _approve(msg.sender, spender, amount);
        return true;
    }

    /// @notice Transfers tokens to a recipient
    /// @param to Recipient address
    /// @param amount Amount to transfer
    /// @return True if successful
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        if (to == address(0)) revert InvalidRecipient(to);

        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Transfers tokens from one address to another using allowance
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Amount to transfer
    /// @return True if successful
    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
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

    /// @notice Increases the allowance of a spender
    /// @param spender Spender address
    /// @param addedValue Amount to add to allowance
    /// @return True if successful
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert ApprovalToZeroAddress();

        uint256 currentAllowance = _allowances[msg.sender][spender];
        _approve(msg.sender, spender, currentAllowance + addedValue);
        return true;
    }

    /// @notice Decreases the allowance of a spender
    /// @param spender Spender address
    /// @param subtractedValue Amount to subtract from allowance
    /// @return True if successful
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

    // ============ EIP-2612 Permit ============

    /// @notice Returns the EIP-712 domain separator
    /// @return Domain separator bytes32
    // forge-lint: disable-next-line(mixed-case-function)
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    /// @dev Computes the EIP-712 domain separator
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

    /// @notice Approves a spender via signature (EIP-2612)
    /// @param owner Token owner signing the permit
    /// @param spender Spender to approve
    /// @param value Amount to approve
    /// @param deadline Timestamp after which permit expires
    /// @param v ECDSA signature component
    /// @param r ECDSA signature component
    /// @param s ECDSA signature component
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

    // ============ EIP-5805 Vote Delegation ============

    /// @notice Returns the delegate of an account
    /// @param account Address to query
    /// @return Delegate address
    function delegates(address account) external view returns (address) {
        return _delegates[account];
    }

    /// @notice Returns the current votes of an account
    /// @param account Address to query
    /// @return Current vote count
    function getVotes(address account) external view returns (uint256) {
        Checkpoint[] storage ckpts = _delegateCheckpoints[account];
        uint256 len = ckpts.length;
        if (len == 0) return 0;
        return ckpts[len - 1].votes;
    }

    /// @notice Returns the votes of an account at a past block
    /// @param account Address to query
    /// @param timepoint Block number to query
    /// @return Vote count at the given block
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {
        if (timepoint >= block.number) revert ERC5805FutureLookup(timepoint, block.number);
        Checkpoint[] storage ckpts = _delegateCheckpoints[account];
        uint256 len = ckpts.length;
        if (len == 0) return 0;
        if (uint256(ckpts[len - 1].fromBlock) <= timepoint) return ckpts[len - 1].votes;
        if (uint256(ckpts[0].fromBlock) > timepoint) return 0;

        // Binary search
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

    /// @notice Delegates voting power to another address
    /// @param delegatee Address to delegate to
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

    /// @notice Delegates voting power via signature
    /// @param delegatee Address to delegate to
    /// @param nonce_ Signer's nonce
    /// @param expiry Timestamp after which signature expires
    /// @param v ECDSA signature component
    /// @param r ECDSA signature component
    /// @param s ECDSA signature component
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

    // ============ Mint/Burn Functions ============

    /// @notice Mints new tokens (only MINTER_ROLE)
    /// @param to Recipient address
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        if (to == address(0)) revert MintToZeroAddress();
        _mint(to, amount);
    }

    /// @notice Burns tokens from the caller
    /// @param amount Amount to burn
    function burn(uint256 amount) external whenNotPaused {
        _burn(msg.sender, amount);
    }

    /// @notice Burns tokens from another account using allowance
    /// @param account Account to burn from
    /// @param amount Amount to burn
    function burnFrom(address account, uint256 amount) external whenNotPaused {
        uint256 currentAllowance = _allowances[account][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(account, msg.sender, amount, currentAllowance);
        }

        unchecked {
            _approve(account, msg.sender, currentAllowance - amount);
        }

        _burn(account, amount);
    }

    // ============ Pause Functions ============

    /// @notice Pauses the contract (only PAUSER_ROLE)
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpauses the contract (only PAUSER_ROLE)
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ============ Internal Functions ============

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
        // slither-disable-next-line incorrect-equality -- intentional: update in-place when same block
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
}
