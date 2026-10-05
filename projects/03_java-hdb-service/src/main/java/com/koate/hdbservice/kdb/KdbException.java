package com.koate.hdbservice.kdb;

/** Thrown when a kdb+ IPC call fails (connection lost, q error, serialization). */
public class KdbException extends RuntimeException {

    public KdbException(String message) {
        super(message);
    }

    public KdbException(String message, Throwable cause) {
        super(message, cause);
    }
}
