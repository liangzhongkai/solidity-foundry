# RareSkills gas optimization — code case index

Article: [The RareSkills Book of Solidity Gas Optimization](https://rareskills.io/post/gas-optimization)

Each TOC bullet maps to a **symbol** in `src/23-rareskills-gas-optimization/`. Gas deltas are exercised in `test/23-rareskills-gas-optimization/`. Items marked **doc-only** are architectural, client-side, unsafe, or compiler-metadata tricks that are not turned into assertive on-chain benchmarks.

## The RareSkills Book of Gas Optimization (intro + 14 tips)

| Article bullet | Code / notes |
|----------------|--------------|
| Gas optimization tricks do not always work | `RsgMeta` |
| Beware of complexity and readability | `RsgMeta` |
| Comprehensive treatment of each topic isn’t possible here | `RsgMeta` |
| We do not discuss application-specific tricks | `RsgMeta` |
| 1. Avoid zero to one storage writes | `RsgBook01Bad` / `RsgBook01Good` |
| 2. Cache storage variables | `RsgBook02Uncached` / `RsgBook02Cached` |
| 3. Pack related variables | `RsgBook03Unpacked` / `RsgBook03Packed` |
| 4. Pack structs | `RsgBook04StructLoose` / `RsgBook04StructTight` |
| 5. Keep strings smaller than 32 bytes | `RsgBook05ShortString` / `RsgBook05LongString` |
| 6. Never-updated vars: immutable/constant | `RsgBook06MutableRead` / `RsgBook06ImmutableRead` |
| 7. Mappings vs arrays (length checks) | `RsgBook07ArrayLookup` / `RsgBook07MappingLookup` |
| 8. Avoid redundant length checks | `RsgBook08LengthTwice` / `RsgBook08LengthCached` |
| 9. Bitmaps vs many bools | `RsgBook09ManyBools` / `RsgBook09Bitmap` |
| 10. SSTORE2 / SSTORE3 | `RsgBook10Sstore2Note` (doc + pointer to libraries) |
| 11. Storage pointers vs memory copies | `RsgBook11MemoryRoundtrip` / `RsgBook11StoragePtr` |
| 12. Avoid ERC20 balance hitting zero | `RsgBook12Zeroing` / `RsgBook12Dust` |
| 13. Count n → 0 | `RsgBook13Up` / `RsgBook13Down` |
| 14. Timestamps not always uint256 | `RsgBook14WideTime` / `RsgBook14NarrowTime` |

## Saving Gas On Deployment (9)

| # | Code |
|---|------|
| 1 | `RsgDep01` + `RsgDep01Factory` (CREATE nonce pattern, doc in NatSpec) |
| 2 | `RsgDep02NotPayable` / `RsgDep02Payable` |
| 3 | **doc-only** — IPFS hash / `--no-cbor-metadata` (build pipeline) |
| 4 | **doc-only** — `selfdestruct` / one-time init (deprecated semantics) |
| 5 | `RsgDep05WithModifier` / `RsgDep05InternalGuard` |
| 6 | `RsgDep06Full` / `RsgDep06Clone` (minimal clone) |
| 7 | `RsgDep07AdminNonPayable` / `RsgDep07AdminPayable` |
| 8 | `RsgDep08RequireString` / `RsgDep08CustomError` |
| 9 | **doc-only** — reuse public CREATE2 factories |

## Cross contract calls (6)

| # | Code |
|---|------|
| 1 | `RsgCross01Doc` (pull vs push hooks — doc stub, see `02-erc20` for token callbacks) |
| 2 | `RsgCross02Deposit` / `RsgCross02Receive` |
| 3 | **doc-only** — ERC-2930 access lists (wallet / tx envelope) |
| 4 | `RsgCross04OracleUncached` / `RsgCross04OracleCached` |
| 5 | `RsgCross05NoBatch` / `RsgCross05Multicall` |
| 6 | `RsgCross06SplitA`+`B` / `RsgCross06Mono` |

## Design patterns (10)

| # | Code |
|---|------|
| 1 | `RsgDesign01MultiDelegate` (batch delegatecall helper) |
| 2 | `RsgDesign02Merkle` / `RsgDesign02Ecdsa` |
| 3 | **doc-only** — ERC20Permit (see existing `02-erc20` permit demos) |
| 4 | **doc-only** — L2 message passing |
| 5 | **doc-only** — state channels |
| 6 | **doc-only** — vote delegation (see `18-advanced-erc20`) |
| 7 | **doc-only** — ERC1155 vs ERC721 cost (large fixture) |
| 8 | **doc-only** — one ERC1155 vs many ERC20 |
| 9 | **doc-only** — UUPS vs transparent proxy |
| 10 | **doc-only** — alternatives to OpenZeppelin |

## Calldata optimizations (4)

| # | Code |
|---|------|
| 1 | **doc-only** — vanity addresses (mining / create2) |
| 2 | `RsgCalldata02Signed` / `RsgCalldata02Unsigned` |
| 3 | `RsgCalldata03MemoryCopy` / `RsgCalldata03CalldataSlice` |
| 4 | **doc-only** — packed calldata on L2 |

## Assembly tricks (10)

| # | Code |
|---|------|
| 1 | `RsgAsm01SolidityRevert` / `RsgAsm01AssemblyRevert` |
| 2 | **doc-only** — interface dispatch memory reuse |
| 3 | `RsgAsm03MinSolidity` / `RsgAsm03MinAsm` |
| 4 | `RsgAsm04IsZeroEq` / `RsgAsm04Xor` |
| 5 | `RsgAsm05ZeroCheckSolidity` / `RsgAsm05ZeroCheckAsm` |
| 6 | `RsgAsm06ThisBalance` / `RsgAsm06SelfBalance` |
| 7 | `RsgAsm07HashSolidity` / `RsgAsm07HashAsm` (small payload) |
| 8 | **doc-only** — reuse memory across multiple ext calls |
| 9 | **doc-only** — reuse memory across multiple creates |
| 10 | `RsgAsm10Mod` / `RsgAsm10Bit` |

## Solidity compiler related (22)

| # | Code |
|---|------|
| 1 | `RsgSolc01Strict` / `RsgSolc01NonStrict` |
| 2 | `RsgSolc02CompoundRequire` / `RsgSolc02SplitRequire` |
| 3 | `RsgSolc03RevertJoin` / `RsgSolc03RevertSplit` |
| 4 | `RsgSolc04Unnamed` / `RsgSolc04Named` |
| 5 | `RsgSolc05NegatedIf` / `RsgSolc05PositiveIf` |
| 6 | `RsgSolc06PostInc` / `RsgSolc06PreInc` |
| 7 | `RsgSolc07CheckedSum` / `RsgSolc07UncheckedSum` |
| 8 | `RsgSolc08LoopNaive` / `RsgSolc08LoopOpt` |
| 9 | `RsgSolc09ForLoop` / `RsgSolc09DoWhile` |
| 10 | `RsgSolc10LooseTypes` / `RsgSolc10PackedArgs` |
| 11 | `RsgSolc11BothEvaluated` / `RsgSolc11ShortCircuit` |
| 12 | `RsgSolc12PublicVar` / `RsgSolc12PrivateGetter` |
| 13 | **doc-only** — optimizer runs tuning |
| 14 | **doc-only** — function name IR length |
| 15 | `RsgSolc15Mul` / `RsgSolc15Shift` |
| 16 | `RsgSolc16CalldataTwice` / `RsgSolc16CalldataCache` |
| 17 | `RsgSolc17Branchy` / `RsgSolc17Branchless` |
| 18 | `RsgSolc18Outlined` / `RsgSolc18Inlined` |
| 19 | **doc-only** — long string/array equality via hash |
| 20 | **doc-only** — lookup tables for pow/log |
| 21 | **doc-only** — precompiles |
| 22 | `RsgSolc22Exp` / `RsgSolc22Mul` |

## Dangerous techniques (7) — **do not ship**

| # | Code |
|---|------|
| 1–7 | `RsgDanger` (NatSpec warnings only; no recommended patterns) |

## Outdated tricks (2)

| # | Code |
|---|------|
| 1 | `RsgOut01PublicVsExternal` |
| 2 | `RsgOut02GtZeroVsNeZero` |
