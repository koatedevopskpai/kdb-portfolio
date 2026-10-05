# Architecture

A high-level view of the portfolio and how the projects fit together. Detailed diagrams
for the flagship live in
[project 02's architecture](../projects/02_real-time-tick/docs/architecture.md).

## Context

The projects replicate pieces of an investment bank's market-data / quant platform. The
long-term goal is an end-to-end slice: data capture (C++) → q tick store → analytics →
enterprise services (Java/C#).

```mermaid
flowchart TB
    subgraph Capture["Capture (low latency)"]
        EXCH["Exchange / vendor feed"]
        FH["C++ feed handler\nproject 02"]
        EXCH --> FH
    end

    subgraph KDB["kdb+ data layer"]
        TP["Tickerplant"]
        RDB["RDB (today)"]
        HDB["HDB (history)"]
        FH --> TP --> RDB
        RDB --> HDB
    end

    subgraph Consume["Consumers / services"]
        Q["q analytics\nproject 01"]
        J["Java service\nproject 03"]
        C["C# app\nplanned"]
    end
    RDB --> Q
    HDB --> Q
    HDB --> J
    RDB --> C

    classDef planned stroke-dasharray: 5 5
    class C planned
```

Dashed nodes are planned. Everything else is implemented in this repository.

## Project 02 — real-time tick system

The canonical kdb+ architecture: one ingestion point, sequenced and logged, fanned out to
live and historical stores.

```mermaid
flowchart LR
    FEED["C++ feed handler\n(feed_cpp)"]
    TP["Tickerplant\n:5010\nseq · log · fan-out"]
    RDB["RDB :5011\ntoday in memory"]
    HDB["HDB :5012\npartitioned disk"]
    CLI["verify.q / eod.q\n(one-shot clients)"]

    FEED -->|"async (`upd;table;data)"| TP
    TP -->|"broadcast"| RDB
    CLI -->|"sync qSQL"| RDB
    RDB -->|"EOD flush"| HDB
    HDB -->|"history"| CLI

    classDef store fill:#eef
    class RDB,HDB store
```

## Project 01 — q data explorer

A guided, from-scratch walkthrough of q fundamentals: generating data, CSV round-trips,
column profiling, qSQL aggregation, and saving a splayed HDB. It is the on-ramp; project 02
is the destination.

## Design principles across projects

| Principle | How it shows up |
|---|---|
| Separation of concerns | one process per responsibility; services decoupled via IPC |
| DRY | single shared `config.q`; pure helpers in `lib.q` |
| KISS / YAGNI | one uniform message shape; no speculative abstraction |
| Testability | pure functions + byte-exact and end-to-end tests |
| Measurability | benchmarks for throughput and latency |
| Documentation | READMEs, narrative walkthroughs, Mermaid diagrams, ADRs |
