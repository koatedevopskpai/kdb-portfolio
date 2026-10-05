package com.koate.hdbservice.web;

import com.koate.hdbservice.kdb.KdbException;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/** Maps domain exceptions to clean HTTP responses. */
@RestControllerAdvice
public class ApiExceptionHandler {

    /** Bad input (e.g. an invalid symbol) -&gt; 400. */
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> badRequest(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(Map.of("error", "bad request", "detail", String.valueOf(e.getMessage())));
    }

    /** kdb+ unreachable or q error -&gt; 503 (the data source is unavailable). */
    @ExceptionHandler(KdbException.class)
    public ResponseEntity<Map<String, Object>> kdbUnavailable(KdbException e) {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(Map.of("error", "kdb+ unavailable", "detail", String.valueOf(e.getMessage())));
    }
}
