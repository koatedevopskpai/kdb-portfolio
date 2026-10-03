# 02 — Real-Time Tick System: Code Walkthrough & Interview Guide

This document narrates the whole project end to end: **what each file is for, how the
files connect, the process flow, and how to talk about it in an interview.** Read it
top to bottom once, then use the last section as a rehearsal script.

---

## 1. The 30-second pitch (say this first)

> "I built a real-time market-data system that mirrors how an investment bank's data
> platform is wired: a **C++ feed handler** ingests data and pushes it over IPC into a
> **q tickerplant**, which assigns sequence numbers, logs it for recovery, and fans it
> out to a **real-time database** for live queries and a **historical database** for
> on-disk, date-partitioned history. At end of day the RDB flushes to the HDB."

That single sentence covers architecture, technologies (C++, q/kdb+), the real-time ↔
historical split, and the bank relevance.

---

## 2. The business problem

Trading desks need **one authoritative, ultra-low-latency stream** of market data that:

1. is captured **once** (single point of ingestion),
2. can be **recovered** after a crash,
3. is queryable **live** during the day, and
4. is persisted **efficiently** for historical analysis.

A naive design (every consumer connecting to the exchange separately) duplicates work,
diverges, and can't replay. The industry answer is the **tick architecture**:

```
source  ->  tickerplant  ->  { rdb (live), hdb (history), other subscribers }
```

Everything in this project exists to implement one part of that sentence.

---

## 3. Architecture at a glance

```
                 +------------------------------+
                 |     FEED HANDLER (C++)       |
                 |  feed_cpp.cpp  (raw IPC)     |
                 +--------------+---------------+
                                | async push: (`upd; `trade; table)
                                v
                 +------------------------------+
                 |         TICKERPLANT          |  :5010
                 |  seq #, disk log, fan-out    |
                 +-------+--------------+-------+
                         |              |
            async broadcast to every subscriber
                         |              |
        +----------------+              +----------------+
        v                                                v
+------------------+                            +------------------+
|       RDB        |  :5011                     |       HDB        |  :5012
|  today in memory |                            |  partitioned disk|
|  live queries    |                            |  full history    |
+--------+---------+                            +------------------+
         |                                                 ^
         | end-of-day flush: (`upd; `trade; table)          |
         +-------------------------------------------------+
                    hdb/YYYY.MM.DD/{trade,quote}
```

Key idea to emphasize: **the feed talks to the tickerplant, not to the RDB/HDB.** The
tickerplant is the only thing that knows about every subscriber. That is *loose
coupling* (see §7).

---

## 4. End-to-end flow — the life of one trade

Follow a single batch of trades from C++ to disk:

1. **C++ feed** generates 10 random trades (symbol, price, size, timestamp) and
   serialises them into a q table on the wire, then sends an **async** message
   `` (`upd; `trade; table) `` to port 5010.
2. **Tickerplant** receives it via `.z.ps`, calls `upd`:
   - increments the per-table **sequence number** (`.u.seq`),
   - appends the rows to a per-table **disk log** (crash recovery),
   - appends to an in-memory **buffer** (so late subscribers can catch up),
   - **broadcasts** the message to every registered subscriber (`.u.w`).
