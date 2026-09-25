/ ============================================================
/ CONFIG - shared by every process in the tick system
/ ============================================================

/ ---- process ports ----
CFG.tpPort:5010    / tickerplant
CFG.rdbPort:5011   / real-time database
CFG.hdbPort:5012   / historical database
CFG.feedPort:5013  / feed handler

/ ---- the host every process runs on ----
CFG.host:"localhost"

/ ---- symbols the feed will generate data for ----
CFG.syms:`AAPL`MSFT`GOOG`AMZN`TSLA`NFLX

/ ---- table schemas: the SINGLE SOURCE OF TRUTH (DRY) ----
/ Every q process grabs these from here rather than redefining them.
/ The C++ feed mirrors the same column names/types on the wire.
CFG.trade:([] time:`timestamp$(); sym:`symbol$(); price:`float$(); size:`long$())
CFG.quote:([] time:`timestamp$(); sym:`symbol$(); bid:`float$(); ask:`float$(); bsize:`long$(); asize:`long$())

/ ---- end-of-day time (RDB flushes to HDB once the clock passes this) ----
CFG.eodTime:16:00:00

/ ---- data directories (relative - KDB-X cannot use absolute paths) ----
CFG.logDir:`:log   / tickerplant logs (crash recovery)
CFG.hdbDir:`:hdb   / partitioned historical database