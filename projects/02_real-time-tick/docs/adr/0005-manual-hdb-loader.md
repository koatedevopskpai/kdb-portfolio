# 5. Load HDB partitions with a manual loader

- **Status:** Accepted
- **Date:** 2026-10-02
- **Deciders:** George Kpai

## Context

On KDB-X 5.0 the classic ways to load a partitioned database are unreliable:

- `.Q.l` errors on the `sym` file;
- `\l dir` **changes the process working directory**, which silently corrupts subsequent
  relative paths (partitions were being written to `hdb/hdb/...`).

## Decision

Implement a small manual loader in `hdb.q`:

1. load the symbol enumeration first (`get hdb/sym`) so FK columns resolve;
2. walk the date directories with `key`;
3. `get` each splayed table and `set` it into the root namespace, resolving the enumerated
   `sym` column with `update sym:value sym`.

## Consequences

- **Positive:** history loads correctly on KDB-X; the working directory is left untouched;
  the loader is explicit and understandable.
- **Negative:** we maintain ~10 lines that `.Q.l`/`\l` would normally provide. If KX fixes
  these in a later release, the loader can be replaced.