3. **RDB**, already subscribed, receives the broadcast in its `.z.ps`, and uses the
   sequence number to apply only rows it hasn't already seen (the snapshot-vs-live
   guard), appending with functional amend `.[`trade;();,;x]`.
4. A trader (or `verify.q`) queries the RDB on port 5011: `select ... by sym from trade`.
5. **End of day** (`eod.q`, or automatically past `CFG.eodTime`): the RDB sends today's
   `trade`/`quote` to the HDB, then resets to empty schemas.
6. **HDB** splays each table into a date partition `hdb/2026.10.05/trade/` and can be
   restarted to load history; historical queries then work the same way.

The same `(`upd; table; data)` message shape is used at **every hop** — that's a
deliberate interface contract (see §7, "uniform interfaces").

---

## 5. The files and how they connect

| File | Runs as | Port | Responsibility (single) | Talks to |
|---|---|---|---|---|
| `config.q` | loaded by all q procs | — | shared ports, paths, symbols, **schemas** | — |
| `lib.q` | loaded by rdb, hdb | — | pure helpers: `applyUpd` guard, `hdbPath` | — |
| `feed_cpp.cpp` | native binary | — | generate + push data (C++); uses `qipc.hpp` | tp (5010) |
| `qipc.hpp` | header-only | — | kdb+ wire-protocol serialization (testable) | — |
| `feed.q` | `q feed.q` | 5013 | same, pure-q fallback | tp (5010) |
| `tp.q` | `q tp.q` | 5010 | ingest, sequence, log, fan-out | subscribers |
| `rdb.q` | `q rdb.q` | 5011 | today's state + live queries + EOD | tp, hdb |
| `hdb.q` | `q hdb.q` | 5012 | partitioned on-disk history | — |
| `verify.q` | one-shot client | — | query the live RDB | rdb (5011) |
| `eod.q` | one-shot client | — | trigger the EOD flush | rdb (5011) |
| `start.sh` / `stop.sh` | shell | — | orchestrate processes | all |
| `build.sh` | shell | — | compile the C++ feed | — |
| `tests/` | shell + q + c++ | — | unit + integration tests | — |
| `bench/` | shell + c++ + q | — | throughput + latency benchmarks | — |

Each `.q` file is a **single process with a single responsibility**. They share *only*
`config.q`; everything else is IPC. This is the heart of the design.

### config.q — the shared contract (DRY)
Loaded by every q process with `system "l config.q"`. It is the **single source of
truth** for ports, host, traded symbols, data directories, the end-of-day time, and the
table **schemas**. Nothing else hard-codes a port or a schema. (The C++ side mirrors the
schema on the wire — a language boundary, not duplication we can remove.)

### lib.q — pure, testable helpers
Holds the two non-trivial bits of logic as side-effect-free functions: `applyUpd` (the
snapshot/live de-dup guard used by the RDB) and `hdbPath` (the partition path builder).
Because they're pure and isolated, they are **unit tested** in `tests/test_units.q` — and
that test caught a real q precedence bug before it could reach the pipeline.

### tp.q — the tickerplant
The only process that sees all data. State: `.u.seq` (per-table sequence), `.u.buff`
(accumulated rows for catch-up), `.u.log` (disk log handle), `.u.w` (subscriber handles).
- `upd[t;x]` — the hot path: bump seq, log, buffer, broadcast.
- `.u.sub[t]` — subscription handshake; registers the caller and replies
  `(current seq; full snapshot)` so a new subscriber catches up atomically.
- `.z.ps` / `.z.pg` — route async pushes and sync subscriptions.

### rdb.q — real-time database
Holds **today's** tables in memory. Its `.z.ps` applies broadcasts using the
snapshot/live guard (`.u.lastSeq`). `sub` performs the sync handshake. `.eod` flushes to
the HDB and resets. A `.z.ts` timer fires `.eod` automatically once past `CFG.eodTime`.

### hdb.q — historical database
Owns the date-partitioned on-disk store. `upd[t;x]` enumerates symbols (`.Q.en`) and
splays into `hdb/<date>/<table>/`. On startup `loadPartitions` walks the directory tree,
loads the symbol enumeration, and resolves each table back into the root namespace.

### feed.q — pure-q feed (fallback)
Same role as the C++, in q. `makeTrades` / `makeQuotes` build random batches; `.z.ts`
publishes every 100 ms. Kept as a dependency-free fallback so the system runs even
without a C++ compiler.

### feed_cpp.cpp — the bank-standard feed handler
See §6.

### verify.q / eod.q — thin clients
Demonstrate **remote querying over IPC**: `h "select ... from trade"`. They prove the
system is queryable by external processes, exactly like a trader's dashboard.

### start.sh / stop.sh — orchestration
Start order encodes a real dependency chain: hdb first (rdb connects to it at startup),
then tp (rdb subscribes), then rdb, then the feed last (so no data is missed).

---

## 6. The C++ feed handler deep dive

**Why C++?** On a trading floor the process that talks to the exchange is C++ (or Java)
for latency and control over memory/bytes. It parses the exchange's binary protocol and
normalises it into q tables. `feed_cpp.cpp` does exactly that shape of work.

**Why implement the protocol by hand?** The KDB-X distribution does not ship the classic
C API library, and the binary does not export the `k()` symbols. Implementing the wire
protocol directly (a) removes all external dependencies, (b) demonstrates you understand
what is *actually on the wire*, and (c) is exactly what a low-latency handler cares about.

**The wire format** (little-endian), verified against q's `-8!`:

```
message = [0x01 arch][0x00 async][0x00 0x00 pad][int32 total length][payload]
payload = general list: 0x00 0x00 03  →  `upd ; `trade ; table
symbol  = 0xf5 + chars + 0x00                       (atom)
vector  = type + attr(0) + int32 count + data
table   = 0x62 0x00 0x63 + name-symbol-vector + general-list-of-columns
```

Column types used: timestamp `0x0c`, symbol `0x0b`, float `0x09`, long `0x07`.
Handshake: send `username + 0x06 + 0x00`, read the server's 1-byte capability.

**How it was validated:** I dumped q's own bytes with `-8!` for the exact message,
matched the C++ byte-for-byte, and confirmed end-to-end that the RDB/HDB receive correct
`p s f j` columns and real symbols.

**Talking point:** "I could have used the KX C API; because it wasn't available for
KDB-X I implemented the serialization myself and verified it against q's `-8!` output."

---

## 7. Software engineering principles applied

Use these as named talking points.

- **DRY (Don't Repeat Yourself).** `config.q` is the single source of truth for ports,
  paths, symbols and schemas; `rdb.q` references `CFG.trade`/`CFG.quote` instead of
  redefining them; the tricky logic (`applyUpd`, `hdbPath`) lives once in `lib.q`;
  `start.sh` no longer repeats port numbers. (Cross-language duplication between the q
  feed and the C++ feed is unavoidable and is documented, not accidental.)
- **KISS (Keep It Simple).** One message shape `` (`upd; table; data) `` at every hop;
  the "database" is just in-memory tables and splayed files; the C++ protocol is a few
  hundred lines with no framework. Complexity is only added where the domain demands it
  (sequence numbers, disk log).
- **YAGNI (You Aren't Gonna Need It).** No message bus, no external database, no config
  service, no premature abstraction. Sequence numbers and the disk log *are* built because
  the tick architecture genuinely requires them — but nothing speculative is.
- **Single Responsibility.** One process per file, one job each: tp ingests, rdb serves
  live, hdb serves history, feed produces. `lib.q` holds only pure helpers.
- **Separation of Concerns / loose coupling.** The feed knows only the tp's port; the
  RDB knows only the tp and hdb ports. Subscribers are decoupled from the source — the tp
  fans out; the producer never needs to know who consumes.
- **Configuration over hard-coding.** All tunables live in `config.q`; the shell scripts
  accept overrides (`Q=...`).
- **Uniform interfaces.** The same `(`upd; table; data)` message flows feed→tp and
  rdb→hdb, so readers/handlers are reusable and easy to reason about.
- **Fail-safe / recovery by design.** The tp writes a disk log before fan-out (crash
  recovery); the RDB uses sequence numbers to make subscription idempotent (no
  double-count on snapshot + live overlap).
- **Progressive enhancement.** `start.sh` prefers the C++ feed and transparently falls
  back to the q feed — the system works at every level of setup.
- **Idempotent, reproducible environment.** Runtime data (`log/`, `hdb/`, `out/`) is
  git-ignored; a fresh clone builds fresh state.

---

## 8. Testing & benchmarks (the numbers to quote)

Tests live in `tests/` and run with one command:

```bash
bash tests/run_tests.sh
```

| Layer | File | Checks |
|---|---|---|
| Unit (C++) | `tests/test_ser.cpp` | serialized message is **byte-for-byte identical** to q's own `-8!` output |
| Unit (q) | `tests/test_units.q` | config values, schema types, the `applyUpd` de-dup guard, `hdbPath` |
| Integration | `tests/test_e2e.sh` | starts the pipeline, asserts live rows arrive, EOD writes a partition, restarted HDB serves history |

The C++ unit test is the important one: it proves the hand-rolled wire protocol is
correct without any network, and it caught a real precedence bug (see §7).

Benchmarks live in `bench/` and run with `bash bench/bench.sh`. Measured on WSL:

| Metric | Result |
|---|---|
| C++ message serialization (single thread) | **~800,000 msg/s · ~8.0M rows/s · ~300 MB/s · 1.25 µs/msg** |
| End-to-end ingestion (C++ feed → tp → rdb) | **~417,000 trade rows/s sustained** |
| IPC sync round-trip (client → rdb) | **~91 µs/call** (20,000 calls) |

Why these matter in an interview: a market-data system is judged on throughput and
latency. Being able to say "I measured 800k messages/s serialization and 417k rows/s
end-to-end, and I know where the time goes" is far stronger than "it works".

Honest caveats to volunteer: the C++ feed emits *simulated* data (no real exchange
protocol); the tp log is written but replay-on-restart is a documented next step; and the
numbers are single-threaded on a WSL VM, so treat them as orders of magnitude, not SLAs.

## 9. Interview Q&A (rehearse these)

**Q: Walk me through the architecture.**
Lead with §1/§3: feed → tickerplant → RDB/HDB, one ingestion point, seq numbers + log,
live vs historical split, EOD flush.

**Q: Why a tickerplant at all? Why not have consumers connect to the feed directly?**
Single ingestion prevents duplicated work and divergence; it gives one ordered,
sequenced, recoverable stream; and it decouples producers from an unknown set of
consumers (the tp fans out).

**Q: How do you stop a subscriber from double-counting during catch-up?**
The subscription handshake returns `(current seq; full snapshot)`. The RDB stores that
seq and, in its message handler, applies a broadcast only if its seq is greater than the
snapshot seq — so any update that overlaps the snapshot is skipped.

**Q: How does recovery work?**
The tp appends every update to a per-table log before broadcasting. On restart you can
replay the log (the mechanism is there; wiring a replay on start is the obvious next
step).

**Q: Why is the feed in C++ and the rest in q?**
Latency and byte-level control at the boundary with the exchange; q is ideal for the
in-memory analytics and the disk store. This split is exactly what banks do.

**Q: How is history stored?**
As a **partitioned** HDB: one directory per date, each containing **splayed** tables
(column files). Symbols are enumerated once via `.Q.en`. This is the standard kdb+ layout
and scales to billions of rows.

**Q: What was the hardest part?**
Honest, strong answer: KDB-X 5.0 deviates from classic kdb+ in several ways (bare `/`
comments swallow a file, `\l` changes the working directory, `insert` is broken, splay
needs an hsym with a trailing slash, etc.). I diagnosed each by isolating it with minimal
reproductions and worked around them. (See the compatibility table in `README.md`.)

**Q: How would you scale this?**
Sharding the tp by symbol, a gateway process for routing queries across RDB/HDB, real
exchange connectivity (FIX/OUCH), log replay on restart, and multiple RDBs behind a
load balancer.

---

## 10. Running the demo live

```bash
# one-time
sudo apt-get update && sudo apt-get install -y g++ make
bash build.sh            # compile the C++ feed handler

bash start.sh            # hdb, tp, rdb, then the C++ feed
q verify.q               # live per-symbol stats from the RDB
q eod.q                  # flush today -> hdb
ls hdb/                  # show the date partition
bash stop.sh
```

If asked "show me the wire": `diff` the C++ serializer's output against `q`'s `-8!` of
the same object.

---

## 11. Extensions / what I'd do next

- **Java service** (Spring Boot) querying the HDB via the kdb+ Java API — rounds out the
  C++/Java/C# enterprise story.
- **C# subscriber** to the tickerplant for a .NET client.
- **Log replay** on tp restart (crash recovery end to end).
- **Gateway** process routing queries between RDB and HDB transparently.
- **Intraday writedown** and compression for the HDB.

---

## Appendix — KDB-X 5.0 gotchas encountered

| Classic kdb+ | KDB-X 5.0 | Workaround in this repo |
|---|---|---|
| `\` trailing comment | `/` is the comment char; a **bare `/` line eats the rest of the file** | all comments use `/` |
| `string \`:hdb` = `"hdb"` | returns `":hdb"` | keep the colon when building paths |
| `set dir/table` splays a table | only with an **hsym + trailing slash** | `` p:`$":hdb/",date,"/",tab,"/"; p set x `` |
| `insert` appends | `insert` throws `'type` | use `upsert` / `.[t;();,;x]` |
| `neg[h] msg` async file write | fails `'type` | write synchronously |
| `\l dir` loads a db | **changes the working directory** | manual partition loader |
| `.Q.l` loads a db | errors on the `sym` file | manual loader via `key`/`get` |
| bare symbol `` `.u.upd `` | variable reference → `'.u.upd` | always write the literal `` `.u.upd `` |
