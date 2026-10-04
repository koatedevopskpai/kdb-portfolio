# 6. Testing strategy: byte-exact unit tests plus an end-to-end integration test

- **Status:** Accepted
- **Date:** 2026-10-03
- **Deciders:** George Kpai

## Context

A distributed system is easy to get "working once" and hard to keep correct. The riskiest
parts here are (a) the hand-rolled IPC serialization and (b) the multi-process data flow.
Neither is well covered by eyeballing output.

## Decision

Two complementary layers, runnable with `bash tests/run_tests.sh`:

1. **Unit tests**
   - `test_ser.cpp` — the C++ serializer's bytes must match q's `-8!` output exactly.
   - `test_units.q` — config values, schema types, `applyUpd`, `hdbPath`.
2. **Integration test**
   - `test_e2e.sh` — starts the pipeline, asserts live rows arrive, that end-of-day writes
     a date partition, and that a restarted HDB serves history.

Tests exit non-zero on failure (CI-friendly).

## Consequences

- **Positive:** the wire protocol is proven without a network; regressions in the flow are
  caught; the tests caught a real precedence bug (`hdbPath`) and the null-comparison bug.
- **Negative:** the integration test depends on ports being free and takes a few seconds.
