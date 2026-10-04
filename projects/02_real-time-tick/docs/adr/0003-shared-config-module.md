# 3. Keep one shared config module as the single source of truth

- **Status:** Accepted
- **Date:** 2026-09-30
- **Deciders:** George Kpai

## Context

Ports, paths, traded symbols and table schemas were initially duplicated across the
process files (and the shell scripts). Duplicated configuration drifts: change a port in
one place and the system silently breaks.

## Decision

Centralise shared definitions in `config.q` under a `CFG` namespace — ports, host, symbols,
data directories, end-of-day time, and the `trade`/`quote` **schemas**. Every q process
loads it; `rdb.q` references `CFG.trade`/`CFG.quote` instead of redefining them. Port
numbers were removed from `start.sh` (they live only in `config.q`).

## Consequences

- **Positive:** one place to change anything; schemas can't drift between processes;
  the configuration is self-documenting.
- **Negative:** `config.q` is loaded by processes that don't use every field (a tiny cost);
  cross-language duplication (the C++ feed mirrors the schema) is unavoidable and documented.
