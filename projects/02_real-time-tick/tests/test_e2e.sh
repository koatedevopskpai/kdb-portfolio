#!/usr/bin/env bash
# ============================================================
# test_e2e.sh - integration test for the whole tick system.
#
# Starts the pipeline with the C++ feed, asserts that:
#   1. the rdb receives live data
#   2. end-of-day writes a date partition to the hdb
#   3. a restarted hdb loads the history and answers queries
# Exits non-zero if any assertion fails.
# ============================================================
cd "$(dirname "$0")/.."
set -u

Q="${Q:-$HOME/.kx/bin/q}"
fail=0

check() { # <got> <want> <label>
  if [ "$1" = "$2" ]; then
    echo "  ok   $3"
  else
    echo "  FAIL $3 (got '$1', want '$2')"
    fail=1
  fi
}
yesno() { [ "$1" -gt 0 ] 2>/dev/null && echo yes || echo no; }

# ---- clean slate ----
for pid in $(pgrep -f '\.kx/bin/q'); do
  cmd=$(ps -o args= -p "$pid")
  case "$cmd" in
    *"127.0.0.1:5000"*|*"explorer"*) : ;;
    *) kill "$pid" 2>/dev/null ;;
  esac
done
sleep 1
rm -rf log hdb out

# ---- build the C++ feed if needed ----
if [ ! -x ./feed_cpp ]; then
  bash build.sh >/dev/null 2>&1 || { echo "cannot build feed_cpp (install g++)"; exit 1; }
fi

# ---- start ----
bash start.sh >/dev/null
sleep 6

# ---- 1. live data flowed ----
rm -f out/live_count.txt
"$Q" tests/count_live.q </dev/null >/dev/null 2>&1
LIVE=$(cat out/live_count.txt 2>/dev/null | tr -d '[:space:]')
check "$(yesno "${LIVE:-0}")" "yes" "live rdb received data [${LIVE:-0} rows]"

# ---- 2. end-of-day writes a partition ----
"$Q" eod.q </dev/null >/dev/null 2>&1
sleep 1
DATE=$(date +%Y.%m.%d)
check "$([ -d "hdb/$DATE/trade" ] && echo yes || echo no)" "yes" "hdb partition hdb/$DATE/trade written"

# ---- 3. restart hdb, load history, query it ----
for pid in $(pgrep -f 'hdb.q'); do kill "$pid" 2>/dev/null; done
sleep 1
nohup "$Q" hdb.q > out/hdb.log 2>&1 &
echo $! > out/hdb.pid
sleep 3
rm -f out/hist_count.txt
"$Q" tests/count_hist.q </dev/null >/dev/null 2>&1
HIST=$(cat out/hist_count.txt 2>/dev/null | tr -d '[:space:]')
check "$(yesno "${HIST:-0}")" "yes" "hdb loaded history [${HIST:-0} rows]"

# ---- stop ----
bash stop.sh >/dev/null 2>&1

echo
if [ "$fail" = 0 ]; then echo "E2E PASS"; else echo "E2E FAIL"; fi
exit $fail