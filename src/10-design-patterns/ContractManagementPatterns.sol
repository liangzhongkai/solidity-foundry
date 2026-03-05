// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// 1. Contract Decorator Pattern
// Wraps another contract to extend its functionality without modifying it.
interface IBaseAction {
    function executeAction() external returns (uint256);
}

contract BaseAction is IBaseAction {
    function executeAction() external pure returns (uint256) {
        return 100;
    }
}

contract Decorator {
    IBaseAction public base;
    uint256 public executionCount;

    constructor(address _base) {
        base = IBaseAction(_base);
    }

    function executeAction() external returns (uint256) {
        executionCount++; // Extended behavior
        return base.executeAction();
    }
}

// 2. Contract Mediator Pattern
// Acts as a central hub to coordinate communication between components.
contract UserDirectory {
    mapping(address => bool) public isRegistered;

    function register(address user) external {
        isRegistered[user] = true;
    }
}

contract RewardSystem {
    mapping(address => uint256) public rewards;

    function grantReward(address user) external {
        rewards[user] += 10;
    }
}

contract Mediator {
    UserDirectory public directory;
    RewardSystem public rewards;

    constructor() {
        directory = new UserDirectory();
        rewards = new RewardSystem();
    }

    function registerAndReward() external {
        // Mediator coordinates the workflow
        directory.register(msg.sender);
        rewards.grantReward(msg.sender);
    }
}

// 3. Satellite Pattern
// Offloads heavy computation or data to a separate satellite contract.
contract Satellite {
    function complexCalculation(uint256 a, uint256 b) external pure returns (uint256) {
        return (a * b) + (a / (b == 0 ? 1 : b));
    }
}

contract MainContract {
    Satellite public satellite;

    constructor(address _satellite) {
        satellite = Satellite(_satellite);
    }

    function doWork(uint256 a, uint256 b) external view returns (uint256) {
        // Delegates heavy lifting to satellite
        return satellite.complexCalculation(a, b);
    }
}

// 4. Migration Pattern & Inter-family Communication
contract V1Legacy {
    mapping(address => uint256) public balances;
    address public migrationTarget;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function setMigrationTarget(address _target) external {
        require(msg.sender == owner, "Not owner");
        migrationTarget = _target;
    }

    // Inter-family communication: V1 trusts V2 (migrationTarget)
    function migrateData(address user) external returns (uint256) {
        require(msg.sender == migrationTarget, "Only migration target");
        uint256 bal = balances[user];
        balances[user] = 0;
        return bal;
    }
}

contract V2Modern {
    mapping(address => uint256) public balances;
    V1Legacy public legacy;

    constructor(address _legacy) {
        legacy = V1Legacy(_legacy);
    }

    function migrate() external {
        // Pulls state from V1
        uint256 migrated = legacy.migrateData(msg.sender);
        balances[msg.sender] += migrated;
    }
}

// 5. Contract Observer Pattern
// An observer listens to state changes in an observable contract.
interface IObserver {
    function notify(uint256 newValue) external;
}

contract Observable {
    IObserver[] public observers;
    uint256 public value;

    function addObserver(address obs) external {
        observers.push(IObserver(obs));
    }

    function setValue(uint256 _val) external {
        value = _val;
        for (uint256 i = 0; i < observers.length; i++) {
            observers[i].notify(_val);
        }
    }
}

contract Observer is IObserver {
    uint256 public lastSeenValue;

    function notify(uint256 newValue) external {
        lastSeenValue = newValue;
    }
}
