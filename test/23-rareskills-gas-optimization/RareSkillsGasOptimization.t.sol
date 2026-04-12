// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {console} from "forge-std@1.14.0/console.sol";
import {Hashes} from "openzeppelin-contracts@5.4.0/utils/cryptography/Hashes.sol";

import {RsgBook01Bad, RsgBook01Good} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";
import {RsgBook02Uncached, RsgBook02Cached} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";
import {RsgBook03Unpacked, RsgBook03Packed} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";
import {RsgBook04StructLoose, RsgBook04StructTight} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";
import {RsgBook05ShortString, RsgBook05LongString} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";
import {RsgBook06MutableRead, RsgBook06ImmutableRead} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";
import {RsgBook07ArrayLookup, RsgBook07MappingLookup} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";
import {RsgBook08LengthTwice, RsgBook08LengthCached} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";
import {RsgBook09ManyBools, RsgBook09Bitmap} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";
import {RsgBook11MemoryRoundtrip, RsgBook11StoragePtr} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";
import {RsgBook12Zeroing, RsgBook12Dust} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";
import {RsgBook13Up, RsgBook13Down} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";
import {RsgBook14WideTime, RsgBook14NarrowTime} from "../../src/23-rareskills-gas-optimization/RsgBook.sol";

import {
    RsgDep01Factory,
    RsgDep02NotPayable,
    RsgDep02Payable,
    RsgDep05WithModifier,
    RsgDep05InternalGuard,
    RsgDep06Impl,
    RsgDep06Full,
    RsgDep06Clone,
    RsgDep07AdminNonPayable,
    RsgDep07AdminPayable,
    RsgDep08RequireString,
    RsgDep08CustomError
} from "../../src/23-rareskills-gas-optimization/RsgDeployment.sol";

import {
    RsgCross02Receive,
    RsgCross02Deposit,
    RsgCrossOracle,
    RsgCross04OracleUncached,
    RsgCross04OracleCached,
    RsgCrossWorker,
    RsgCross05NoBatch,
    RsgCross05Multicall,
    RsgCross06SplitA,
    RsgCross06SplitB,
    RsgCross06RunnerSplit,
    RsgCross06Mono
} from "../../src/23-rareskills-gas-optimization/RsgCross.sol";

import {
    RsgDesign01MultiDelegate,
    RsgDesign02Merkle,
    RsgDesign02Ecdsa
} from "../../src/23-rareskills-gas-optimization/RsgDesign.sol";

import {RsgCalldata02Signed, RsgCalldata02Unsigned} from "../../src/23-rareskills-gas-optimization/RsgCalldata.sol";
import {
    RsgCalldata03MemoryCopy,
    RsgCalldata03CalldataSlice
} from "../../src/23-rareskills-gas-optimization/RsgCalldata.sol";

import {
    RsgAsm01SolidityRevert,
    RsgAsm01AssemblyRevert,
    RsgAsm03MinSolidity,
    RsgAsm03MinAsm,
    RsgAsm04IsZeroEq,
    RsgAsm04Xor,
    RsgAsm05ZeroCheckSolidity,
    RsgAsm05ZeroCheckAsm,
    RsgAsm06ThisBalance,
    RsgAsm06SelfBalance,
    RsgAsm07HashSolidity,
    RsgAsm07HashAsm,
    RsgAsm10Mod,
    RsgAsm10Bit
} from "../../src/23-rareskills-gas-optimization/RsgAssembly.sol";

import {
    RsgSolc02CompoundRequire,
    RsgSolc02SplitRequire,
    RsgSolc03RevertJoin,
    RsgSolc03RevertSplit,
    RsgSolc04Unnamed,
    RsgSolc04Named,
    RsgSolc05NegatedIf,
    RsgSolc05PositiveIf,
    RsgSolc06PostInc,
    RsgSolc06PreInc,
    RsgSolc07CheckedSum,
    RsgSolc07UncheckedSum,
    RsgSolc08LoopNaive,
    RsgSolc08LoopOpt,
    RsgSolc09ForLoop,
    RsgSolc09DoWhile,
    RsgSolc10LooseTypes,
    RsgSolc10PackedArgs,
    RsgSolc11Hits,
    RsgSolc11ShortCircuit,
    RsgSolc11BothEvaluated,
    RsgSolc12PublicVar,
    RsgSolc12PrivateGetter,
    RsgSolc15Mul,
    RsgSolc15Shift,
    RsgSolc16CalldataTwice,
    RsgSolc16CalldataCache,
    RsgSolc17Branchy,
    RsgSolc17Branchless,
    RsgSolc18Outlined,
    RsgSolc18Inlined,
    RsgSolc22Exp,
    RsgSolc22Mul
} from "../../src/23-rareskills-gas-optimization/RsgCompiler.sol";

