# real-time-tick

A professional-grade **real-time market data system** built on KDB-X (kdb+), demonstrating the canonical kdb+ architecture used across investment banks: feed handler → tickerplant → RDB → HDB.

> 📖 **New here?** Read [`02_codeAlongThrough.md`](02_codeAlongThrough.md) — a full narrative
> walkthrough of every file, how they connect, the process flow, the engineering principles
> applied, and an interview Q&A rehearsal guide.
>
> 🏗️ Architecture diagrams: [`docs/architecture.md`](docs/architecture.md) ·
> Key decisions: [`docs/adr/`](docs/adr/README.md)

## Why this project matters

This is the exact architecture that powers market data at trading desks. If you understand this repo, you understand how a bank's real-time data layer is wired:

| Component | What a bank calls it | What it does here |
|---|---|---|
| `feed_cpp.cpp` | Feed handler / market data gateway (C++) | Connects to the exchange, normalises data, pushes to the tp over IPC |
| `feed.q` | Feed handler (q fallback) | Simulates an exchange feed, pushes trades & quotes |
| `tp.q` | Tickerplant | Single point of ingestion: sequence numbers, disk logging, fan-out |
| `rdb.q` | Real-Time Database | In-memory state for the current day, answers live queries |
| `hdb.q` | Historical Database | Partitioned on-disk history, holds every past day |

## Architecture

```
                 +---------------------------+
                 |     FEED HANDLER (C++)    |
                 |  feed_cpp.cpp - raw IPC   |
                 +------------+--------------+
                              | async push (kdb+ wire protocol)
                              v
                 +---------------------------+
                 |        TICKERPLANT        |  :5010
                 |  seq numbers, log, fanout |
                 +------+-----------+--------+
                        |           |
           async broadcast (neg .u.w)
                        |           |
        +---------------+           +---------------+
        v                               v
+------------------+              +------------------+
|       RDB        |              |       HDB        |
| in-memory today  |  :5011       | partitioned disk |  :5012
| live queries     |              | full history     |
+--------+---------+              +------------------+
         |
         | end-of-day flush (async)
         v
+------------------+
|  hdb/YYYY.MM.DD/ |
|   trade/ quote/  |
+------------------+
```

## The C++ feed handler (bank-standard architecture)

In a real investment bank, the process that talks to the exchange is written in
**C++ or Java** for sub-microsecond latency. It parses the exchange's binary
protocol (FIX/OUCH), normalises the data into q tables, and pushes it into the
q tickerplant over IPC. That is exactly what `feed_cpp.cpp` does.

`feed_cpp.cpp` implements the **kdb+ IPC wire protocol directly** (raw TCP,
little-endian serialization) — no KX library required. The exact byte format is
documented in the source and verified against q's `-8!` output.

To build and use it:

```bash
# one-time prerequisite (needs sudo):
sudo apt-get update && sudo apt-get install -y g++ make

bash build.sh                # compiles ./feed_cpp
bash start.sh                # start.sh now prefers feed_cpp over feed.q
```

`start.sh` automatically uses `feed_cpp` when it is built, and falls back to the
pure-q `feed.q` otherwise.

## Prerequisites

- **KDB-X (or kdb+) on Linux/WSL** with `q` on your `PATH`
- bash (WSL on Windows)

## Quick start

```bash
bash start.sh     # starts hdb, tp, rdb, feed (in dependency order)
q verify.q        # connects to the live rdb and prints per-symbol stats
q eod.q           # triggers an end-of-day flush: rdb -> hdb
ls hdb/           # see the new date partition
bash stop.sh      # stops everything
```

## How data flows

1. **feed.q** generates a batch of ~10 trades and ~10 quotes every 100 ms and pushes them to the tp asynchronously: `neg[h] (\`upd; \`trade; table)`.
2. **tp.q** assigns each table a monotonically increasing **sequence number**, appends every update to a rolling **disk log** (crash recovery), keeps an in-memory buffer (so late subscribers can catch up), and broadcasts to all subscribers.
3. **rdb.q** subscribes with a sync handshake that returns `(current seq; full snapshot)`, then applies every broadcast. Its `.z.ps` uses the seq number to avoid applying rows twice (snapshot vs. live). It exposes live queries on `:5011`.
4. **At end-of-day**, rdb flushes today's data to the hdb, which splays it into a **date partition** `hdb/YYYY.MM.DD/trade`. Once the clock passes `CFG.eodTime` (16:00), the rdb does this automatically.
5. **hdb.q** loads all existing partitions on startup via `.Q.l`, so historical queries work across days.

