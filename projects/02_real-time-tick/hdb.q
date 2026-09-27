/ ============================================================
/ HISTORICAL DATABASE (hdb)  -  port 5012
/ - 
/ Owns the partitioned on-disk history. Receives the day's data
/ from the rdb at end-of-day and answers historical queries.
/ - 
/ On-disk layout (partitioned by date):
/ - 
/     hdb/
/       sym                      / symbol enumeration file
/       2026.10.05/
/         trade/                 / splayed columns: time, sym, price, size
/         quote/
/       2026.10.06/
/         ...
/ - 
/ Every partition is a directory named after its date.
/ ============================================================

system "l config.q"
system "l lib.q"
system "p ", string CFG.hdbPort

/ ---- make sure the hdb directory exists ----
system "mkdir -p ", string[CFG.hdbDir] except ":"

/ ---- load any existing partitions ----
/ KDB-X gotchas: .Q.l errors on the sym file, and \l CHANGES the working
/ directory. So we load each partition by hand.
/ How key distinguishes dirs from files: key of a FILE returns the file atom,
/ key of a DIRECTORY returns a list. So we only descend into directory entries.
loadPartitions:{[]
  / load the symbol enumeration FIRST so the FK columns can be resolved.
  / note the global assignment (::) - a plain : would make a LOCAL sym
  sym::@[get;`$string[CFG.hdbDir],"/sym";()];
  entries:key CFG.hdbDir;                       / e.g. `2026.10.05`sym
  {[d]
    ddir:`$string[CFG.hdbDir],"/",string[d];
    if[11h=type key ddir;                       / d is a date partition
      {[t;d]
        p:`$string[CFG.hdbDir],"/",string[d],"/",string[t];
        nm:`$string[t];                         / compute name first (avoid `$ precedence trap)
        / resolve the enumerated sym column back to real symbols
        nm set update sym:value sym from get p;
        0N! "hdb loaded: ",string[d],"/",string[t]
      }[;d] each key ddir
      ]
  } each entries
  }
loadPartitions[]

/ ---- called by the rdb at end-of-day: persist today's table ----
upd:{[t;x]
  if[0=count x; :(::)];                  / nothing to write
  d:.Q.en[CFG.hdbDir] x;                 / enumerate symbols (KDB-X set requires it)
  p:hdbPath[CFG.hdbDir; .z.d; t];        / shared path builder (lib.q)
  p set d                                 / splay into today's partition
  }

/ ---- route incoming async messages ----
.z.ps:{[m]
  if[`upd~m[0]; upd[m[1];m[2]]; :(::)];
  m}

0N!"HDB ready on port ",string CFG.hdbPort