#!/usr/bin/env bash
# ============================================================
# run_tests.sh - run the whole test suite.
#   unit (C++): byte-exact serialization
#   unit (q)  : config + lib helpers
#   integration: end-to-end pipeline
# Exits non-zero if anything fails.
# ============================================================
cd "$(dirname "$0")/.."
set -u
Q="${Q:-$HOME/.kx/bin/q}"
fail=0

echo "=== unit: C++ byte-exact serialization (vs q -8!) ==="
if g++ -std=c++17 -Wall tests/test_ser.cpp -o tests/test_ser; then
  ./tests/test_ser || fail=1
else
  echo "  FAIL could not compile test_ser"; fail=1
fi

echo
echo "=== unit: q (config + lib) ==="
"$Q" tests/test_units.q </dev/null || fail=1

echo
echo "=== integration: end-to-end pipeline ==="
bash tests/test_e2e.sh || fail=1

echo
if [ "$fail" = 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; fi
exit $fail