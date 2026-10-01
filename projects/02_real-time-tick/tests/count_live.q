/ helper: write the live rdb trade row count to out/live_count.txt
/ (writing to a file avoids parsing q's stdout)
h:hopen `:localhost:5011
`:out/live_count.txt 0: enlist string h "count trade"
exit 0