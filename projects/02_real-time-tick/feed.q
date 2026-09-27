/ ============================================================
/ FEED HANDLER (feed)  -  port 5013
/ - 
/ Simulates an exchange feed and pushes updates into the tp.
/ In a real bank this process:
/   - receives raw data from an exchange gateway
/     (the gateway is usually written in C++ or Java)
/   - normalises it into clean q tables
/   - pushes to the tickerplant asynchronously
/ ============================================================

system "l config.q"
system "p ", string CFG.feedPort

/ ---- connect to the tickerplant ----
h:hopen `$":",CFG.host,":",string CFG.tpPort

/ ---- generate a fresh batch of trade rows ----
makeTrades:{[]
  n:10;
  :([] time:.z.p + n?1000000;          / now + 0..1ms random
       sym:n?CFG.syms;                 / random symbol from the config list
       price:100 + n?50f;              / 100..150
       size:1 + n?1000j)               / 1..1000 as long (matches rdb schema)
  }

/ ---- generate a fresh batch of quote rows ----
makeQuotes:{[]
  n:10;
  :([] time:.z.p + n?1000000;
       sym:n?CFG.syms;
       bid:99 + n?50f;
       ask:100 + n?50f;
       bsize:1 + n?100j;
       asize:1 + n?100j)
  }

/ ---- push one batch of each to the tp ----
publish:{[]
  neg[h] (`upd; `trade; makeTrades[]);
  neg[h] (`upd; `quote; makeQuotes[]);
  }

/ ---- run publish every 100ms ----
.z.ts:publish
\t 100

0N!"FEED ready on port ",string CFG.feedPort," - pushing every 100ms"