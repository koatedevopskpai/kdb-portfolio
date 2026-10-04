# 8. Enumerate symbols on write, resolve them on read

- **Status:** Accepted
- **Date:** 2026-10-04
- **Deciders:** George Kpai

## Context

kdb+ conventionally stores the `sym` column as an *enumeration* (a foreign key into a
global `sym` list), which compresses repeated symbols and is required for a proper HDB. On
KDB-X 5.0, `set` only splays an **enumerated** (`.Q.en`-processed) table, and the
resulting FK column does not resolve reliably in `meta`/qSQL when loaded.

## Decision

- **On write:** enumerate with `.Q.en` (this is also what KDB-X's splay requires) and store
  the enumerated table.
- **On read:** load the `sym` list first, then resolve each table's FK column back to plain
  symbols with `update sym:value sym`. Downstream qSQL then returns real symbols.

## Consequences

- **Positive:** the standard HDB format is preserved on disk; queries and `meta` behave
  correctly; the workaround is isolated to the loader.
- **Negative:** we resolve FK→symbol at load time (a small cost, fine at this scale); if
  KDB-X fixes FK resolution, the `update sym:value sym` line can be removed.
