#!/usr/bin/env bash
# ============================================================
# bench.sh - performance benchmarks for the tick system.
#   1. C++ message serialization throughput (single thread)
#   2. end-to-end ingestion rate  (C++ feed -> tp -> rdb)
#   3. IPC round-trip latency      (sync call to the rdb)
# ============================================================
cd "$(dirname "$0")/.."
set -u
Q="${Q:-$HOME/.kx/bin/q}"

echo "=== 1. C++ message serialization throughput ==="
g++ -O2 -std=c++17 bench/bench_ser.cpp -o bench/bench_ser || exit 1
./bench/bench_ser

echo
echo "=== 2. end-to-end ingestion rate (C++ feed -> tp -> rdb) ==="
for pid in $(pgrep -f '\.kx/bin/q'); do
  cmd=$(ps -o args= -p "$pid")
  case "$cmd" in *"127.0.0.1:5000"*|*"explorer"*) : ;; *) kill "$pid" 2>/dev/null ;; esac
done
sleep 1
rm -rf log hdb out
[ -x ./feed_cpp ] || bash build.sh >/dev/null 2>&1 || { echo "cannot build feed_cpp"; exit 1; }
mkdir -p log hdb out

nohup "$Q" hdb.q > out/hdb.log 2>&1 & echo $! > out/hdb.pid
sleep 1
nohup "$Q" tp.q  > out/tp.log  2>&1 & echo $! > out/tp.pid
sleep 1
nohup "$Q" rdb.q > out/rdb.log 2>&1 & echo $! > out/rdb.pid
sleep 2

rm -f out/live_count.txt
"$Q" tests/count_live.q </dev/null >/dev/null 2>&1
BASE=$(cat out/live_count.txt 2>/dev/null | tr -d '[:space:]')
BASE=${BASE:-0}

# throttle-free feed: interval 0ms, 100 rows per trade batch
./feed_cpp 127.0.0.1 5010 0 100 > out/feed.log 2>&1 & FEED=$!
T=3
sleep $T
rm -f out/live_count.txt
"$Q" tests/count_live.q </dev/null >/dev/null 2>&1
END=$(cat out/live_count.txt 2>/dev/null | tr -d '[:space:]')
END=${END:-0}
kill "$FEED" 2>/dev/null

ROWS=$(( END - BASE ))
echo "  ingested $ROWS trade rows in ${T}s"
[ "$T" -gt 0 ] && echo "  => ~$(( ROWS / T )) trade rows/s sustained end-to-end"

echo
echo "=== 3. IPC round-trip latency (sync call to rdb :5011) ==="
"$Q" bench/latency.q </dev/null 2>/dev/null | grep -v -- '^-1$'

# ---- stop ----
for n in feed rdb tp hdb; do
  [ -f "out/$n.pid" ] && kill "$(cat "out/$n.pid")" 2>/dev/null && rm -f "out/$n.pid"
done
echo
echo "done"