# 1. Adopt the kdb+ tick architecture

- **Status:** Accepted
- **Date:** 2026-09-25
- **Deciders:** George Kpai

## Context

Trading desks need one authoritative, low-latency stream of market data that is captured
once, recoverable after a crash, queryable live during the day, and persisted efficiently
for history. A naive design — every consumer connecting to the source independently —
duplicates work, risks divergence, and cannot replay.

## Decision

Implement the canonical kdb+ **tick architecture**:

```
source -> tickerplant -> { rdb (live), hdb (history), other subscribers }
```

The tickerplant is the single point of ingestion; it assigns per-table sequence numbers,
writes a disk log for recovery, and fans out to subscribers.

## Consequences

- **Positive:** single ingestion point; ordered, sequenced, recoverable stream; producers
  decoupled from an unknown set of consumers.
- **Negative:** the tickerplant is a critical path and a potential bottleneck; scaling
  requires sharding/gateways (accepted future work).
- This is the industry-standard pattern, so the code is legible to any kdb+ team.
