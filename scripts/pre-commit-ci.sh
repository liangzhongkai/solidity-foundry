#!/usr/bin/env bash
set -e

# Mirror checks from .github/workflows/test.yml
export FOUNDRY_PROFILE=ci

echo "[1/6] forge fmt --check"
forge fmt --check

echo "[2/6] forge build --sizes --build-info"
forge build --sizes --build-info

echo "[3/6] forge test -vvv --ffi"
forge test -vvv --ffi

# Slither 静态分析 (仅 high 及以上严重性会导致失败)
echo "[4/6] Slither..."
slither . --config-file slither.config.json --fail-high

# Manticore 符号执行 (短超时，仅分析 CounterManticore)
if command -v manticore-verifier &>/dev/null; then
  echo "[5/6] Manticore..."
  manticore-verifier src/manticore/CounterManticore.sol \
    --contract_name CounterManticore \
    --timeout 120
else
  echo "[5/6] Skipping Manticore (manticore-verifier not in PATH)"
fi

# Echidna 模糊测试 (需单独安装: brew install echidna 或从 GitHub releases 下载)
if command -v echidna-test &>/dev/null; then
  echo "[6/6] Echidna..."
  echidna-test . \
    --contract CounterEchidna \
    --config echidna.yaml \
    --crytic-args "--ignore-compile" \
    --test-limit 500
else
  echo "[6/6] Skipping Echidna (echidna-test not in PATH)"
fi
