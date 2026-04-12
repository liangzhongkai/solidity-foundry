// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title RsgCross01Doc
/// @notice RareSkills: prefer token *callback / hook* flows where the token notifies the receiver instead of the receiver repeatedly initiating pulls that fight composability.
/// @dev A faithful ERC-20 hook demo belongs with token standards; this symbol exists so the README index stays 1:1 with the article list.
contract RsgCross01Doc {
    function notePullVsPushHooks() external pure {}
}

// --- #2 receive / fallback vs explicit deposit() ---

contract RsgCross02Receive {
    uint256 public received;

    receive() external payable {
        received += msg.value;
    }
}

contract RsgCross02Deposit {
    uint256 public received;

    function deposit() external payable {
        received += msg.value;
    }
}

// --- #4 cache external oracle reads ---

contract RsgCrossOracle {
    uint256 public v;

    function set(uint256 x) external {
        v = x;
    }

    function read() external view returns (uint256) {
        return v;
    }
}

contract RsgCross04OracleUncached {
    RsgCrossOracle public immutable o;

    constructor(RsgCrossOracle _o) {
        o = _o;
    }

    function doubled() external view returns (uint256) {
        return o.read() + o.read();
    }
}

contract RsgCross04OracleCached {
    RsgCrossOracle public immutable o;

    constructor(RsgCrossOracle _o) {
        o = _o;
    }

    function doubled() external view returns (uint256) {
        uint256 x = o.read();
        return x + x;
    }
}

// --- #5 batching: two externals vs one ---

contract RsgCrossWorker {
    uint256 public hits;

    function tick() external {
        hits++;
    }

    function tickTwice() external {
        hits++;
        hits++;
    }
}

contract RsgCross05NoBatch {
    function run(address w) external {
        RsgCrossWorker(payable(w)).tick();
        RsgCrossWorker(payable(w)).tick();
    }
}

contract RsgCross05Multicall {
    function run(address w) external {
        RsgCrossWorker(payable(w)).tickTwice();
    }
}

// --- #6 monolith vs split contracts ---

contract RsgCross06SplitA {
    uint256 public x;

    function f() external {
        x++;
    }
}

contract RsgCross06SplitB {
    uint256 public y;

    function g() external {
        y++;
    }
}

contract RsgCross06RunnerSplit {
    function run(address a, address b) external {
        RsgCross06SplitA(payable(a)).f();
        RsgCross06SplitB(payable(b)).g();
    }
}

contract RsgCross06Mono {
    uint256 public x;
    uint256 public y;

    function fg() external {
        x++;
        y++;
    }
}
