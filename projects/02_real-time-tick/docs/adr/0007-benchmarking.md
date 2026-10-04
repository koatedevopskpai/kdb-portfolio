# 7. Benchmark the hot path and publish the numbers

- **Status:** Accepted
- **Date:** 2026-10-03
- **Deciders:** George Kpai

## Context

A market-data system is judged on throughput and latency, yet "it works" tells a reviewer
nothing about performance. Claims without measurements are not credible.

## Decision

Add benchmarks in `bench/`, runnable with `bash bench/bench.sh`:

1. **Serialization throughput** — build N messages and measure messages/s, rows/s, MB/s.
2. **End-to-end ingestion** — run a throttle-free feed and measure rows/s reaching the RDB.
3. **IPC latency** — time many synchronous round-trips to the RDB.

Results are published in the README and walkthrough with honest caveats.

## Consequences

- **Positive:** concrete, quotable numbers (measured on WSL: ~800k msg/s serialization,
  ~417k rows/s end-to-end, ~91 µs IPC round-trip); forces awareness of the hot path.
- **Negative:** numbers are machine- and VM-dependent; they are documented as orders of
  magnitude, not SLAs.
