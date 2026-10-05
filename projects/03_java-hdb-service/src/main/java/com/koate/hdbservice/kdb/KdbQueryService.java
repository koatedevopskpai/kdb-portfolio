package com.koate.hdbservice.kdb;

import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.stereotype.Service;

/**
 * The query layer: builds qSQL (parameterised safely) and runs it over a pooled
 * kdb+ connection, returning JSON-ready structures.
 */
@Service
public class KdbQueryService {

    /** Symbols are used as q symbol literals, so restrict them to a safe charset. */
    private static final Pattern SYMBOL = Pattern.compile("^[A-Za-z0-9._-]{1,32}$");
    private static final int MAX_ROWS = 1000;

    private final KdbConnectionPool pool;

    public KdbQueryService(KdbConnectionPool pool) {
        this.pool = pool;
    }

    public boolean ping() {
        return pool.ping();
    }

    /** Distinct symbols present in the HDB. */
    @SuppressWarnings("unchecked")
    public List<String> symbols() {
        Object result = pool.withConnection(c -> c.k("exec distinct sym from trade"));
        Object json = QValue.toJson(result);
        return json instanceof List<?> list ? (List<String>) list : List.of();
    }

    /** Per-symbol aggregates across the whole HDB. */
    public List<Map<String, Object>> allStats() {
        return rows("0!select cnt:count i, avgPx:avg price, minPx:min price, "
                + "maxPx:max price, totSize:sum size by sym from trade");
    }

    /** Aggregates for a single symbol. */
    public List<Map<String, Object>> statsFor(String symbol) {
        return rows("select cnt:count i, avgPx:avg price, minPx:min price, "
                + "maxPx:max price, totSize:sum size from trade where sym=`" + safeSymbol(symbol));
    }

    /** Most recent (up to {@code limit}) trades for a symbol. */
    public List<Map<String, Object>> trades(String symbol, int limit) {
        int n = Math.max(1, Math.min(limit, MAX_ROWS));
        return rows(n + "#select time, price, size from trade where sym=`" + safeSymbol(symbol));
    }

    /** Daily trade counts and average price. */
    public List<Map<String, Object>> daily() {
        // KDB-X note: the `date$` cast is unavailable; "d"$time casts a timestamp to a date
        return rows("0!select cnt:count i, avgPx:avg price by day:\"d\"$time from trade");
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> rows(String q) {
        Object result = pool.withConnection(c -> c.k(q));
        Object json = QValue.toJson(result);
        return json instanceof List<?> list ? (List<Map<String, Object>>) list : List.of();
    }

    private static String safeSymbol(String symbol) {
        if (symbol == null || !SYMBOL.matcher(symbol).matches()) {
            throw new IllegalArgumentException("invalid symbol: " + symbol);
        }
        return symbol;
    }
}
