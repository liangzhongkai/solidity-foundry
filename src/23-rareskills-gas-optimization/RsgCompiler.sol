// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// --- #1 strict vs non-strict (measure locally; compiler may erase differences) ---

contract RsgSolc01Strict {
    function check(uint256 x) external pure returns (bool) {
        return x > 0;
    }
}

contract RsgSolc01NonStrict {
    function check(uint256 x) external pure returns (bool) {
        return x >= 1;
    }
}

// --- #2 compound require vs split ---

contract RsgSolc02CompoundRequire {
    function gate(uint256 a, uint256 b) external pure {
        require(a > 0 && b > 0);
    }
}

contract RsgSolc02SplitRequire {
    function gate(uint256 a, uint256 b) external pure {
        require(a > 0);
        require(b > 0);
    }
}

// --- #3 joined revert strings vs split ---

contract RsgSolc03RevertJoin {
    function fail(uint256 x) external pure {
        if (x == 1) revert("alpha");
        if (x == 2) revert("beta");
    }
}

contract RsgSolc03RevertSplit {
    function fail(uint256 x) external pure {
        if (x == 1) {
            revert("alpha");
        }
        if (x == 2) {
            revert("beta");
        }
    }
}

// --- #4 named returns ---

contract RsgSolc04Unnamed {
    function pick(uint256 x) external pure returns (uint256) {
        if (x > 5) return 10;
        return 0;
    }
}

contract RsgSolc04Named {
    function pick(uint256 x) external pure returns (uint256 r) {
        if (x > 5) {
            r = 10;
        } else {
            r = 0;
        }
    }
}

// --- #5 negated condition vs positive branches ---

contract RsgSolc05NegatedIf {
    function route(bool c) external pure returns (uint256) {
        if (!c) return 1;
        return 2;
    }
}

contract RsgSolc05PositiveIf {
    function route(bool c) external pure returns (uint256) {
        if (c) return 2;
        return 1;
    }
}

// --- #6 post-increment vs pre-increment ---

contract RsgSolc06PostInc {
    function run(uint256 n) external pure returns (uint256 s) {
        for (uint256 i; i < n; i++) {
            s += 1;
        }
    }
}

contract RsgSolc06PreInc {
    function run(uint256 n) external pure returns (uint256 s) {
        for (uint256 i; i < n; ++i) {
            s += 1;
        }
    }
}

// --- #7 checked vs unchecked accumulation ---

contract RsgSolc07CheckedSum {
    function sum(uint256[] calldata xs) external pure returns (uint256 s) {
        for (uint256 i; i < xs.length; i++) {
            s += xs[i];
        }
    }
}

contract RsgSolc07UncheckedSum {
    function sum(uint256[] calldata xs) external pure returns (uint256 s) {
        unchecked {
            for (uint256 i; i < xs.length; i++) {
                s += xs[i];
            }
        }
    }
}

// --- #8 naive for-loop vs cached length + ++i ---

contract RsgSolc08LoopNaive {
    function acc(uint256[] calldata xs) external pure returns (uint256 s) {
        for (uint256 i = 0; i < xs.length; i++) {
            s += xs[i];
        }
    }
}

contract RsgSolc08LoopOpt {
    function acc(uint256[] calldata xs) external pure returns (uint256 s) {
        uint256 len = xs.length;
        for (uint256 i; i < len; ++i) {
            s += xs[i];
        }
    }
}

// --- #9 do-while vs for (same arithmetic body) ---

contract RsgSolc09ForLoop {
    function sumTo(uint256 n) external pure returns (uint256 s) {
        for (uint256 i = 1; i <= n; i++) {
            s += i;
        }
    }
}

contract RsgSolc09DoWhile {
    function sumTo(uint256 n) external pure returns (uint256 s) {
        uint256 i = 1;
        if (n == 0) return 0;
        do {
            s += i;
            i++;
        } while (i <= n);
    }
}

// --- #10 loose integer widths vs full-word calldata ---

contract RsgSolc10LooseTypes {
    function add(uint128 a, uint128 b) external pure returns (uint256) {
        return uint256(a) + uint256(b);
    }
}

contract RsgSolc10PackedArgs {
    function add(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }
}

// --- #11 logical OR short-circuit vs bitwise OR ---

contract RsgSolc11Hits {
    uint256 public hitsA;
    uint256 public hitsB;

    function a() external returns (bool) {
        hitsA++;
        return true;
    }

    function b() external returns (bool) {
        hitsB++;
        return true;
    }
}

contract RsgSolc11ShortCircuit {
    RsgSolc11Hits public immutable h;

    constructor(RsgSolc11Hits _h) {
        h = _h;
    }

    function run() external returns (bool) {
        return h.a() || h.b();
    }
}

contract RsgSolc11BothEvaluated {
    RsgSolc11Hits public immutable h;

    constructor(RsgSolc11Hits _h) {
        h = _h;
    }

    function run() external returns (bool) {
        bool ra = h.a();
        bool rb = h.b();
        return ra || rb;
    }
}

// --- #12 auto getter vs explicit view ---

contract RsgSolc12PublicVar {
    uint256 public secret = 42;

    function read() external view returns (uint256) {
        return secret;
    }
}

contract RsgSolc12PrivateGetter {
    uint256 private secret = 42;

    function read() external view returns (uint256) {
        return secret;
    }
}

// --- #15 multiply vs bit-shift ---

contract RsgSolc15Mul {
    function double(uint256 x) external pure returns (uint256) {
        return x * 2;
    }
}

contract RsgSolc15Shift {
    function double(uint256 x) external pure returns (uint256) {
        return x << 1;
    }
}

// --- #16 calldata element read twice vs cached ---

contract RsgSolc16CalldataTwice {
    function head2(bytes calldata d) external pure returns (uint256) {
        return uint256(uint8(d[0])) + uint256(uint8(d[0]));
    }
}

contract RsgSolc16CalldataCache {
    function head2(bytes calldata d) external pure returns (uint256) {
        uint256 b0 = uint256(uint8(d[0]));
        return b0 + b0;
    }
}

// --- #17 branchy vs branchless absolute value ---

contract RsgSolc17Branchy {
    function abs(int256 x) external pure returns (int256) {
        if (x < 0) return -x;
        return x;
    }
}

contract RsgSolc17Branchless {
    function abs(int256 x) external pure returns (int256 v) {
        int256 mask = x >> 255;
        v = (x + mask) ^ mask;
    }
}

// --- #18 internal helper used once: outlined vs inlined (two equivalent entrypoints) ---

contract RsgSolc18Outlined {
    function _bump(uint256 x) private pure returns (uint256) {
        return x + 1;
    }

    function entry(uint256 x) external pure returns (uint256) {
        return _bump(x);
    }
}

contract RsgSolc18Inlined {
    function entry(uint256 x) external pure returns (uint256) {
        return x + 1;
    }
}

// --- #22 exponentiation vs repeated multiply ---

contract RsgSolc22Exp {
    function cube(uint256 n) external pure returns (uint256) {
        return n ** 3;
    }
}

contract RsgSolc22Mul {
    function cube(uint256 n) external pure returns (uint256) {
        return n * n * n;
    }
}
