// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

error RsgAsmErr();

/// @notice Solidity `revert RsgAsmErr();` path (compiler-generated ABI encoding).
contract RsgAsm01SolidityRevert {
    function fail() external pure {
        revert RsgAsmErr();
    }
}

/// @notice Same custom error via raw assembly (`revert` with four-byte selector).
/// @dev This skips the compiler's generic ABI-encoding scaffolding and writes only the selector bytes needed for the revert.
contract RsgAsm01AssemblyRevert {
    function fail() external pure {
        bytes4 sel = RsgAsmErr.selector;
        assembly {
            mstore(0x00, sel)
            revert(0x00, 0x04)
        }
    }
}

contract RsgAsm03MinSolidity {
    function min(uint256 a, uint256 b) external pure returns (uint256) {
        return a < b ? a : b;
    }
}

/// @notice The assembly branch writes the result directly, avoiding some Solidity codegen overhead for this tiny primitive.
contract RsgAsm03MinAsm {
    function min(uint256 a, uint256 b) external pure returns (uint256 r) {
        assembly {
            switch lt(a, b)
            case 1 { r := a }
            default { r := b }
        }
    }
}

contract RsgAsm04IsZeroEq {
    function neq(uint256 a, uint256 b) external pure returns (bool) {
        return a != b;
    }
}

/// @notice `xor(a, b)` is zero only when the values are equal, so this avoids a higher-level compare sequence.
contract RsgAsm04Xor {
    function neq(uint256 a, uint256 b) external pure returns (bool r) {
        assembly {
            r := iszero(iszero(xor(a, b)))
        }
    }
}

contract RsgAsm05ZeroCheckSolidity {
    function isZero(address a) external pure returns (bool) {
        return a == address(0);
    }
}

/// @notice `iszero(a)` maps directly to the EVM opcode for a zero-address test.
contract RsgAsm05ZeroCheckAsm {
    function isZero(address a) external pure returns (bool r) {
        assembly {
            r := iszero(a)
        }
    }
}

contract RsgAsm06ThisBalance {
    function bal() external view returns (uint256) {
        return address(this).balance;
    }
}

/// @notice `selfbalance()` is a dedicated opcode that avoids the extra work behind `address(this).balance`.
contract RsgAsm06SelfBalance {
    function bal() external view returns (uint256 v) {
        assembly {
            v := selfbalance()
        }
    }
}

contract RsgAsm07HashSolidity {
    function h(bytes32 a, bytes32 b, bytes32 c) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(a, b, c));
    }
}

/// @notice Write the three words contiguously and hash them directly to avoid `abi.encodePacked` helper overhead.
contract RsgAsm07HashAsm {
    function h(bytes32 a, bytes32 b, bytes32 c) external pure returns (bytes32 r) {
        assembly {
            let p := 0x80
            mstore(p, a)
            mstore(add(p, 32), b)
            mstore(add(p, 64), c)
            r := keccak256(p, 0x60)
        }
    }
}

contract RsgAsm10Mod {
    function odd(uint256 x) external pure returns (bool) {
        return x % 2 == 1;
    }
}

/// @notice Testing the low bit with `and(x, 1)` is cheaper than computing `x % 2`.
contract RsgAsm10Bit {
    function odd(uint256 x) external pure returns (bool r) {
        assembly {
            r := and(x, 1)
        }
    }
}
