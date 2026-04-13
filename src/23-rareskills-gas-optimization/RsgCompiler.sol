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

/// @notice Splitting the checks lets the first failure short-circuit before evaluating the second predicate.
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

/// @notice Keeping each revert branch separate can give the optimizer simpler control flow to lower.
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

/// @notice Named returns can sometimes let Solidity reuse the return slot instead of building extra temporaries.
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

/// @notice Writing the hot branch positively can compile to slightly simpler branching than negating the condition first.
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

/// @notice `++i` avoids the temporary value bookkeeping associated with post-increment.
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

/// @notice Skipping overflow checks saves gas when the loop's value range is already known to be safe.
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

/// @notice Cache the length and use `++i` so the loop body does less repeated bookkeeping per iteration.
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

/// @notice Once the zero case is handled, the `do...while` loop can use a slightly leaner loop shape.
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

/// @notice Full-word ABI arguments avoid the extra masking and widening that smaller integer types can trigger.
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

/// @notice Logical short-circuiting skips `b()` entirely once `a()` already returned true.
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

/// @notice A private variable avoids the compiler-generated public getter when callers only need the custom accessor.
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

/// @notice Left shift by one is a direct bit operation that can be cheaper than generic multiplication.
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

/// @notice Cache the decoded byte once so the function does not index into calldata twice.
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

/// @notice The branchless form avoids jump-based control flow by computing the sign correction arithmetically.
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

/// @notice Inlining a one-use helper can save the extra jump and stack shuffling for the call boundary.
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

/// @notice Repeated multiplication is cheaper here than the generic exponentiation path for a fixed exponent of three.
contract RsgSolc22Mul {
    function cube(uint256 n) external pure returns (uint256) {
        return n * n * n;
    }
}
