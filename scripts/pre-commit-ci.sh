#!/usr/bin/env bash
set -e

# Mirror checks from .github/workflows/test.yml
export FOUNDRY_PROFILE=ci

npm ci
forge fmt --check
forge build --sizes
forge test -vvv --ffi
