package com.koate.hdbservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/**
 * REST service that exposes a kdb+ historical database (HDB) over HTTP.
 *
 * <p>The service talks to kdb+ using the official KX Java client ({@code com.kx.c})
 * over the native kdb+ IPC protocol; queries are written in q (qSQL).
 */
@SpringBootApplication
@ConfigurationPropertiesScan
public class HdbServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(HdbServiceApplication.class, args);
    }
}
