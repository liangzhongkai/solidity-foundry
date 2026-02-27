#!/usr/bin/env bash
set -e

# Mirror checks from .github/workflows/test.yml
export FOUNDRY_PROFILE=ci

npm ci
forge fmt --check
forge build --sizes --build-info
forge test -vvv --ffi

# Slither 静态分析 (仅 high 及以上严重性会导致失败)
echo "Running Slither..."
slither . --config-file slither.config.json --fail-high

# Manticore 符号执行 (短超时，仅分析 CounterManticore)
if command -v manticore-verifier &>/dev/null; then
  echo "Running Manticore..."
  manticore-verifier src/manticore/CounterManticore.sol \
    --contract_name CounterManticore \
    --timeout 120
else
  echo "Skipping Manticore (manticore-verifier not in PATH, install: pip install manticore)"
fi

# Echidna 模糊测试 (需单独安装: brew install echidna 或从 GitHub releases 下载)
if command -v echidna-test &>/dev/null; then
  echo "Running Echidna..."
  echidna-test . \
    --contract CounterEchidna \
    --config echidna.yaml \
    --crytic-args "--ignore-compile" \
    --test-limit 500
else
  echo "Skipping Echidna (echidna-test not in PATH, install: brew install echidna)"
fi
