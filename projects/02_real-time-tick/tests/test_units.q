/ ============================================================
/ test_units.q - unit tests for config.q and lib.q
/ Run from the project root:  q tests/test_units.q
/ Exits non-zero if any check fails (CI-friendly).
/ ============================================================

system "l config.q"
system "l lib.q"

.pass:0
.fail:0
chk:{[name;cond]
  $[cond; .pass+:1; .fail+:1];
  $[cond; -1 "  ok   ",name; -1 "  FAIL ",name];
  }

/ ---- config: single source of truth ----
chk["config: tpPort";  CFG.tpPort=5010]
chk["config: rdbPort"; CFG.rdbPort=5011]
chk["config: hdbPort"; CFG.hdbPort=5012]
chk["config: host";    CFG.host~"localhost"]
chk["config: syms";    CFG.syms~`AAPL`MSFT`GOOG`AMZN`TSLA`NFLX]

/ ---- schemas: single source of truth ----
chk["schema: trade columns"; cols[CFG.trade]~`time`sym`price`size]
chk["schema: trade types";   (exec t from meta CFG.trade)~"psfj"]
chk["schema: quote columns"; cols[CFG.quote]~`time`sym`bid`ask`bsize`asize]
chk["schema: quote types";   (exec t from meta CFG.quote)~"psffjj"]

/ ---- lib: applyUpd (snapshot / live de-duplication) ----
chk["applyUpd: unknown table applies";   applyUpd[()!(); `trade; 1]]
chk["applyUpd: newer seq applies";        applyUpd[(enlist `trade)!enlist 5; `trade; 6]]
chk["applyUpd: equal seq suppressed";     not applyUpd[(enlist `trade)!enlist 5; `trade; 5]]
chk["applyUpd: older seq suppressed";     not applyUpd[(enlist `trade)!enlist 5; `trade; 4]]

/ ---- lib: hdbPath ----
chk["hdbPath: format"; hdbPath[`:hdb; 2026.10.05; `trade]~`$":hdb/2026.10.05/trade/"]

-1 "-----------------------------------------";
-1 "passed: ",string[.pass],"   failed: ",string[.fail];
exit .fail