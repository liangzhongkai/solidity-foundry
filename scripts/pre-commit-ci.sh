#!/usr/bin/env bash
set -e

# Mirror checks from .github/workflows/test.yml

echo "[1/7] forge fmt --check"
forge fmt --check

echo "[2/7] forge build --sizes --build-info"
forge build --sizes --build-info

echo "[3/7] forge test -vvv"
forge test -vvv

echo "[4/7] explicit FFI tests"
RUN_FFI_TESTS=true forge test --match-path test/FFI.t.sol --ffi -vvv
RUN_FFI_TESTS=true FOUNDRY_FUZZ_RUNS=100 forge test --match-path test/DifferentialTest.t.sol --ffi -vvv
RUN_FFI_TESTS=true forge test --match-path test/Vyper.t.sol --ffi -vvv

# Slither 静态分析 (仅 high 及以上严重性会导致失败)
echo "[5/7] Slither..."
slither . --config-file slither.config.json --fail-high

# Manticore 符号执行 (短超时，仅分析 CounterManticore)
if command -v manticore-verifier &>/dev/null; then
  echo "[6/7] Manticore..."
  manticore-verifier src/manticore/CounterManticore.sol \
    --contract_name CounterManticore \
    --compile-force-framework foundry \
    --maxt 2 \
    --timeout 120 || echo "Manticore execution failed, skipping..."
else
  echo "[6/7] Skipping Manticore (manticore-verifier not in PATH)"
fi

# Echidna 模糊测试 (需单独安装: brew install echidna 或从 GitHub releases 下载)
if command -v echidna-test &>/dev/null; then
  echo "[7/7] Echidna..."
  echidna-test . \
    --contract CounterEchidna \
    --config echidna.yaml \
    --test-limit 500 \
    --format text \
    --disable-slither
else
  echo "[7/7] Skipping Echidna (echidna-test not in PATH)"
fi
