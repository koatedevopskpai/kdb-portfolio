package com.koate.hdbservice.kdb;

/** A unit of work that runs against a borrowed kdb+ connection. */
@FunctionalInterface
public interface KdbCall<T> {
    T apply(KdbConnection connection) throws Exception;
}
