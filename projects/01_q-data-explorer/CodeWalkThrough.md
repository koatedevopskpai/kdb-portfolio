# Project A — q Data Explorer CLI

A step-by-step scaffold for building a small command-line data explorer in q.
**You type every line yourself** — each section tells you *what* to write, *why*, and *what you should see*. Work through it in a `q` REPL, then assemble the pieces into `explorer.q`.

## Learning objectives

- q datatypes & table literals
- Reading / writing CSV (`0:`, `csv`)
- `select` / `update` / `exec` (qSQL)
- Functions & dictionaries (`!`)
- Splayed (HDB-style) storage with `.Q.en`

## Project layout

```
01_q-data-explorer/
  CodeWalkThrough.md  <- this guide
  data/               <- generated trades.csv
  out/                <- saved results (symStats.csv)
  hdb/                <- splayed storage (created in Step 7)
  explorer.q          <- the final script (you build this, step by step)
```

Work in this folder from now on (its WSL path is
`/mnt/c/Users/koate/development/kbd-q/kbdprojects/01_q-data-explorer`).

> **KDB-X 5.0 gotchas (learned the hard way):**
> 1. **`/` is the comment character** — it works at the start of a line *and* as a trailing comment (`n:1000 / comment`). The classic q `\` trailing comment does **not** work in KDB-X.
> 2. **Use relative file paths**, not absolute ones. `` `:/mnt/c/... `` breaks (the `/` gets eaten as a comment) — `` `:data/trades.csv `` works fine.
> 3. **CSV type map**: symbol is `S`, **not** `N`. `N` means *timespan*. A wrong type map silently reads nulls — always sanity-check with `meta` and a null count.

---

## Step 0 — Start a q session

From a terminal:

```bash
q
```

You should see the kdb+ banner and a `q)` prompt. The install put `q` on your WSL path; in PowerShell use the `q` function we set up.

## Step 1 — Generate a sample trades table

*What we're doing:* we have no real data yet, so we fabricate a trades feed. This also teaches you **table literals** and **random vector generation**.

*Type this — every line is annotated so you know why it's there:*

```q
/ ============================================================
/ THE "?" OPERATOR - random draw
/ ============================================================
n:1000 / ":" assigns the long 1000 to variable n, available everywhere below

/  "?" with an int on the LEFT and a range on the RIGHT = random draw
/    left  = how many items to draw
/    right = the population to draw from

n?1000 / draw 1000 random ints from 0..999  (a bare int literal IS a range 0 1 2 ... 999)
n?50f  / draw 1000 random FLOATS in [0, 50)      - the "f" makes it a float range
n?00:30:00.000000000 / draw 1000 random TIMES within 30 minutes
/                    00:30:00.000000000 is a TIME literal (h:m:s.nanoseconds)

/ ============================================================
/ BUILDING THE TIMESTAMPS
/ ============================================================
.z.p / .z.p = current UTC TIMESTAMP (nanosecond precision). The .z namespace = system info.

.z.p + n?00:30:00.000000000 / timestamp + time vector = "now + random 0..30min" for each row

asc .z.p + n?00:30:00.000000000 / asc sorts ascending -> time-ordered
/                                asc ALSO tags the vector "sorted" (a performance hint)

