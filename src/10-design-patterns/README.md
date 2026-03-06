# 10 Design Patterns

This chapter collects Solidity design patterns and upgrades them to a more production-oriented 2026 style.

## Goals

- Keep the original pattern taxonomy from the Hedera article.
- Prefer secure, gas-aware, low-footprint implementations over toy examples.
- Show how old patterns evolve in modern Solidity and EVM practice.
- Back examples with unit, fuzz, invariant, and Echidna-style verification where it matters.

## Structure

- `security/PatternVault.sol`
  Unified treasury example for pull payments, scoped pause flags, rate limits, balance caps, CEI, and surplus-only emergency sweep.
- `security/SecurityPatterns.sol`
  Unified security-focused treasury for guardian controls, delayed withdrawals, delayed termination, deprecation, fork checks, and liabilities-safe shutdown.
- `access-control/AccessControlPatterns.sol`
  Judge-based escrow, typed signature permissions with `EIP-712` + `ERC-1271`, and `EIP-1967`-style dynamic binding.
- `efficiency/EfficiencyPatterns.sol`
  Packed storage, metadata roots instead of large strings, single-write update flows, and compact challenge-response state.
- `contract-management/ContractManagementPatterns.sol`
  Decorator, mediator, satellite, migration, and observer patterns upgraded toward event-driven and authority-scoped designs.
- `contract-management/ContractRegistry.sol`
  Delayed-activation registry to reduce accidental or rushed address rotations.
- `access-control/HashSecret.sol`
  Commit-reveal with reveal window and scoped revealer.
- `contract-management/PatternVaultFactory.sol`
  Deterministic clone factory using minimal proxies.

## Pattern Coverage

### Security Patterns

- `security/PatternVault.sol`
  Checks-effects-interactions, pull payments, withdrawal pattern, scoped circuit breakers, balance limits, rate limiting, secure transfer, mutex, delayed emergency sweep.
- `security/SecurityPatterns.sol`
  Fork check, owner/guardian access restriction, scoped pause, delayed withdrawal, delayed termination, auto deprecation, secure transfer, liabilities-safe shutdown.
- `security/AutoDeprecation.sol`
  Minimal isolated sunset example for contracts that should stop accepting risky flows after a fixed time.
- `access-control/HashSecret.sol`
  Commit-reveal with a reveal window, scoped revealer, and explicit expiration.

### Efficiency Patterns

- `efficiency/EfficiencyPatterns.sol`
  Libraries, tight packing, single-write updates, minimized metadata footprint, challenge-response, compact on-chain state.
- `efficiency/IncentiveExecution.sol`
  Incentivized maintenance execution for keeper-style workflows.
- `efficiency/PublisherSubscriber.sol`
  Event-first notification pattern instead of expensive on-chain fan-out.

### Access Control Patterns

- `access-control/AccessControlPatterns.sol`
  Judge pattern, typed signatures with `EIP-712`, contract signatures with `ERC-1271`, and `EIP-1967`-style upgrade authority.
- `access-control/MultiSigWallet.sol`
  Multi-authorization pattern using an explicit confirmation threshold.

### Contract Management Patterns

- `contract-management/ContractManagementPatterns.sol`
  Decorator, mediator, satellite, migration, inter-family communication, and observer patterns upgraded toward event-driven or authority-scoped flows.
- `contract-management/ContractRegistry.sol`
  Delayed-activation registry for safer address rotations.
- `contract-management/DataLogicContract.sol`
  Data/logic separation example.
- `contract-management/PatternVaultFactory.sol`
  Factory pattern with deterministic clone deployment.

### Foundational Examples

- `foundational/StateMachine.sol`
  Lifecycle management through explicit state transitions.


## Directory Convention

- `access-control/`
  Authorization, signatures, multisig, and privilege boundaries.
- `security/`
  Treasury safety, pause logic, shutdown flows, and liability protection.
- `efficiency/`
  Gas-aware state/layout patterns and low-footprint coordination.
- `contract-management/`
  Factories, registries, migration, mediator, observer, and modular composition.
- `foundational/`
  Cross-cutting examples that teach lifecycle or base state semantics.

Naming convention:

- Directory names are lowercase kebab-case by topic.
- Solidity file names stay PascalCase to match primary contract names.
- Test paths mirror source topics so imports and discovery stay predictable.

## Modernization Notes

- `push payments` -> prefer `pull / withdrawal`
- `global pause` -> prefer `scoped pause` with unstoppable exits where possible
- `bare signatures` -> prefer `EIP-712`, nonce, deadline, and `ERC-1271`
- `bare delegatecall proxy` -> prefer standard storage slots and explicit upgrade authority
- `on-chain observer loops` -> prefer `event + version + pull sync`
- `string-heavy metadata` -> prefer compact roots or hashes
- `termination` -> never strand liabilities; allow shutdown only after obligations are clear

## Verification Matrix

- Unit tests:
  `test/10-design-patterns/**/*.t.sol`
- Fuzz tests:
  `AccessControlPatterns.fuzz.t.sol`
  `SecurityPatterns.fuzz.t.sol`
- Invariant tests:
  `AccessControlPatterns.invariant.t.sol`
  `SecurityPatterns.invariant.t.sol`
  `PatternVault.invariant.t.sol`
- Echidna harnesses:
  `src/echidna/PatternVaultEchidna.sol`
  `src/echidna/SecurityPatternsEchidna.sol`

## Verification Commands

- Run all chapter 10 tests:
  `forge test --match-path "test/10-design-patterns/**/*.t.sol"`
- Run only fuzz coverage for chapter 10:
  `forge test --match-path "test/10-design-patterns/**/*.fuzz.t.sol"`
- Run only invariant coverage for chapter 10:
  `forge test --match-path "test/10-design-patterns/**/*.invariant.t.sol"`
- Run `PatternVault` Echidna:
  `echidna-test . --contract PatternVaultEchidna --config echidna.yaml`
- Run `SecurityPatterns` Echidna:
  `echidna-test . --contract SecurityPatternsEchidna --config echidna.yaml`

## Review Checklist

- Start with `security/PatternVault.sol` and `security/SecurityPatterns.sol` if you want the most production-relevant examples first.
- Use `access-control/AccessControlPatterns.sol` to review modern authorization and upgrade patterns.
- Use `contract-management/ContractManagementPatterns.sol` to compare old conceptual patterns with event-driven or delayed-activation replacements.
- Use the fuzz and invariant suites to understand which properties are intended to remain true under adversarial call sequences.

## Suggested Reading Order

1. `security/PatternVault.sol`
2. `security/SecurityPatterns.sol`
3. `access-control/AccessControlPatterns.sol`
4. `efficiency/EfficiencyPatterns.sol`
5. `contract-management/ContractManagementPatterns.sol`

## Production Caveat

These examples are much closer to production than minimal tutorials, but they are still educational samples. A real deployment should still add:

- protocol-specific threat modeling
- upgrade and governance review
- gas profiling on target chains
- role separation review
- external audit and adversarial testing
