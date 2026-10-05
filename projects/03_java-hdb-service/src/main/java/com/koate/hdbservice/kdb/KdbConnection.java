package com.koate.hdbservice.kdb;

import com.koate.hdbservice.config.KdbProperties;
import com.kx.c;
import java.io.IOException;

/**
 * A single kdb+ IPC connection (thin wrapper over the KX Java client {@link c}).
 *
 * <p>A {@code com.kx.c} instance is <b>not</b> thread-safe, so connections are never
 * shared between threads — {@link KdbConnectionPool} lends one out at a time.
 */
public final class KdbConnection implements AutoCloseable {

    private final c conn;

    public KdbConnection(KdbProperties props) throws c.KException, IOException {
        this.conn = props.credentials().isBlank()
                ? new c(props.host(), props.port())
                : new c(props.host(), props.port(), props.credentials());
    }

    /** Run a synchronous q expression and return the deserialized result. */
    public Object k(String q) throws c.KException, IOException {
        return conn.k(q);
    }

    /** Cheap liveness check used to validate pooled connections. */
    public boolean isAlive() {
        try {
            return conn.k("1+1") != null;
        } catch (Exception e) {
            return false;
        }
    }

    @Override
    public void close() {
        try {
            conn.close();
        } catch (Exception ignored) {
            // best-effort close
        }
    }
}
