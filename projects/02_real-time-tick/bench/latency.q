/ ============================================================
/ latency.q - measure IPC round-trip latency to a q process.
/ Times a synchronous call to the rdb many times and reports the average.
/ ============================================================

port:5011
n:20000

h:hopen `$":localhost:",string port
do[100; h "1+1"]          / warm up

t0:.z.p
do[n; h "1+1"]
t1:.z.p

ns:"j"$(t1-t0)            / elapsed nanoseconds
-1 "IPC round-trip to :",(string port),": ",(string ns%n)," ns/call (",(string (ns%n)%1000)," us) over ",(string n)," calls"
exit 0