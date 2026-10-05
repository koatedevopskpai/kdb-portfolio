# 2. Keep a pure, thread-safe aggregator and tolerate unknown schemas

- **Status:** Accepted
- **Date:** 2026-10-05
- **Deciders:** George Kpai

## Context

Updates arrive on the reader thread while the reporter thread reads aggregates — so shared
state needs synchronisation. Also, the mini tickerplant broadcasts **every** table to every
subscriber (it does not filter per subscription), so the client receives `quote` updates as
well as `trade`; a malformed or unexpected table must not crash the process.

## Decision

- Put the aggregation logic in a pure `TradeAggregator` (a lock-guarded dictionary of
  symbol -> running stats) with no dependency on kdb+ types. It is unit tested.
- Convert tables in a separate `FlipMapper`: if the table lacks the expected
  `time/sym/price/size` columns, return `false` and the update is skipped.
- The `TickSubscriber` only glues IPC to these two pieces.

## Consequences

- **Positive:** the core is fast to test (no sockets); thread safety is explicit; unknown
  tables (e.g. `quote`) are ignored gracefully; responsibilities are separated.
- **Negative:** a real feed would subscribe per table and route by table name; this simple
  schema check stands in for that. Documented in the README.
