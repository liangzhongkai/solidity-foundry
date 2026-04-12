// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Clones} from "openzeppelin-contracts@5.4.0/proxy/Clones.sol";

/// @title RsgDep01 — CREATE nonce address prediction
/// @notice RareSkills tip: deploy dependent contracts in deterministic order so later contracts can embed predicted addresses without extra storage setters.
/// @dev Gas story is mostly deployment-time; see `RsgDep01Factory` for a minimal CREATE ordering sketch.
contract RsgDep01Factory {
    address public child;

    function deploy() external {
        child = address(new RsgDep01Child());
    }
}

contract RsgDep01Child {
    uint256 public x = 1;
}

// --- #2 payable constructor ---

contract RsgDep02NotPayable {
    constructor() {}
}

contract RsgDep02Payable {
    constructor() payable {}
}

// --- #5 internal check vs modifier ---

contract RsgDep05WithModifier {
    uint256 private x;

    modifier chk() {
        require(x < 100);
        _;
    }

    function inc() external chk {
        x++;
    }
}

contract RsgDep05InternalGuard {
    uint256 private x;

    function _chk() internal view {
        require(x < 100);
    }

    function inc() external {
        _chk();
        x++;
    }
}

// --- #6 minimal clone vs full contract ---

contract RsgDep06Impl {
    uint256 public x = 1;

    function inc() external {
        x++;
    }
}

contract RsgDep06Full {
    RsgDep06Impl public immutable impl;

    constructor() {
        impl = new RsgDep06Impl();
    }

    function bump() external {
        impl.inc();
    }
}

contract RsgDep06Clone {
    RsgDep06Impl public immutable child;

    constructor(address implementation) {
        child = RsgDep06Impl(payable(Clones.clone(implementation)));
    }

    function bump() external {
        child.inc();
    }
}

// --- #7 admin payable ---

contract RsgDep07AdminNonPayable {
    uint256 private x;

    function adminSet() external {
        x = 1;
    }
}

contract RsgDep07AdminPayable {
    uint256 private x;

    function adminSet() external payable {
        x = 1;
    }
}

// --- #8 custom errors vs long require strings ---

error RsgDepBad();

contract RsgDep08RequireString {
    function gate(uint256 x) external pure {
        require(x > 0, "value must be strictly positive");
    }
}

contract RsgDep08CustomError {
    function gate(uint256 x) external pure {
        if (x == 0) revert RsgDepBad();
    }
}