/ ============================================================
/ THE TABLE LITERAL
/ ============================================================
t:([] time:asc .z.p + n?00:30:00.000000000; sym:n?`AAPL`MSFT`GOOG`AMZN`TSLA; price:100 + n?50f; size:1 + n?1000)
/ ([] ...) = TABLE LITERAL. The [] means "no key columns" (a simple table).
/ Columns are separated by ";" - each is  name : expression
/ The expression must be a VECTOR - all columns must have equal length (1000 rows).

/   time  = ascending future timestamps
/   sym   = random pick of 5 SYMBOLS
/   price = random floats 0-49, shifted UP by 100 -> range 100..149.99
/   size  = random ints 0-999, shifted UP by 1   -> range 1..1000

/ SYMBOL literals start with a backtick: `AAPL
/ A LIST of symbols = backticks joined:  `AAPL`MSFT`GOOG`AMZN`TSLA
/ 100 + n?50f : scalar + vector = add to EVERY element (vector maths)

/ ============================================================
/ DISPLAYING
/ ============================================================
t / print the table
/ the `s# marker before the time values = "sorted" attribute tag from asc

meta t / returns the table's METADATA dictionary:
/       c  = column name        t  = type char        f/a  = attribute info
/       type chars: p = timestamp, s = symbol, f = float, j = long
/       the "s" on the time row = that column is marked SORTED
```

The two "aha" details to absorb:

| Expression | What it does |
|---|---|
| `100 + n?50f` | scalar + vector = add to EVERY element (vector maths) |
| `asc` + `` `s# `` | `asc` tags the vector "sorted" — a hint q exploits in fast lookups |

Breakdown of the flow:

| Expression | What it does |
|---|---|
| `n?50f` | draw 1000 random floats 0–49 |
| `n?00:30:00.000000000` | 1000 random durations within 30 minutes |
| `.z.p + ...` | current timestamp + durations → future timestamps |
| `asc` | sort ascending (this is your time ordering) |
| `([...])` | **keyed** table literal — column names on the left, definitions on the right |

Check what you built:

```q
t
meta t
```

`t` shows 1000 rows; `meta t` shows column names and types (`p` = timestamp, `s` = symbol, `f` = float, `j` = long).

## Step 2 — Persist the table to CSV

*What we're doing:* storing our in-memory table as a real file on disk, then proving we can round-trip it back. This is the `0:` file-handle operator (integer 0 = filesystem).

```q
system "mkdir -p data" / create the folder (you only do this once)
`:data/trades.csv 0: csv 0: t
```

The flow, read right-to-left:

1. `csv 0: t` — convert the table to lines of CSV text (list of strings)
2. `0:` with a path on the left — write those lines to the file

> Note: relative path `` `:data/trades.csv `` — absolute paths like `` `:/mnt/c/... `` break in KDB-X (see gotchas above).

Verify the file exists (outside q, or via `system`):

```q
system "head -3 data/trades.csv"
```

You should see a header row then data rows.

## Step 3 — Load the CSV back into q

*What we're doing:* CSV is just text — q needs a **type map** to decode each column. This is the real-world skill: reading exchange/bank exports.

```q
trades:("PSFJ";enlist ",") 0: `:data/trades.csv
```

Breakdown:

| Piece | Meaning |
|---|---|
| `("PSFJ";enlist ",")` | column type map + the separator |
| `P` | timestamp |
| `S` | **symbol** (not `N`!) |
| `F` | float |
| `J` | long |
| `enlist ","` | comma is the field delimiter |

> If you use `N` for the symbol column, every symbol comes back null — always verify with `meta trades` (you want `s` in the type column) and the Step 4 null count.

Sanity check — the two tables should agree:

```q
count trades
meta trades
```

## Step 4 — Profile the data (counts, types, nulls)

*What we're doing:* every analyst tool starts with "what am I looking at?". We build a column-by-column profile.

Column names and types:

```q
cols trades
meta trades
```

Null counts per column — *type this annotated build-up, one step at a time:*

```q
/ ============================================================
/ WHAT ARE WE LOOKING AT?  (column profiling)
/ ============================================================

cols trades / return the list of column NAMES as symbols: `time`sym`price`size
meta trades / the metadata dictionary: c = name, t = type char, f/a = attribute

/ ============================================================
/ THE FLIP TRICK: a table is a "flipped dictionary"
/ ============================================================
flip trades / table -> DICTIONARY: column name -> column vector
/            think of it as "turn the table sideways"

value flip trades / value on a dict = the VALUES only
/                  i.e. the list of column vectors, in order

/ ============================================================
/ COUNTING NULLS PER COLUMN
/ ============================================================
{sum null x} / a LAMBDA (anonymous function): x is its argument
/   null x   / tests every element -> BOOLEAN vector (1b = null, 0b = not)
/   sum      / sums the booleans -> total count of nulls (true counts as 1)

{sum null x} each value flip trades
/ each = apply the lambda to EVERY column vector, one at a time
/        result: a list like 0 0 0 0 (no nulls in our generated data)

/ ============================================================
/ ZIP NAMES BACK ONTO THE COUNTS  ->  the "!" dictionary operator
/ ============================================================
cols[trades] / function-application syntax: cols applied to trades

cols[trades]!{sum null x} each value flip trades
/ ! = build a DICTIONARY from two equal-length lists
/     LEFT  = keys   (the column names)
/     RIGHT = values (the null counts)
/
/     result:  time|0   sym|0   price|0   size|0
```

The key mental model: **a table is a dictionary of equal-length columns, and `flip` is the switch between the two views.**

```q
t            / table view
flip t       / dictionary view (name -> vector)
```

Read it in pieces:

| Piece | Meaning |
|---|---|
| `flip trades` | table → dictionary (column name → column data) |
| `value flip trades` | just the column vectors, as a list |
| `{sum null x} each ...` | apply the null-count to each column |
| `cols[trades]!...` | zip names back onto counts → a dictionary |

You should see `time|0`, `sym|0`, `price|0`, `size|0` (we made clean data).

## Step 5 — Summary statistics (qSQL)

*What we're doing:* the money-maker. `select` is q's SQL. It reads **top-to-bottom, right-to-left**: `from` first, then `by`, then the aggregates.

*Type this annotated build-up:*

```q
/ ============================================================
/ qSQL - q's SQL. READ EVERY QUERY RIGHT-TO-LEFT:
/     from -> where -> by -> select
/ ============================================================

/ SIMPLE AGGREGATION (whole table, one result row)
select cnt:count i, minPx:min price, maxPx:max price, avgPx:avg price from trades
/  ^ result columns                                    ^ the table
/  cnt:count i   -> result column named "cnt" = count of rows
/                  i = the IMPLICIT row index (0 1 2 ... n-1)
/                  count i = how many rows (any column works; i is the habit)
/  minPx:min price / maxPx:max price / avgPx:avg price
/  each result column =  aliasName : aggregateFunction column

/ ------------------------------------------------------------
/ GROUPING WITH "by"  ->  one result row PER GROUP
/ ------------------------------------------------------------
symStats:select cnt:count i, avgPx:avg price, minPx:min price, maxPx:max price, totSize:sum size by sym from trades
/                                                                ^^^^^^ group by the sym column
/
/  by sym : split the table into sub-tables, one per symbol, then
/          run the aggregates on EACH sub-table separately
/  result: a KEYED table - key column = sym, value columns = your aggregates

/ ------------------------------------------------------------
/ THE OTHER PIECES OF qSQL VOCABULARY
/ ------------------------------------------------------------
select cnt:count i by sym from trades                     / just counts per symbol
select avgPx:avg price by sym from trades where size>500   / FILTER FIRST, then aggregate
/                                                     ^^^^ the "where" clause
/
/ flow: from trades -> where size>500 (keep only big trades) -> by sym -> select avg

/ ------------------------------------------------------------
/ READING THE RESULT
/ ------------------------------------------------------------
symStats        / shows the keyed table (sym column + your aggregates)
meta symStats    / note: sym appears as a KEY column (a "s#" sorted key)
```

`count i` counts rows (any column works; `i` is the implicit row index).

Three habits to build:

1. **Read right-to-left**: `from` first, then `where`, then `by`, then `select`.
2. **`count i`** = count rows. You'll see it in every q codebase.
3. **A `by` query returns a keyed table** — the grouping columns become the key. Look up one group with `symStats[`MSFT]`.

Progressions to feel it click:

```q
select from trades where sym=`MSFT
select avg price from trades where sym=`MSFT
select avgPx:avg price by sym from trades where size>500
```

## Step 6 — Save results to CSV

*What we're doing:* exporting your analysis so the rest of the bank can consume it.

```q
system "mkdir -p out" / only once
`:out/symStats.csv 0: csv 0: symStats
```

