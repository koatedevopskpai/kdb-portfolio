#!/usr/bin/env bash
# ============================================================
# Build the C++ feed handler.
#
# One-time prerequisite (needs sudo):
#   sudo apt-get update && sudo apt-get install -y g++ make
#
# The feed handler implements the kdb+ IPC wire protocol directly,
# so it needs no KX libraries - just a C++17 compiler.
# ============================================================
set -e
cd "$(dirname "$0")"

if ! command -v g++ >/dev/null 2>&1; then
  echo "g++ not found. Install it with:"
  echo "  sudo apt-get update && sudo apt-get install -y g++ make"
  exit 1
fi

g++ -O2 -std=c++17 -Wall -Wextra feed_cpp.cpp -o feed_cpp
echo "built ./feed_cpp"
echo "run it:  ./feed_cpp 127.0.0.1 5010 100"