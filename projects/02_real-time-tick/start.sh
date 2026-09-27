#!/usr/bin/env bash
# ============================================================
# Start the KDB-X tick system.
# Start order matters:
#   1. hdb  - historical database (rdb connects to it at startup)
#   2. tp   - tickerplant (rdb subscribes to it at startup)
#   3. rdb  - real-time database (subscribes to tp, connects to hdb)
#   4. feed - feed handler (pushes data into tp)
# ============================================================
set -e

cd "$(dirname "$0")"

# locate the q binary: override with Q=... or default to the KDB-X install
Q="${Q:-$HOME/.kx/bin/q}"
if [ ! -x "$Q" ]; then
  echo "q binary not found at $Q. Set Q=/path/to/q or install KDB-X." >&2
  exit 1
fi

mkdir -p log hdb out

start() {
  local name="$1"
  nohup "$Q" "$name.q" > "out/$name.log" 2>&1 &
  echo $! > "out/$name.pid"
  echo "started $name (pid $!)"
  sleep 1
}

# The feed can be either the pure-q feed (feed.q) or the C++ feed handler
# (feed_cpp), which is the bank-standard architecture. If feed_cpp is built
# (bash build.sh), prefer it; otherwise fall back to feed.q.
# (host/port mirror config.q; the C++ side cannot read the q config file)
start_feed() {
  if [ -x ./feed_cpp ]; then
    nohup ./feed_cpp 127.0.0.1 5010 100 > "out/feed.log" 2>&1 &
    echo "started feed (C++ feed handler, pid $!)"
  else
    nohup "$Q" feed.q > "out/feed.log" 2>&1 &
    echo "started feed (q feed handler, pid $!)"
  fi
  echo $! > "out/feed.pid"
}

start hdb
start tp
start rdb
start_feed

echo
echo "All processes started. Logs in out/."
echo "  feed -> tp -> (rdb, hdb)"
echo
echo "Query the live rdb:"
echo "  q verify.q"
echo "Flush to history:"
echo "  q eod.q"
echo "Stop everything:"
echo "  bash stop.sh"