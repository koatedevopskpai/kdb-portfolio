#!/usr/bin/env bash
# ============================================================
# Stop all tick system processes (reverse start order).
# ============================================================
cd "$(dirname "$0")"

for name in feed rdb tp hdb; do
  if [ -f "out/$name.pid" ]; then
    pid=$(cat "out/$name.pid")
    if kill "$pid" 2>/dev/null; then
      echo "stopped $name (pid $pid)"
    else
      echo "$name not running"
    fi
    rm -f "out/$name.pid"
  fi
done

echo "done"