Same `csv 0:` idiom as Step 2 — export is just the inverse of import.

## Step 7 — Save to a splayed (HDB) table

*What we're doing:* q's trick for scaling to billions of rows — store the table on disk **by column** (splayed), and enumerate symbols once. `.Q.en` handles the symbol enumeration.

```q
.Q.en[`:hdb] trades
`:hdb/trades set .Q.en[`:hdb] trades
```

This creates `hdb/sym` (the symbol list) and `hdb/trades/` (one file per column).

Load it back to prove the round-trip:

```q
\l hdb/trades
select cnt:count i by sym from trades
```

## Step 8 — Turn it into a CLI

*What we're doing:* wrapping everything into **functions** so the script runs with arguments — this is the "engineering" part that interviewers like.

```q
profile:{[t]
  (cols[t]!{sum null x} each value flip t), meta t}

read:{[file]
  ("PSFJ";enlist ",") 0: hsym `$file}

main:{[file]
  t:read file;
  show profile t;
  show select cnt:count i, avgPx:avg price by sym from t;
  ...}
```

Try it:

```q
main "data/trades.csv"
```

## Final checkpoint — run the whole script non-interactively

Put every step into `explorer.q` and run it as a program:

```bash
q explorer.q data/trades.csv
```

If it prints a profile + per-symbol stats and writes both `out/symStats.csv` and the splayed `hdb/`, **Project A is done.**

---

## Extensions (pick 1–2)

1. **Type-map inference**: detect column types from a header instead of hardcoding `"PSFJ"` (teaches `each`, parsing, `.Q` utilities).
2. **Date partitioning**: change the splay to partition by date — `hdb/2026.10.05/` (directly sets you up for Project C).
3. **Filter by symbol**: add `where sym in ...` clauses and pass the symbols as a CLI argument.

---

## Enterprise-language track (for IB trading roles)

kdb+ sits in the *middle* of a bank's stack: q runs the data layer; the surrounding systems are C++, Java and C#. To show those skills, extend the roadmap with:

- **Project E — C# client**: use the kdb+ C# API (`cn`/KdbSharp) to subscribe to your tickerplant from a .NET console app and render live trades. Proves `c#` + IPC + real-time.
- **Project F — Java client**: query your HDB from a Spring Boot service via the kdb+ Java API (`cx`). Expose a `/stats?sym=MSFT` REST endpoint backed by qSQL. Proves Java + enterprise patterns.
- **Project G — C++ feed handler**: simulate an exchange feed in C++ (the classic IB role) and push ticks into your q process over IPC using the C API. Proves low-latency C++ + connectivity.

Suggested order: **C++ feed handler → C# subscriber → Java REST service**, matching how a bank physically wires its market data pipeline.