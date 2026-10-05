package com.koate.hdbservice.web;

import com.koate.hdbservice.kdb.KdbQueryService;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** HTTP API over the kdb+ HDB. */
@RestController
@RequestMapping("/api")
public class HdbController {

    private final KdbQueryService queries;

    public HdbController(KdbQueryService queries) {
        this.queries = queries;
    }

    /** Liveness + kdb+ reachability. 200 when the HDB is reachable, 503 otherwise. */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        boolean up = queries.ping();
        Map<String, Object> body = Map.of("status", up ? "UP" : "DOWN", "kdb", up ? "reachable" : "unreachable");
        return ResponseEntity.status(up ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE).body(body);
    }

    /** Distinct symbols in the HDB. */
    @GetMapping("/symbols")
    public List<String> symbols() {
        return queries.symbols();
    }

    /** Per-symbol aggregate statistics across the whole HDB. */
    @GetMapping("/stats")
    public List<Map<String, Object>> stats() {
        return queries.allStats();
    }

    /** Aggregate statistics for one symbol. */
    @GetMapping("/stats/{symbol}")
    public List<Map<String, Object>> statsForSymbol(@PathVariable String symbol) {
        return queries.statsFor(symbol);
    }

    /** Recent trades for one symbol, e.g. {@code /api/trades/MSFT?limit=50}. */
    @GetMapping("/trades/{symbol}")
    public List<Map<String, Object>> trades(
            @PathVariable String symbol,
            @RequestParam(name = "limit", defaultValue = "100") int limit) {
        return queries.trades(symbol, limit);
    }

    /** Daily trade count and average price. */
    @GetMapping("/daily")
    public List<Map<String, Object>> daily() {
        return queries.daily();
    }
}
