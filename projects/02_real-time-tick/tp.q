/ ============================================================
/ TICKERPLANT (tp)  -  port 5010
/ - 
/ The single point of ingestion for ALL market data.
/ Every update in the system flows through here:
/ - 
/     feed --> tp --> (rdb, hdb, any subscriber)
/ - 
/ Responsibilities:
/   1. accept updates pushed by the feed handler
/   2. assign a monotonically increasing sequence number per table
/   3. append every update to a rolling disk log (crash recovery)
/   4. fan each update out to every subscriber (async, non-blocking)
/ - 
/ This is the exact role a real bank's tickerplant plays.
/ ============================================================

system "l config.q"
system "p ", string CFG.tpPort

/ ---- state ----
.u.seq:()!()   / table -> last sequence number
.u.buff:()!()  / table -> accumulated data (so late subscribers can catch up)
.u.log:()!()   / table -> open log file handle
.u.w:()        / subscriber handles

/ ---- broadcast a message to every subscriber (async, non-blocking) ----
.u.broadcast:{[msg]
  if[count .u.w; neg[.u.w]@\: msg]
  }

/ ---- upd: called whenever new data arrives ----
upd:{[t;x]
  / first contact for this table? initialise seq, buffer and log
  if[not t in key .u.seq;
    .u.seq[t]:0;
    .u.buff[t]:0#x;                      / empty table with the right schema
    system "mkdir -p ", string[CFG.logDir] except ":";
    .u.log[t]:hopen `$string[CFG.logDir],"/",string[t],".log";
    ];
  / next sequence number
  .u.seq[t]+:1;
  / keep the in-memory copy up to date (subscriber catch-up)
  .u.buff[t],:x;
  / persist to the disk log (crash recovery) - KDB-X writes files synchronously
  .u.log[t] (.u.seq[t]; x);
  / fan out to every subscriber
  .u.broadcast (`.u.upd; t; .u.seq[t]; x)
  }

/ ---- subscription handshake: register the caller and send a snapshot ----
.u.sub:{[t]
  .u.w,: enlist .z.w;              / remember the subscriber's handle
  :(.u.seq[t]; .u.buff[t])         / reply (current seq; full data so far)
  }

/ ---- route incoming messages ----
.z.pg:{value x}  / sync calls (subscription handshake)
.z.ps:{value x}  / async calls (feed pushes, client calls)

/ ---- signal that the tp is ready ----
0N!"TICKERPLANT ready on port ",string CFG.tpPort