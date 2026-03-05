// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title PatternVault
/// @notice Production-grade payment vault demonstrating security/perf patterns:
/// - checks-effects-interactions
/// - pull payment
/// - emergency stop (pause)
/// - role-based access control
/// - rate limit + balance cap
/// - custom errors + tight storage packing
contract PatternVault {
    struct Config {
        uint96 maxBalance;
        uint96 epochLimit;
        uint32 epochDuration;
        uint32 emergencyDelay;
    }

    // ---------------------------
    // Errors
    // ---------------------------
    error AlreadyInitialized();
    error ZeroAddress();
    error Unauthorized();
    error Reentrancy();
    error Paused();
    error NotPaused();
    error AmountZero();
    error BalanceCapExceeded(uint256 newBalance, uint256 maxBalance);
    error EpochLimitExceeded(uint256 requested, uint256 remaining);
    error InsufficientSurplus(uint256 requested, uint256 available);
    error NoCredit();
    error TransferFailed();
    error EmergencyDelayActive(uint256 unlockAt, uint256 currentTime);
    error InvalidConfig();

    // ---------------------------
    // Events
    // ---------------------------
    event Initialized(
        address indexed owner, uint96 maxBalance, uint96 epochLimit, uint32 epochDuration, uint32 emergencyDelay
    );
    event OperatorUpdated(address indexed operator, bool enabled);
    event PausedStateChanged(bool paused, uint64 emergencyUnlockAt);
    event Deposited(address indexed from, uint256 amount);
    event PaymentQueued(address indexed operator, address indexed recipient, uint256 amount);
    event Withdrawn(address indexed recipient, uint256 amount);
    event EmergencySwept(address indexed to, uint256 amount);

    // ---------------------------
    // Storage
    // ---------------------------
    address public owner;
    mapping(address => bool) public isOperator;
    mapping(address => uint256) public credits;

    // Total pending liabilities owed to recipients.
    uint256 public totalCredits;

    Config public config;

    uint64 public epochStart;
    uint64 public emergencyUnlockAt;

    bool public paused;
    uint128 public spentInEpoch;

    uint256 private _entered;

    // ---------------------------
    // Modifiers
    // ---------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (!isOperator[msg.sender]) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (_entered != 0) revert Reentrancy();
        _entered = 1;
        _;
        _entered = 0;
    }

    // ---------------------------
    // Lifecycle
    // ---------------------------
    function initialize(address owner_, Config calldata cfg) external {
        if (owner != address(0)) revert AlreadyInitialized();
        if (owner_ == address(0)) revert ZeroAddress();
        if (cfg.maxBalance == 0 || cfg.epochDuration == 0 || cfg.emergencyDelay == 0) revert InvalidConfig();

        owner = owner_;
        config = cfg;
        epochStart = uint64(block.timestamp);
        _entered = 0;

        emit Initialized(owner_, cfg.maxBalance, cfg.epochLimit, cfg.epochDuration, cfg.emergencyDelay);
    }

    // ---------------------------
    // Access control / admin
    // ---------------------------
    function setOperator(address operator, bool enabled) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        isOperator[operator] = enabled;
        emit OperatorUpdated(operator, enabled);
    }

    function setPaused(bool paused_) external onlyOwner {
        if (paused == paused_) {
            if (paused_) revert Paused();
            revert NotPaused();
        }
        paused = paused_;

        uint64 unlockAt = 0;
        if (paused_) {
            unlockAt = uint64(block.timestamp) + config.emergencyDelay;
            emergencyUnlockAt = unlockAt;
        } else {
            emergencyUnlockAt = 0;
        }

        emit PausedStateChanged(paused_, unlockAt);
    }

    // ---------------------------
    // Funds
    // ---------------------------
    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        _deposit(msg.sender, msg.value);
    }

    function _deposit(address from, uint256 amount) internal whenNotPaused {
        if (amount == 0) revert AmountZero();
        uint256 newBalance = address(this).balance;
        if (newBalance > config.maxBalance) revert BalanceCapExceeded(newBalance, config.maxBalance);
        emit Deposited(from, amount);
    }

    /// @notice Queue payment credit for recipient, who later claims via withdraw().
    function queuePayment(address recipient, uint256 amount) public onlyOperator whenNotPaused {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();

        _consumeEpoch(amount);

        uint256 liabilities = totalCredits + amount;
        if (address(this).balance < liabilities) {
            revert InsufficientSurplus(amount, _surplus());
        }

        credits[recipient] += amount;
        totalCredits = liabilities;

        emit PaymentQueued(msg.sender, recipient, amount);
    }

    function batchQueuePayment(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyOperator
        whenNotPaused
    {
        uint256 len = recipients.length;
        if (len == 0 || len != amounts.length) revert InvalidConfig();

        for (uint256 i; i < len; ++i) {
            queuePayment(recipients[i], amounts[i]);
        }
    }

    function withdraw() external nonReentrant {
        uint256 amount = credits[msg.sender];
        if (amount == 0) revert NoCredit();

        // Checks-Effects-Interactions
        credits[msg.sender] = 0;
        totalCredits -= amount;

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Sweeps only surplus funds (never touches owed user credits).
    function emergencySweep(address to, uint256 amount) external onlyOwner nonReentrant {
        if (!paused) revert NotPaused();
        if (to == address(0)) revert ZeroAddress();
        if (block.timestamp < emergencyUnlockAt) {
            revert EmergencyDelayActive(emergencyUnlockAt, block.timestamp);
        }

        uint256 available = _surplus();
        if (amount > available) revert InsufficientSurplus(amount, available);

        (bool ok,) = payable(to).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit EmergencySwept(to, amount);
    }

    // ---------------------------
    // Views
    // ---------------------------
    function surplus() external view returns (uint256) {
        return _surplus();
    }

    function _surplus() internal view returns (uint256) {
        unchecked {
            return address(this).balance - totalCredits;
        }
    }

    // ---------------------------
    // Internals
    // ---------------------------
    function _consumeEpoch(uint256 amount) internal {
        uint256 elapsed = block.timestamp - epochStart;
        if (elapsed >= config.epochDuration) {
            epochStart = uint64(block.timestamp);
            spentInEpoch = 0;
        }

        uint256 newSpent = uint256(spentInEpoch) + amount;
        uint256 limit = config.epochLimit;
        if (newSpent > limit) {
            revert EpochLimitExceeded(amount, limit - spentInEpoch);
        }
        spentInEpoch = uint128(newSpent);
    }
}
