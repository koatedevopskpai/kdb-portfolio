/ helper: write the hdb trade row count to out/hist_count.txt
h:hopen `:localhost:5012
`:out/hist_count.txt 0: enlist string h "count trade"
exit 0