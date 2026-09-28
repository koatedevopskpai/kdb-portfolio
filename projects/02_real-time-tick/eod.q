/ ============================================================
/ EOD - trigger an end-of-day flush from the rdb to the hdb
/ Usage:  q eod.q
/ After running, check hdb/ for a new date partition.
/ ============================================================

h:hopen `:localhost:5011
h ".eod[]"
show "end-of-day flush triggered"
hclose h