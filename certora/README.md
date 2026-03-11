# Certora Layout

This directory contains project-owned Certora artifacts for contracts in `src/`.

## Layout

- `confs/` stores `.conf` files passed directly to `certoraRun`
- `specs/` stores CVL specs
- `specs/methods/` stores reusable method declarations

## Wallet baseline proof

Minimal Wallet proof entrypoint:

```bash
certoraRun certora/confs/Wallet.conf
```

The current baseline focuses on access control and owner safety:

- only the current owner can call `withdraw`
- only the current owner can call `setOwner`
- `withdraw` never changes `owner`
- a failed `setOwner` call preserves the current owner
- ownership can only change through an authorized `setOwner`
- `owner` never becomes the zero address after deployment
