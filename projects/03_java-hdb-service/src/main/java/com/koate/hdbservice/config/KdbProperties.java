package com.koate.hdbservice.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Connection settings for the kdb+ HDB, bound from the {@code kdb.*} properties.
 *
 * @param host          kdb+ host
 * @param port          kdb+ port (default 5012 = the portfolio HDB)
 * @param credentials   {@code "user:password"}, or blank for no auth
 * @param poolSize      number of IPC connections to keep in the pool
 * @param timeoutMillis socket timeout in milliseconds
 */
@ConfigurationProperties(prefix = "kdb")
public record KdbProperties(
        String host,
        int port,
        String credentials,
        int poolSize,
        int timeoutMillis) {

    public KdbProperties {
        if (host == null || host.isBlank()) host = "localhost";
        if (port <= 0) port = 5012;
        if (credentials == null) credentials = "";
        if (poolSize <= 0) poolSize = 4;
        if (timeoutMillis <= 0) timeoutMillis = 5000;
    }
}