## Project structure

```
02_real-time-tick/
  config.q    # shared ports, paths, symbols, schemas (single source of truth)
  lib.q       # pure helpers: applyUpd guard, hdbPath (unit tested)
  tp.q        # tickerplant
  rdb.q       # real-time database
  hdb.q       # historical database
  feed.q      # q feed handler (fallback)
  feed_cpp.cpp# C++ feed handler (bank-standard)
  qipc.hpp    # kdb+ wire-protocol serialization library (unit tested)
  build.sh    # compiles feed_cpp (needs g++)
  verify.q    # demo client: remote query of the live rdb
  eod.q       # trigger an end-of-day flush
  start.sh    # start all processes in dependency order
  stop.sh     # stop all processes
  tests/      # unit (C++/q) + end-to-end integration tests
  bench/      # serialization / ingestion / IPC-latency benchmarks
  README.md
  LICENSE
```

## Key kdb+ concepts demonstrated

- **IPC** — `hopen` / `hclose`, async (`neg[h]`) vs sync (`h msg`) messaging, `.z.pg` / `.z.ps` handlers, remote string queries
- **Tickerplant pattern** — sequence numbers, disk logging, fan-out, subscriber catch-up
- **Partitioned HDB** — `.Q.en` symbol enumeration, splayed tables, date partitions, `.Q.l`
- **Timers** — `.z.ts` / `\t` for the feed and the automatic end-of-day
- **qSQL** — the aggregates used in `verify.q`

## Testing & benchmarks

```bash
bash tests/run_tests.sh   # unit (C++ vs q -8!) + unit (q) + end-to-end
bash bench/bench.sh       # serialization, ingestion rate, IPC latency
```

Measured on WSL (single-threaded):

| Metric | Result |
|---|---|
| C++ message serialization | ~800,000 msg/s (~8M rows/s, ~300 MB/s, 1.25 µs/msg) |
| End-to-end ingestion (feed → tp → rdb) | ~417,000 trade rows/s |
| IPC sync round-trip | ~91 µs/call |

## Safety notes

- Logs and data (`log/`, `hdb/`, `out/`) are git-ignored — a repo clone builds fresh data on first run.
- All paths are relative: KDB-X treats `/` as a comment character, so absolute POSIX paths do not work.

## KDB-X 5.0 compatibility notes

This project was developed and verified on **KDB-X 5.0** (Community Edition), which differs from classic kdb+ in several ways. The code works around all of these — useful to know in an interview:

| Classic kdb+ | KDB-X 5.0 reality | Workaround used here |
|---|---|---|
| `\` starts a trailing comment | `/` is the comment char everywhere; a **bare `/` line swallows the rest of the file** | all comments use `/`, never a bare `/` line |
| `string \`:hdb` = `"hdb"` | `string \`:hdb` = `":hdb"` (keeps the colon) | keep the colon when building paths |
| `set` on `dir/table` splays a table | only splays when the path is an **hsym with a trailing slash** | `` p:`$":hdb/",date,"/",table,"/"; p set d `` |
| `insert` appends rows | `insert` throws `'type`; use `upsert` / functional amend | RDB appends with `.[`trade;();,;x]` |
| `neg[h] msg` writes async to a file handle | fails with `'type`; writes are synchronous | tp logs with `h msg` |
| `\l dir` loads a partitioned db, cwd unchanged | `\l dir` **changes the working directory** | manual partition loader (no `\l`) |
| `.Q.l` loads a partitioned db | `.Q.l` errors on the `sym` file | manual loader via `key`/`get` |
| bare symbol `.u.upd` compares with `~` | `.u.upd` is a *variable reference* → `'.u.upd` | always write the literal `` `.u.upd `` |
| `` `$string[t] set x `` parses as desired | `string[t] set x` binds first → `'type` | compute the name first: `n:\`$string[t]; n set x` |

## License

MIT. See [LICENSE](LICENSE).