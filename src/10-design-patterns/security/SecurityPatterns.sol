// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title SecurityPatterns
/// @notice Production-style treasury demonstrating modern security patterns:
/// - fork check
/// - guardian/owner access restriction
/// - scoped circuit breakers
/// - rate limit + balance limit
/// - CEI + withdrawal pattern + secure ether transfer
/// - time constraints for withdrawals and termination
/// - mutex reentrancy guard
/// - auto deprecation for risky entrypoints
/// - delayed termination and surplus-only sweep
contract SecurityPatterns {
    struct Config {
        uint96 balanceCap;
        uint96 epochLimit;
        uint64 epochDuration;
        uint64 withdrawalDelay;
        uint64 terminateDelay;
        uint64 deprecationTime;
    }

    uint8 public constant PAUSE_DEPOSITS = 1 << 0;
    uint8 public constant PAUSE_QUEUEING = 1 << 1;

    uint256 public immutable deploymentChainId;
    address public immutable owner;
    address public guardian;

    Config public config;

    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => uint64) public withdrawAvailableAt;

    uint256 public totalLiabilities;
    uint128 public spentInEpoch;
    uint64 public epochStart;
    uint64 public terminateAfter;
    uint8 public pauseFlags;
    bool public isTerminated;
    uint256 private _entered;

    error WrongChain();
    error Terminated();
    error Unauthorized();
    error TransferFailed();
    error ZeroAddress();
    error AmountZero();
    error InvalidConfig();
    error Paused();
    error NotPaused();
    error Deprecated();
    error BalanceCapExceeded(uint256 newBalance, uint256 maxBalance);
    error EpochLimitExceeded(uint256 requested, uint256 remaining);
    error WithdrawalNotReady(uint256 currentTime, uint256 availableAt);
    error NoCredit();
    error TerminationNotReady(uint256 currentTime, uint256 availableAt);
    error InsufficientSurplus(uint256 requested, uint256 available);
    error TerminationNotScheduled();
    error OutstandingLiabilities(uint256 liabilities);
    error Reentrancy();

    event GuardianUpdated(address indexed guardian);
    event PauseFlagsUpdated(uint8 pauseFlags);
    event Deposited(address indexed from, uint256 amount);
    event WithdrawalQueued(address indexed operator, address indexed recipient, uint256 amount, uint64 availableAt);
    event Withdrawn(address indexed recipient, uint256 amount);
    event TerminationScheduled(uint64 terminateAfter);
    event TerminatedState(address indexed sweptTo, uint256 amount);

    modifier onlyValidFork() {
        if (block.chainid != deploymentChainId) revert WrongChain();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOwnerOrGuardian() {
        if (msg.sender != owner && msg.sender != guardian) revert Unauthorized();
        _;
    }

    modifier notTerminated() {
        if (isTerminated) revert Terminated();
        _;
    }

    modifier nonReentrant() {
        if (_entered != 0) revert Reentrancy();
        _entered = 1;
        _;
        _entered = 0;
    }

    constructor(address guardian_, Config memory cfg) {
        if (guardian_ == address(0)) revert ZeroAddress();
        if (
            cfg.balanceCap == 0 || cfg.epochLimit == 0 || cfg.epochDuration == 0 || cfg.withdrawalDelay == 0
                || cfg.terminateDelay == 0 || cfg.deprecationTime <= block.timestamp
        ) revert InvalidConfig();

        deploymentChainId = block.chainid;
        owner = msg.sender;
        guardian = guardian_;
        config = cfg;
        epochStart = uint64(block.timestamp);

        emit GuardianUpdated(guardian_);
    }

    receive() external payable {
        deposit();
    }

    function setGuardian(address guardian_) external onlyOwner {
        if (guardian_ == address(0)) revert ZeroAddress();
        guardian = guardian_;
        emit GuardianUpdated(guardian_);
    }

    function setPauseFlags(uint8 newPauseFlags) external onlyOwnerOrGuardian {
        if (pauseFlags == newPauseFlags) {
            if (newPauseFlags == 0) revert NotPaused();
            revert Paused();
        }

        pauseFlags = newPauseFlags;
        emit PauseFlagsUpdated(newPauseFlags);
    }

    function deposit() public payable onlyValidFork notTerminated {
        if (_isFlagSet(PAUSE_DEPOSITS)) revert Paused();
        if (block.timestamp >= config.deprecationTime) revert Deprecated();
        if (msg.value == 0) revert AmountZero();

        uint256 newBalance = address(this).balance;
        if (newBalance > config.balanceCap) {
            revert BalanceCapExceeded(newBalance, config.balanceCap);
        }

        emit Deposited(msg.sender, msg.value);
    }

    function queueWithdrawal(address recipient, uint256 amount)
        external
        onlyValidFork
        onlyOwnerOrGuardian
        notTerminated
    {
        if (_isFlagSet(PAUSE_QUEUEING)) revert Paused();
        if (block.timestamp >= config.deprecationTime) revert Deprecated();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();

        _consumeEpoch(amount);

        uint256 liabilities = totalLiabilities + amount;
        if (address(this).balance < liabilities) {
            revert InsufficientSurplus(amount, _surplus());
        }

        pendingWithdrawals[recipient] += amount;
        totalLiabilities = liabilities;

        uint64 availableAt = uint64(block.timestamp) + config.withdrawalDelay;
        withdrawAvailableAt[recipient] = availableAt;
        emit WithdrawalQueued(msg.sender, recipient, amount, availableAt);
    }

    function withdraw() external onlyValidFork notTerminated nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert NoCredit();

        uint64 availableAt = withdrawAvailableAt[msg.sender];
        if (block.timestamp < availableAt) revert WithdrawalNotReady(block.timestamp, availableAt);

        pendingWithdrawals[msg.sender] = 0;
        withdrawAvailableAt[msg.sender] = 0;
        totalLiabilities -= amount;

        _secureTransfer(payable(msg.sender), amount);
        emit Withdrawn(msg.sender, amount);
    }

    function scheduleTermination() external onlyValidFork onlyOwner {
        if (pauseFlags == 0) revert NotPaused();

        uint64 unlockAt = uint64(block.timestamp) + config.terminateDelay;
        terminateAfter = unlockAt;
        emit TerminationScheduled(unlockAt);
    }

    function terminateAndSweep(address payable to, uint256 amount) external onlyValidFork onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (terminateAfter == 0) revert TerminationNotScheduled();
        if (block.timestamp < terminateAfter) revert TerminationNotReady(block.timestamp, terminateAfter);

        uint256 available = _surplus();
        if (amount > available) revert InsufficientSurplus(amount, available);

        if (amount == available) {
            if (totalLiabilities != 0) revert OutstandingLiabilities(totalLiabilities);
            isTerminated = true;
        }

        _secureTransfer(to, amount);
        emit TerminatedState(to, amount);
    }

    function sumArray(uint256[] calldata data) external view onlyValidFork notTerminated returns (uint256 sum) {
        uint256 len = data.length;
        for (uint256 i = 0; i < len;) {
            sum += data[i];
            unchecked {
                ++i;
            }
        }
    }

    function paused() external view returns (bool) {
        return pauseFlags != 0;
    }

    function surplus() external view returns (uint256) {
        return _surplus();
    }

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

    function _secureTransfer(address payable to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function _surplus() internal view returns (uint256) {
        unchecked {
            return address(this).balance - totalLiabilities;
        }
    }

    function _isFlagSet(uint8 flag) internal view returns (bool) {
        return (pauseFlags & flag) != 0;
    }
}
