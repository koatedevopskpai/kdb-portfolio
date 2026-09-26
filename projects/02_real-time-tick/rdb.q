/ ============================================================
/ REAL-TIME DATABASE (rdb)  -  port 5011
/ - 
/ Subscribes to the tickerplant and holds TODAY'S data in memory.
/   - applies every broadcast update as it arrives
/   - answers real-time queries on its port
/   - flushes the day's data to the HDB at end-of-day, then resets
/ - 
/ This is the process a trader's dashboard queries during the day.
/ ============================================================

system "l config.q"
system "l lib.q"
system "p ", string CFG.rdbPort

/ ---- grab the shared schemas (defined once in config.q - DRY) ----
/ we take a local reference: q is copy-on-write, so appending to `trade`
/ here never mutates the shared CFG.trade definition.
trade:CFG.trade
quote:CFG.quote

/ ---- catch-up bookkeeping: seq each table was covered up to ----
.u.lastSeq:()!()

/ ---- route incoming async messages (broadcasts from the tp) ----
.z.ps:{[m]
  if[`.u.upd~m[0];
    / apply only rows not already delivered by the subscription snapshot
    if[applyUpd[.u.lastSeq; m[1]; m[2]];
      .[m[1];();,;m[3]]];
    :(::)];
  m}

/ ---- connect to the tp and hdb ----
.u.tp:hopen `$":",CFG.host,":",string CFG.tpPort
.u.hdb:hopen `$":",CFG.host,":",string CFG.hdbPort

/ ---- subscribe: sync handshake returns (current seq; full snapshot) ----
sub:{[t]
  r:.u.tp (`.u.sub; t);
  / store the catch-up seq as a real int (0 = start from the beginning)
  .u.lastSeq[t]:$[count r[1]; r[0]; 0];
  / replace the schema only if there is data to catch up on
  if[count r[1]; t set r[1]];
  }
sub `trade
sub `quote

/ ---- end-of-day: push today's data to the hdb, then reset ----
.eod:{[]
  if[0<count trade; neg[.u.hdb] (`upd; `trade; trade)];
  if[0<count quote; neg[.u.hdb] (`upd; `quote; quote)];
  trade::0#trade;
  quote::0#quote;
  0N!"RDB flushed to HDB and reset"
  }

/ ---- automatic end-of-day once the clock passes CFG.eodTime ----
.u.done:0b
.z.ts:{[]
  if[(not .u.done) and .z.T>=CFG.eodTime;
    .eod[];
    .u.done:1b]}
\t 1000

0N!"RDB ready on port ",string CFG.rdbPort