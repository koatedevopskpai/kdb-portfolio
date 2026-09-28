/ ============================================================
/ VERIFY - connect to the rdb and confirm data is flowing
/ Usage:  q verify.q
/ Demonstrates remote querying (the professional way to use kdb+):
/ sending qSQL as strings to a process over IPC.
/ ============================================================

h:hopen `:localhost:5011

show "TRADE counts by symbol:"
show h "select cnt:count i, avgPx:avg price, minPx:min price, maxPx:max price by sym from trade"

show "QUOTE counts by symbol:"
show h "select cnt:count i, avgBid:avg bid, avgAsk:avg ask by sym from quote"

hclose h