import {
    RsgOut01Public,
    RsgOut01External,
    RsgOut02GtZero,
    RsgOut02NeZero
} from "../../src/23-rareskills-gas-optimization/RsgOutdated.sol";

contract RareSkillsGasOptimizationTest is Test {
    function _gasStatic(address target, bytes memory data) internal view returns (uint256) {
        uint256 g = gasleft();
        (bool ok,) = target.staticcall(data);
        require(ok, "staticcall");
        return g - gasleft();
    }

    function _gasCall(address target, bytes memory data) internal returns (uint256) {
        uint256 g = gasleft();
        (bool ok,) = target.call(data);
        require(ok, "call");
        return g - gasleft();
    }

    function _gasCallValue(address target, bytes memory data, uint256 value) internal returns (uint256) {
        uint256 g = gasleft();
        (bool ok,) = target.call{value: value}(data);
        require(ok, "call value");
        return g - gasleft();
    }

    function _gasCallExpectFail(address target, bytes memory data) internal returns (uint256) {
        uint256 g = gasleft();
        (bool ok,) = target.call(data);
        require(!ok, "expected fail");
        return g - gasleft();
    }

    function test_Gas_Book01_firstStorageWrite() public {
        RsgBook01Bad bad = new RsgBook01Bad();
        RsgBook01Good good = new RsgBook01Good();
        uint256 gBad = _gasCall(address(bad), abi.encodeCall(RsgBook01Bad.bump, ()));
        uint256 gGood = _gasCall(address(good), abi.encodeCall(RsgBook01Good.bump, ()));
        console.log("Book01 bad (0->1 style first write) gas:", gBad);
        console.log("Book01 good (1->2 transition) gas:", gGood);
        assertLt(gGood, gBad, "warm nonzero transition should be cheaper than cold zero init");
    }

    function test_Gas_Book02_cacheStorage() public {
        RsgBook02Uncached a = new RsgBook02Uncached();
        RsgBook02Cached b = new RsgBook02Cached();
        uint256 gA = _gasCall(address(a), abi.encodeCall(RsgBook02Uncached.increment, ()));
        uint256 gB = _gasCall(address(b), abi.encodeCall(RsgBook02Cached.increment, ()));
        console.log("Book02 uncached gas:", gA);
        console.log("Book02 cached gas:", gB);
        assertLt(gB, gA);
    }

    function test_Gas_Book03_slotPacking() public {
        RsgBook03Unpacked u = new RsgBook03Unpacked();
        RsgBook03Packed p = new RsgBook03Packed();
        uint256 gU = _gasStatic(address(u), abi.encodeCall(RsgBook03Unpacked.touch, ()));
        uint256 gP = _gasStatic(address(p), abi.encodeCall(RsgBook03Packed.touch, ()));
        console.log("Book03 unpacked touch gas:", gU);
        console.log("Book03 packed touch gas:", gP);
    }

    function test_Gas_Book04_structPacking() public {
        RsgBook04StructLoose a = new RsgBook04StructLoose();
        RsgBook04StructTight b = new RsgBook04StructTight();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgBook04StructLoose.sum, ()));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgBook04StructTight.sum, ()));
        console.log("Book04 loose struct sum gas:", gA);
        console.log("Book04 tight struct sum gas:", gB);
    }

    function test_Gas_Book05_shortString() public {
        RsgBook05ShortString s = new RsgBook05ShortString();
        RsgBook05LongString l = new RsgBook05LongString();
        uint256 gS = _gasStatic(address(s), abi.encodeCall(RsgBook05ShortString.bump, ()));
        uint256 gL = _gasStatic(address(l), abi.encodeCall(RsgBook05LongString.bump, ()));
        console.log("Book05 short string read gas:", gS);
        console.log("Book05 long string read gas:", gL);
        // Compiler + layout effects can invert the naive expectation; article says measure both.
    }

    function test_Gas_Book06_immutableVsStorageRead() public {
        RsgBook06MutableRead m = new RsgBook06MutableRead();
        RsgBook06ImmutableRead i = new RsgBook06ImmutableRead();
        uint256 gM = _gasStatic(address(m), abi.encodeCall(RsgBook06MutableRead.scale, (3)));
        uint256 gI = _gasStatic(address(i), abi.encodeCall(RsgBook06ImmutableRead.scale, (3)));
        console.log("Book06 mutable storage read gas:", gM);
        console.log("Book06 immutable read gas:", gI);
        assertLt(gI, gM);
    }

    function test_Gas_Book07_mappingVsScan() public {
        RsgBook07ArrayLookup a = new RsgBook07ArrayLookup();
        RsgBook07MappingLookup m = new RsgBook07MappingLookup();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgBook07ArrayLookup.contains, (5)));
        uint256 gM = _gasStatic(address(m), abi.encodeCall(RsgBook07MappingLookup.contains, (5)));
        console.log("Book07 array scan gas:", gA);
        console.log("Book07 mapping lookup gas:", gM);
        assertLt(gM, gA);
    }

    function test_Gas_Book08_cachedLength() public {
        RsgBook08LengthTwice a = new RsgBook08LengthTwice();
        RsgBook08LengthCached b = new RsgBook08LengthCached();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgBook08LengthTwice.sum, ()));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgBook08LengthCached.sum, ()));
        console.log("Book08 length twice gas:", gA);
        console.log("Book08 length cached gas:", gB);
        assertLt(gB, gA);
    }

    function test_Gas_Book09_bitmap() public {
        RsgBook09ManyBools many = new RsgBook09ManyBools();
        RsgBook09Bitmap bmp = new RsgBook09Bitmap();
        uint256 gMany = _gasCall(address(many), abi.encodeCall(RsgBook09ManyBools.setAll, ()));
        uint256 gBmp = _gasCall(address(bmp), abi.encodeCall(RsgBook09Bitmap.setAll, ()));
        console.log("Book09 many storage words gas:", gMany);
        console.log("Book09 bitmap gas:", gBmp);
        assertLt(gBmp, gMany);
    }

    function test_Gas_Book11_storagePointer() public {
        RsgBook11MemoryRoundtrip m = new RsgBook11MemoryRoundtrip();
        RsgBook11StoragePtr s = new RsgBook11StoragePtr();
        uint256 gM = _gasCall(address(m), abi.encodeCall(RsgBook11MemoryRoundtrip.bump, ()));
        uint256 gS = _gasCall(address(s), abi.encodeCall(RsgBook11StoragePtr.bump, ()));
        console.log("Book11 memory roundtrip gas:", gM);
        console.log("Book11 storage pointer gas:", gS);
        assertLt(gS, gM);
    }

    function test_Gas_Book12_dustBalance() public {
        RsgBook12Zeroing z = new RsgBook12Zeroing();
        RsgBook12Dust d = new RsgBook12Dust();
        uint256 gZ = _gasCall(address(z), abi.encodeCall(RsgBook12Zeroing.spendAll, ()));
        uint256 gD = _gasCall(address(d), abi.encodeCall(RsgBook12Dust.spendAll, ()));
        console.log("Book12 zeroing gas:", gZ);
        console.log("Book12 dust gas:", gD);
    }

    function test_Gas_Book13_countDown() public {
        uint256 n = 64;
        RsgBook13Up u = new RsgBook13Up();
        RsgBook13Down d = new RsgBook13Down();
        uint256 gU = _gasStatic(address(u), abi.encodeCall(RsgBook13Up.sum, (n)));
        uint256 gD = _gasStatic(address(d), abi.encodeCall(RsgBook13Down.sum, (n)));
        console.log("Book13 up loop gas:", gU);
        console.log("Book13 down loop gas:", gD);
    }

    function test_Gas_Book14_narrowTimestamp() public {
        RsgBook14WideTime w = new RsgBook14WideTime();
        RsgBook14NarrowTime n = new RsgBook14NarrowTime();
        uint256 gW = _gasCall(address(w), abi.encodeCall(RsgBook14WideTime.setNow, ()));
        uint256 gN = _gasCall(address(n), abi.encodeCall(RsgBook14NarrowTime.setNow, ()));
        console.log("Book14 uint256 timestamp store gas:", gW);
        console.log("Book14 uint64 timestamp store gas:", gN);
    }

    function test_Gas_Dep05_modifierVsInternal() public {
        RsgDep05WithModifier m = new RsgDep05WithModifier();
        RsgDep05InternalGuard i = new RsgDep05InternalGuard();
        uint256 gM = _gasCall(address(m), abi.encodeCall(RsgDep05WithModifier.inc, ()));
        uint256 gI = _gasCall(address(i), abi.encodeCall(RsgDep05InternalGuard.inc, ()));
        console.log("Dep05 modifier gas:", gM);
        console.log("Dep05 internal guard gas:", gI);
    }

    function test_Gas_Dep06_cloneVsFull() public {
        RsgDep06Impl impl = new RsgDep06Impl();
        RsgDep06Full full = new RsgDep06Full();
        RsgDep06Clone cl = new RsgDep06Clone(address(impl));
        uint256 gFull = _gasCall(address(full), abi.encodeCall(RsgDep06Full.bump, ()));
        uint256 gClone = _gasCall(address(cl), abi.encodeCall(RsgDep06Clone.bump, ()));
        console.log("Dep06 full impl bump gas:", gFull);
        console.log("Dep06 clone bump gas:", gClone);
    }

    function test_Gas_Dep07_payableAdmin() public {
        RsgDep07AdminNonPayable a = new RsgDep07AdminNonPayable();
        RsgDep07AdminPayable b = new RsgDep07AdminPayable();
        uint256 gA = _gasCall(address(a), abi.encodeCall(RsgDep07AdminNonPayable.adminSet, ()));
        uint256 gB = _gasCall(address(b), abi.encodeCall(RsgDep07AdminPayable.adminSet, ()));
        console.log("Dep07 non-payable admin gas:", gA);
        console.log("Dep07 payable admin gas:", gB);
    }

    function test_Gas_Dep08_customError() public {
        RsgDep08RequireString a = new RsgDep08RequireString();
        RsgDep08CustomError b = new RsgDep08CustomError();
        uint256 gA = _gasCallExpectFail(address(a), abi.encodeCall(RsgDep08RequireString.gate, (0)));
        uint256 gB = _gasCallExpectFail(address(b), abi.encodeCall(RsgDep08CustomError.gate, (0)));
        console.log("Dep08 require string revert gas:", gA);
        console.log("Dep08 custom error revert gas:", gB);
        assertLt(gB, gA);
    }

    function test_Gas_Cross02_receiveVsDeposit() public {
        RsgCross02Receive recv = new RsgCross02Receive();
        RsgCross02Deposit dep = new RsgCross02Deposit();
        uint256 gRecv = _gasCallValue(address(recv), hex"", 1 wei);
        uint256 gDep = _gasCallValue(address(dep), abi.encodeCall(RsgCross02Deposit.deposit, ()), 1 wei);
        console.log("Cross02 receive() gas:", gRecv);
        console.log("Cross02 deposit() gas:", gDep);
        assertLt(gRecv, gDep);
    }

    function test_Gas_Cross04_cacheOracle() public {
        RsgCrossOracle o = new RsgCrossOracle();
        o.set(123);
        RsgCross04OracleUncached u = new RsgCross04OracleUncached(o);
        RsgCross04OracleCached c = new RsgCross04OracleCached(o);
        uint256 gU = _gasStatic(address(u), abi.encodeCall(RsgCross04OracleUncached.doubled, ()));
        uint256 gC = _gasStatic(address(c), abi.encodeCall(RsgCross04OracleCached.doubled, ()));
        console.log("Cross04 uncached doubled gas:", gU);
        console.log("Cross04 cached doubled gas:", gC);
        assertLt(gC, gU);
    }

    function test_Gas_Cross05_multicallStyle() public {
        RsgCrossWorker w = new RsgCrossWorker();
        RsgCross05NoBatch nb = new RsgCross05NoBatch();
        RsgCross05Multicall mc = new RsgCross05Multicall();
        uint256 gNb = _gasCall(address(nb), abi.encodeCall(RsgCross05NoBatch.run, (address(w))));
        uint256 gMc = _gasCall(address(mc), abi.encodeCall(RsgCross05Multicall.run, (address(w))));
        console.log("Cross05 two externals gas:", gNb);
        console.log("Cross05 single external gas:", gMc);
        assertLt(gMc, gNb);
    }

    function test_Gas_Cross06_monolith() public {
        RsgCross06SplitA a = new RsgCross06SplitA();
        RsgCross06SplitB b = new RsgCross06SplitB();
        RsgCross06RunnerSplit r = new RsgCross06RunnerSplit();
        RsgCross06Mono m = new RsgCross06Mono();
        uint256 gSplit = _gasCall(address(r), abi.encodeCall(RsgCross06RunnerSplit.run, (address(a), address(b))));
        uint256 gMono = _gasCall(address(m), abi.encodeCall(RsgCross06Mono.fg, ()));
        console.log("Cross06 split contracts gas:", gSplit);
        console.log("Cross06 monolith gas:", gMono);
        assertLt(gMono, gSplit);
    }

    function test_Gas_Design02_merkleVsEcdsa() public {
        bytes32 leafA = keccak256(bytes("A"));
        bytes32 leafB = keccak256(bytes("B"));
        bytes32 root = Hashes.commutativeKeccak256(leafA, leafB);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leafB;
        RsgDesign02Merkle merkle = new RsgDesign02Merkle(root);
        uint256 gMerkle = _gasStatic(address(merkle), abi.encodeCall(RsgDesign02Merkle.isAllowed, (proof, leafA)));

        // well-known anvil test private key (never use in production)
        uint256 pk = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address signer = vm.addr(pk);
        bytes32 digest = keccak256("digest");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        RsgDesign02Ecdsa ecs = new RsgDesign02Ecdsa(signer);
        uint256 gEc = _gasStatic(address(ecs), abi.encodeCall(RsgDesign02Ecdsa.isAllowed, (digest, sig)));
        console.log("Design02 merkle verify gas:", gMerkle);
        console.log("Design02 ECDSA recover gas:", gEc);
    }

    function test_Gas_Calldata02_signedVsUnsigned() public {
        RsgCalldata02Signed s = new RsgCalldata02Signed();
        RsgCalldata02Unsigned u = new RsgCalldata02Unsigned();
        uint256 gS = _gasStatic(address(s), abi.encodeCall(RsgCalldata02Signed.sum, (-1, -2)));
        uint256 gU = _gasStatic(address(u), abi.encodeCall(RsgCalldata02Unsigned.sum, (1, 2)));
        console.log("Calldata02 signed sum gas:", gS);
        console.log("Calldata02 unsigned sum gas:", gU);
    }

    function test_Gas_Calldata03_memoryVsCalldataHash() public {
        bytes memory payload = new bytes(160);
        RsgCalldata03MemoryCopy m = new RsgCalldata03MemoryCopy();
        RsgCalldata03CalldataSlice c = new RsgCalldata03CalldataSlice();
        uint256 gM = _gasStatic(address(m), abi.encodeCall(RsgCalldata03MemoryCopy.hash, (payload)));
        uint256 gC = _gasStatic(address(c), abi.encodeCall(RsgCalldata03CalldataSlice.hash, (payload)));
        console.log("Calldata03 memory copy+hash gas:", gM);
        console.log("Calldata03 calldata slice hash gas:", gC);
        assertLt(gC, gM);
    }

    function test_Gas_Asm01_revertPath() public {
        RsgAsm01SolidityRevert a = new RsgAsm01SolidityRevert();
        RsgAsm01AssemblyRevert b = new RsgAsm01AssemblyRevert();
        uint256 gA = _gasCallExpectFail(address(a), abi.encodeCall(RsgAsm01SolidityRevert.fail, ()));
        uint256 gB = _gasCallExpectFail(address(b), abi.encodeCall(RsgAsm01AssemblyRevert.fail, ()));
        console.log("Asm01 solidity revert gas:", gA);
        console.log("Asm01 assembly revert gas:", gB);
    }

    function test_Gas_Asm03_min() public {
        RsgAsm03MinSolidity s = new RsgAsm03MinSolidity();
        RsgAsm03MinAsm a = new RsgAsm03MinAsm();
        uint256 gS = _gasStatic(address(s), abi.encodeCall(RsgAsm03MinSolidity.min, (3, 9)));
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgAsm03MinAsm.min, (3, 9)));
        console.log("Asm03 solidity min gas:", gS);
        console.log("Asm03 assembly min gas:", gA);
    }

    function test_Gas_Asm06_selfbalance() public {
        RsgAsm06ThisBalance a = new RsgAsm06ThisBalance();
        RsgAsm06SelfBalance b = new RsgAsm06SelfBalance();
        vm.deal(address(a), 1 ether);
        vm.deal(address(b), 1 ether);
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgAsm06ThisBalance.bal, ()));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgAsm06SelfBalance.bal, ()));
        console.log("Asm06 address(this).balance gas:", gA);
        console.log("Asm06 selfbalance gas:", gB);
    }

    function test_Gas_Asm07_hash96() public {
        bytes32 x = keccak256("x");
        bytes32 y = keccak256("y");
        bytes32 z = keccak256("z");
        RsgAsm07HashSolidity s = new RsgAsm07HashSolidity();
        RsgAsm07HashAsm a = new RsgAsm07HashAsm();
        uint256 gS = _gasStatic(address(s), abi.encodeCall(RsgAsm07HashSolidity.h, (x, y, z)));
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgAsm07HashAsm.h, (x, y, z)));
        console.log("Asm07 solidity abi.encodePacked hash gas:", gS);
        console.log("Asm07 assembly contiguous hash gas:", gA);
        assertEq(s.h(x, y, z), a.h(x, y, z), "assembly and solidity hashes must match");
        assertLt(gA, gS);
    }

    function test_Gas_Asm10_oddCheck() public {
        RsgAsm10Mod m = new RsgAsm10Mod();
        RsgAsm10Bit b = new RsgAsm10Bit();
        uint256 gM = _gasStatic(address(m), abi.encodeCall(RsgAsm10Mod.odd, (999)));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgAsm10Bit.odd, (999)));
        console.log("Asm10 modulo gas:", gM);
        console.log("Asm10 bit test gas:", gB);
        assertLt(gB, gM);
    }

    function test_Gas_Solc02_splitRequire() public {
        RsgSolc02CompoundRequire a = new RsgSolc02CompoundRequire();
        RsgSolc02SplitRequire b = new RsgSolc02SplitRequire();
        uint256 gA = _gasCallExpectFail(address(a), abi.encodeCall(RsgSolc02CompoundRequire.gate, (0, 1)));
        uint256 gB = _gasCallExpectFail(address(b), abi.encodeCall(RsgSolc02SplitRequire.gate, (0, 1)));
        console.log("Solc02 compound require fail gas:", gA);
        console.log("Solc02 split require fail gas:", gB);
    }

    function test_Gas_Solc06_preIncrement() public {
        RsgSolc06PostInc p = new RsgSolc06PostInc();
        RsgSolc06PreInc r = new RsgSolc06PreInc();
        uint256 n = 32;
        uint256 gP = _gasStatic(address(p), abi.encodeCall(RsgSolc06PostInc.run, (n)));
        uint256 gR = _gasStatic(address(r), abi.encodeCall(RsgSolc06PreInc.run, (n)));
        console.log("Solc06 post-inc loop gas:", gP);
        console.log("Solc06 pre-inc loop gas:", gR);
        assertLt(gR, gP);
    }

    function test_Gas_Solc07_unchecked() public {
        uint256[] memory xs = new uint256[](32);
        for (uint256 i; i < 32; i++) {
            xs[i] = i + 1;
        }
        RsgSolc07CheckedSum a = new RsgSolc07CheckedSum();
        RsgSolc07UncheckedSum b = new RsgSolc07UncheckedSum();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgSolc07CheckedSum.sum, (xs)));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgSolc07UncheckedSum.sum, (xs)));
        console.log("Solc07 checked sum gas:", gA);
        console.log("Solc07 unchecked sum gas:", gB);
        assertLt(gB, gA);
    }

    function test_Gas_Solc08_loopOpt() public {
        uint256[] memory xs = new uint256[](32);
        for (uint256 i; i < 32; i++) {
            xs[i] = i;
        }
        RsgSolc08LoopNaive n = new RsgSolc08LoopNaive();
        RsgSolc08LoopOpt o = new RsgSolc08LoopOpt();
        uint256 gN = _gasStatic(address(n), abi.encodeCall(RsgSolc08LoopNaive.acc, (xs)));
        uint256 gO = _gasStatic(address(o), abi.encodeCall(RsgSolc08LoopOpt.acc, (xs)));
        console.log("Solc08 naive loop gas:", gN);
        console.log("Solc08 cached length ++i gas:", gO);
        assertLt(gO, gN);
    }

    function test_Gas_Solc11_shortCircuit() public {
        RsgSolc11Hits h = new RsgSolc11Hits();
        RsgSolc11ShortCircuit s = new RsgSolc11ShortCircuit(h);
        RsgSolc11BothEvaluated e = new RsgSolc11BothEvaluated(h);
        s.run();
        assertEq(h.hitsA(), 1);
        assertEq(h.hitsB(), 0);
        h = new RsgSolc11Hits();
        e = new RsgSolc11BothEvaluated(h);
        e.run();
        assertEq(h.hitsA(), 1);
        assertEq(h.hitsB(), 1);
    }

    function test_Gas_Solc15_shiftVsMul() public {
        RsgSolc15Mul m = new RsgSolc15Mul();
        RsgSolc15Shift s = new RsgSolc15Shift();
        uint256 gM = _gasStatic(address(m), abi.encodeCall(RsgSolc15Mul.double, (9)));
        uint256 gS = _gasStatic(address(s), abi.encodeCall(RsgSolc15Shift.double, (9)));
        console.log("Solc15 multiply gas:", gM);
        console.log("Solc15 shift gas:", gS);
        assertLt(gS, gM);
    }

    function test_Gas_Solc16_calldataCache() public {
        bytes memory buf = new bytes(1);
        buf[0] = 0xAB;
        RsgSolc16CalldataTwice t = new RsgSolc16CalldataTwice();
        RsgSolc16CalldataCache c = new RsgSolc16CalldataCache();
        uint256 gT = _gasStatic(address(t), abi.encodeCall(RsgSolc16CalldataTwice.head2, (buf)));
        uint256 gC = _gasStatic(address(c), abi.encodeCall(RsgSolc16CalldataCache.head2, (buf)));
        console.log("Solc16 two calldata index reads gas:", gT);
        console.log("Solc16 cached calldata head gas:", gC);
        assertLt(gC, gT);
    }

    function test_Gas_Solc22_mulVsExp() public {
        RsgSolc22Exp e = new RsgSolc22Exp();
        RsgSolc22Mul m = new RsgSolc22Mul();
        uint256 gE = _gasStatic(address(e), abi.encodeCall(RsgSolc22Exp.cube, (7)));
        uint256 gM = _gasStatic(address(m), abi.encodeCall(RsgSolc22Mul.cube, (7)));
        console.log("Solc22 exponent cube gas:", gE);
        console.log("Solc22 multiply cube gas:", gM);
        assertLt(gM, gE);
    }

    function test_Gas_Outdated_compare() public {
        RsgOut01Public p = new RsgOut01Public();
        RsgOut01External e = new RsgOut01External();
        uint256 gP = _gasStatic(address(p), abi.encodeCall(RsgOut01Public.f, (5)));
        uint256 gE = _gasStatic(address(e), abi.encodeCall(RsgOut01External.f, (5)));
        console.log("Outdated01 public dispatch gas:", gP);
        console.log("Outdated01 external dispatch gas:", gE);

        RsgOut02GtZero a = new RsgOut02GtZero();
        RsgOut02NeZero b = new RsgOut02NeZero();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgOut02GtZero.nz, (1)));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgOut02NeZero.nz, (1)));
        console.log("Outdated02 >0 check gas:", gA);
        console.log("Outdated02 !=0 check gas:", gB);
    }

    // ---- Tests added by ReviewAgent to cover previously untested contract pairs ----

    function test_Gas_Dep01_factoryDeploy() public {
        RsgDep01Factory f = new RsgDep01Factory();
        uint256 g = _gasCall(address(f), abi.encodeCall(RsgDep01Factory.deploy, ()));
        console.log("Dep01 factory CREATE child gas:", g);
    }

    function test_Gas_Dep06_deploymentCost() public {
        uint256 g1 = gasleft();
        new RsgDep06Impl();
        g1 = g1 - gasleft();

        RsgDep06Impl impl = new RsgDep06Impl();
        uint256 g2 = gasleft();
        new RsgDep06Clone(address(impl));
        g2 = g2 - gasleft();

        console.log("Dep06 full impl deploy gas:", g1);
        console.log("Dep06 clone wrapper deploy gas:", g2);
        // Clone wrapper deploys both itself AND the minimal proxy; the savings
        // appear when comparing the proxy creation alone against a full redeploy.
    }

    function test_Gas_Asm04_xorNeq() public {
        RsgAsm04IsZeroEq a = new RsgAsm04IsZeroEq();
        RsgAsm04Xor b = new RsgAsm04Xor();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgAsm04IsZeroEq.neq, (3, 7)));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgAsm04Xor.neq, (3, 7)));
        console.log("Asm04 solidity != gas:", gA);
        console.log("Asm04 xor != gas:", gB);
    }

    function test_Gas_Asm05_zeroCheck() public {
        RsgAsm05ZeroCheckSolidity a = new RsgAsm05ZeroCheckSolidity();
        RsgAsm05ZeroCheckAsm b = new RsgAsm05ZeroCheckAsm();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgAsm05ZeroCheckSolidity.isZero, (address(0))));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgAsm05ZeroCheckAsm.isZero, (address(0))));
        console.log("Asm05 solidity address==0 gas:", gA);
        console.log("Asm05 assembly iszero gas:", gB);
    }

    function test_Gas_Solc03_revertStringSplit() public {
        RsgSolc03RevertJoin j = new RsgSolc03RevertJoin();
        RsgSolc03RevertSplit s = new RsgSolc03RevertSplit();
        uint256 gJ = _gasCallExpectFail(address(j), abi.encodeCall(RsgSolc03RevertJoin.fail, (1)));
        uint256 gS = _gasCallExpectFail(address(s), abi.encodeCall(RsgSolc03RevertSplit.fail, (1)));
        console.log("Solc03 joined revert gas:", gJ);
        console.log("Solc03 split revert gas:", gS);
    }

    function test_Gas_Solc04_namedReturn() public {
        RsgSolc04Unnamed a = new RsgSolc04Unnamed();
        RsgSolc04Named b = new RsgSolc04Named();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgSolc04Unnamed.pick, (10)));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgSolc04Named.pick, (10)));
        console.log("Solc04 unnamed return gas:", gA);
        console.log("Solc04 named return gas:", gB);
    }

    function test_Gas_Solc05_negatedCondition() public {
        RsgSolc05NegatedIf a = new RsgSolc05NegatedIf();
        RsgSolc05PositiveIf b = new RsgSolc05PositiveIf();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgSolc05NegatedIf.route, (true)));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgSolc05PositiveIf.route, (true)));
        console.log("Solc05 negated if gas:", gA);
        console.log("Solc05 positive if gas:", gB);
    }

    function test_Gas_Solc09_doWhile() public {
        uint256 n = 32;
        RsgSolc09ForLoop f = new RsgSolc09ForLoop();
        RsgSolc09DoWhile d = new RsgSolc09DoWhile();
        uint256 gF = _gasStatic(address(f), abi.encodeCall(RsgSolc09ForLoop.sumTo, (n)));
        uint256 gD = _gasStatic(address(d), abi.encodeCall(RsgSolc09DoWhile.sumTo, (n)));
        console.log("Solc09 for-loop sumTo gas:", gF);
        console.log("Solc09 do-while sumTo gas:", gD);
    }

    function test_Gas_Solc10_packedArgs() public {
        RsgSolc10LooseTypes a = new RsgSolc10LooseTypes();
        RsgSolc10PackedArgs b = new RsgSolc10PackedArgs();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgSolc10LooseTypes.add, (100, 200)));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgSolc10PackedArgs.add, (100, 200)));
        console.log("Solc10 uint128 args gas:", gA);
        console.log("Solc10 uint256 args gas:", gB);
    }

    function test_Gas_Solc11_shortCircuitGas() public {
        RsgSolc11Hits h1 = new RsgSolc11Hits();
        RsgSolc11ShortCircuit s = new RsgSolc11ShortCircuit(h1);
        uint256 gS = _gasCall(address(s), abi.encodeCall(RsgSolc11ShortCircuit.run, ()));

        RsgSolc11Hits h2 = new RsgSolc11Hits();
        RsgSolc11BothEvaluated e = new RsgSolc11BothEvaluated(h2);
        uint256 gE = _gasCall(address(e), abi.encodeCall(RsgSolc11BothEvaluated.run, ()));

        console.log("Solc11 short-circuit (a() true, b() skipped) gas:", gS);
        console.log("Solc11 both evaluated gas:", gE);
        assertLt(gS, gE, "short-circuit should skip second external call");
    }

    function test_Gas_Solc12_privateGetter() public {
        RsgSolc12PublicVar a = new RsgSolc12PublicVar();
        RsgSolc12PrivateGetter b = new RsgSolc12PrivateGetter();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgSolc12PublicVar.read, ()));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgSolc12PrivateGetter.read, ()));
        console.log("Solc12 public var + read() gas:", gA);
        console.log("Solc12 private + read() gas:", gB);
    }

    function test_Gas_Solc17_branchless() public {
        RsgSolc17Branchy a = new RsgSolc17Branchy();
        RsgSolc17Branchless b = new RsgSolc17Branchless();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgSolc17Branchy.abs, (-42)));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgSolc17Branchless.abs, (-42)));
        console.log("Solc17 branchy abs gas:", gA);
        console.log("Solc17 branchless abs gas:", gB);
    }

    function test_Gas_Solc18_inlined() public {
        RsgSolc18Outlined a = new RsgSolc18Outlined();
        RsgSolc18Inlined b = new RsgSolc18Inlined();
        uint256 gA = _gasStatic(address(a), abi.encodeCall(RsgSolc18Outlined.entry, (5)));
        uint256 gB = _gasStatic(address(b), abi.encodeCall(RsgSolc18Inlined.entry, (5)));
        console.log("Solc18 outlined helper gas:", gA);
        console.log("Solc18 inlined gas:", gB);
    }

    function test_Gas_Design01_multiDelegatecall() public {
        RsgDesign01MultiDelegate md = new RsgDesign01MultiDelegate();
        address[] memory targets = new address[](0);
        bytes[] memory data = new bytes[](0);
        uint256 g = _gasCall(address(md), abi.encodeCall(RsgDesign01MultiDelegate.multiDelegatecall, (targets, data)));
        console.log("Design01 multiDelegatecall (empty batch) gas:", g);
    }
}
