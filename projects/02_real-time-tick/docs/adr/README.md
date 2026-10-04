# Architecture Decision Records

Lightweight ADRs for the real-time tick system (project 02). Format: Status · Date ·
Context · Decision · Consequences.

| # | Decision | Status |
|---|---|---|
| [0001](0001-adopt-tick-architecture.md) | Adopt the kdb+ tick architecture | Accepted |
| [0002](0002-cpp-feed-handler-raw-ipc.md) | C++ feed handler using raw kdb+ IPC | Accepted |
| [0003](0003-shared-config-module.md) | One shared config module (single source of truth) | Accepted |
| [0004](0004-pure-helpers-lib.md) | Extract pure helpers into `lib.q` for testability | Accepted |
| [0005](0005-manual-hdb-loader.md) | Manual HDB partition loader (KDB-X constraints) | Accepted |
| [0006](0006-testing-strategy.md) | Unit + end-to-end integration testing | Accepted |
| [0007](0007-benchmarking.md) | Benchmark the hot path, publish the numbers | Accepted |
| [0008](0008-enumerate-on-write-resolve-on-read.md) | Enumerate symbols on write, resolve on read | Accepted |
