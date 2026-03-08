// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Wraps a base action and adds analytics without mutating the original contract.
interface IBaseAction {
    function executeAction() external returns (uint256);
}

contract BaseAction is IBaseAction {
    function executeAction() external pure returns (uint256) {
        return 100;
    }
}

contract Decorator {
    IBaseAction public immutable base;
    uint256 public executionCount;

    event DecoratedExecution(address indexed caller, uint256 result, uint256 executionCount);

    error ZeroAddress();

    constructor(address base_) {
        if (base_ == address(0)) revert ZeroAddress();
        base = IBaseAction(base_);
    }

    function executeAction() external returns (uint256 result) {
        unchecked {
            ++executionCount;
        }

        result = base.executeAction();
        emit DecoratedExecution(msg.sender, result, executionCount);
    }
}

/// @notice Subsystems expose only the minimal entrypoints that the mediator can orchestrate.
contract UserDirectory {
    address public immutable mediator;
    mapping(address => bool) public isRegistered;

    error Unauthorized();

    constructor(address mediator_) {
        mediator = mediator_;
    }

    function register(address user) external {
        if (msg.sender != mediator) revert Unauthorized();
        isRegistered[user] = true;
    }
}

contract RewardSystem {
    address public immutable mediator;
    mapping(address => uint256) public rewards;

    error Unauthorized();

    constructor(address mediator_) {
        mediator = mediator_;
    }

    function grantReward(address user, uint256 amount) external {
        if (msg.sender != mediator) revert Unauthorized();
        rewards[user] += amount;
    }
}

contract Mediator {
    uint256 public constant REGISTRATION_REWARD = 10;

    UserDirectory public immutable directory;
    RewardSystem public immutable rewards;

    error AlreadyRegistered();

    constructor() {
        directory = new UserDirectory(address(this));
        rewards = new RewardSystem(address(this));
    }

    function registerAndReward() external {
        if (directory.isRegistered(msg.sender)) revert AlreadyRegistered();

        directory.register(msg.sender);
        rewards.grantReward(msg.sender, REGISTRATION_REWARD);
    }
}

/// @notice Offloads pure computations into a separate satellite module to keep the main contract small.
contract Satellite {
    error DivisionByZero();

    function complexCalculation(uint256 a, uint256 b) external pure returns (uint256) {
        if (b == 0) revert DivisionByZero();
        return (a * b) + (a / b);
    }
}

contract MainContract {
    Satellite public immutable satellite;

    error ZeroAddress();

    constructor(address satellite_) {
        if (satellite_ == address(0)) revert ZeroAddress();
        satellite = Satellite(satellite_);
    }

    function doWork(uint256 a, uint256 b) external view returns (uint256) {
        return satellite.complexCalculation(a, b);
    }
}

/// @notice Modern migration flow: once a target is set, legacy deposits freeze and users self-migrate.
contract V1Legacy {
    mapping(address => uint256) public balances;

    address public immutable owner;
    address public migrationTarget;
    bool public depositsFrozen;

    event MigrationTargetSet(address indexed target);
    event Migrated(address indexed user, uint256 amount);

    error Unauthorized();
    error ZeroAddress();
    error DepositsFrozen();

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        if (depositsFrozen) revert DepositsFrozen();
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        require(msg.sender == owner, "Unauthorized");
        uint256 bal = address(this).balance;
        if (bal > 0) {
            (bool ok,) = payable(owner).call{value: bal}("");
            require(ok, "transfer failed");
        }
    }

    function setMigrationTarget(address target) external {
        if (msg.sender != owner) revert Unauthorized();
        if (target == address(0)) revert ZeroAddress();

        migrationTarget = target;
        depositsFrozen = true;
        emit MigrationTargetSet(target);
    }

    function migrateData(address user) external returns (uint256 balance) {
        if (msg.sender != migrationTarget) revert Unauthorized();

        balance = balances[user];
        balances[user] = 0;
        emit Migrated(user, balance);
    }
}

contract V2Modern {
    mapping(address => uint256) public balances;
    V1Legacy public immutable legacy;

    event MigrationAccepted(address indexed user, uint256 amount);

    error ZeroAddress();

    constructor(address legacy_) {
        if (legacy_ == address(0)) revert ZeroAddress();
        legacy = V1Legacy(legacy_);
    }

    function migrate() external {
        uint256 migrated = legacy.migrateData(msg.sender);
        balances[msg.sender] += migrated;
        emit MigrationAccepted(msg.sender, migrated);
    }
}

/// @notice Modern observer pattern: push an event on write, let observers sync lazily with a monotonic version.
contract Observable {
    uint256 public value;
    uint256 public version;

    event ValueUpdated(uint256 indexed version, uint256 value);

    function setValue(uint256 newValue) external {
        value = newValue;
        unchecked {
            ++version;
        }

        emit ValueUpdated(version, newValue);
    }
}

contract Observer {
    uint256 public lastSeenValue;
    uint256 public lastSyncedVersion;

    event Synced(address indexed observable, uint256 indexed version, uint256 value);

    error AlreadySynced();

    function sync(address observable_) external {
        Observable observable = Observable(observable_);
        uint256 nextVersion = observable.version();
        if (nextVersion == lastSyncedVersion) revert AlreadySynced();

        lastSeenValue = observable.value();
        lastSyncedVersion = nextVersion;
        emit Synced(observable_, nextVersion, lastSeenValue);
    }
}
