// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// --- Book #1: avoid 0 → 1 storage initialization on hot paths ---

/// @notice First mutation pays the expensive zero → nonzero `SSTORE` when starting from zero.
contract RsgBook01Bad {
    uint256 private v;

    function bump() external {
        v = 1;
    }
}

/// @notice Keep storage nonzero by default so the hot mutation is nonzero → nonzero (cheaper).
/// @dev The constructor pays the 0→1 initialization cost once; subsequent writes stay in the cheap nonzero→nonzero band.
contract RsgBook01Good {
    uint256 private v = 1;

    function bump() external {
        v = 2;
    }
}

// --- Book #2: cache storage reads/writes ---

contract RsgBook02Uncached {
    uint256 private n;

    function increment() external {
        require(n < 10);
        n = n + 1;
    }
}

contract RsgBook02Cached {
    uint256 private n;

    function increment() external {
        uint256 _n = n;
        require(_n < 10);
        n = _n + 1;
    }
}

// --- Book #3: pack scalar state ---

contract RsgBook03Unpacked {
    uint128 public a = 1;
    uint256 public b = 2;
    uint128 public c = 3;

    function touch() external view returns (uint256) {
        return uint256(a) + b + uint256(c);
    }
}

contract RsgBook03Packed {
    uint128 public a = 1;
    uint128 public c = 3;
    uint256 public b = 2;

    function touch() external view returns (uint256) {
        return uint256(a) + b + uint256(c);
    }
}

// --- Book #4: pack structs ---

struct Loose {
    uint128 x;
    uint256 y;
    uint128 z;
}

struct Tight {
    uint128 x;
    uint128 z;
    uint256 y;
}

contract RsgBook04StructLoose {
    Loose public s = Loose(1, 2, 3);

    function sum() external view returns (uint256) {
        return uint256(s.x) + s.y + uint256(s.z);
    }
}

contract RsgBook04StructTight {
    Tight public s = Tight(1, 3, 2);

    function sum() external view returns (uint256) {
        return uint256(s.x) + s.y + uint256(s.z);
    }
}

// --- Book #5: short strings (<32 bytes) pack in one word ---

contract RsgBook05ShortString {
    string public label = "short";

    function bump() external view returns (uint256) {
        return bytes(label).length;
    }
}

contract RsgBook05LongString {
    // 40 ASCII chars → two storage words for the dynamic string body
    string public label = "0123456789012345678901234567890123456789";

    function bump() external view returns (uint256) {
        return bytes(label).length;
    }
}

// --- Book #6: immutable / constant for write-once values ---

contract RsgBook06MutableRead {
    uint256 public factor = 7;

    function scale(uint256 x) external view returns (uint256) {
        return x * factor;
    }
}

contract RsgBook06ImmutableRead {
    uint256 public immutable factor;

    constructor() {
        factor = 7;
    }

    function scale(uint256 x) external view returns (uint256) {
        return x * factor;
    }
}

// --- Book #7: mapping vs array membership scans ---

contract RsgBook07ArrayLookup {
    uint256[] public items;

    constructor() {
        items.push(1);
        items.push(2);
        items.push(3);
        items.push(4);
        items.push(5);
    }

    function contains(uint256 needle) external view returns (bool) {
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i] == needle) return true;
        }
        return false;
    }
}

contract RsgBook07MappingLookup {
    mapping(uint256 => bool) public present;

    constructor() {
        present[1] = true;
        present[2] = true;
        present[3] = true;
        present[4] = true;
        present[5] = true;
    }

    function contains(uint256 needle) external view returns (bool) {
        return present[needle];
    }
}

// --- Book #8: redundant `.length` / bounds work ---

contract RsgBook08LengthTwice {
    uint256[] public arr;

    constructor() {
        for (uint256 i; i < 32; i++) {
            arr.push(i);
        }
    }

    function sum() external view returns (uint256 s) {
        for (uint256 i; i < arr.length; i++) {
            s += arr[i];
            s += arr.length; // second `.length` read each iteration (anti-pattern)
        }
    }
}

contract RsgBook08LengthCached {
    uint256[] public arr;

    constructor() {
        for (uint256 i; i < 32; i++) {
            arr.push(i);
        }
    }

    function sum() external view returns (uint256 s) {
        uint256 len = arr.length;
        for (uint256 i; i < len; i++) {
            s += arr[i];
        }
    }
}

// --- Book #9: bitmap vs many separate storage words used as flags ---

contract RsgBook09ManyBools {
    uint256 private f0;
    uint256 private f1;
    uint256 private f2;
    uint256 private f3;
    uint256 private f4;
    uint256 private f5;
    uint256 private f6;
    uint256 private f7;

    function setAll() external {
        f0 = 1;
        f1 = 1;
        f2 = 1;
        f3 = 1;
        f4 = 1;
        f5 = 1;
        f6 = 1;
        f7 = 1;
    }
}

contract RsgBook09Bitmap {
    uint256 private flags;

    function setAll() external {
        flags = 0xFF;
    }
}

// --- Book #10: SSTORE2 / SSTORE3 (pointer only) ---

/// @notice Large blob storage belongs in dedicated bytecode libraries (SSTORE2/SSTORE3 patterns).
/// @dev This repo does not vendor a production SSTORE2 implementation; measure with your bytecode library of choice.
library RsgBook10Sstore2Note {
    function note() internal pure {}
}

// --- Book #11: storage struct pointer vs memory round-trip ---

contract RsgBook11MemoryRoundtrip {
    struct S {
        uint256 a;
        uint256 b;
    }

    S s;

    constructor() {
        s = S(1, 2);
    }

    function bump() external {
        S memory m = s;
        m.a += 1;
        m.b += 1;
        s = m;
    }
}

contract RsgBook11StoragePtr {
    struct S {
        uint256 a;
        uint256 b;
    }

    S s;

    constructor() {
        s = S(1, 2);
    }

    function bump() external {
        S storage p = s;
        p.a += 1;
        p.b += 1;
    }
}

// --- Book #12: avoid zeroing balances (toy ledger) ---

contract RsgBook12Zeroing {
    uint256 public bal = 100;

    function spendAll() external {
        bal = 0;
    }
}

contract RsgBook12Dust {
    uint256 public bal = 100;

    function spendAll() external {
        bal = 1; // keep dust to avoid next 0→1 write on refill patterns
    }
}

// --- Book #13: count down vs up ---

contract RsgBook13Up {
    function sum(uint256 n) external pure returns (uint256 s) {
        for (uint256 i = 0; i < n; i++) {
            s += i;
        }
    }
}

contract RsgBook13Down {
    function sum(uint256 n) external pure returns (uint256 s) {
        unchecked {
            for (uint256 i = n; i > 0; i--) {
                s += i - 1;
            }
        }
    }
}

// --- Book #14: timestamp width ---

contract RsgBook14WideTime {
    uint256 public ts;

    function setNow() external {
        ts = block.timestamp;
    }
}

contract RsgBook14NarrowTime {
    uint64 public ts;

    function setNow() external {
        ts = uint64(block.timestamp);
    }
}
