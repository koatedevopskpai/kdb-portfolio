package com.koate.hdbservice.kdb;

import com.koate.hdbservice.config.KdbProperties;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * A small, self-healing pool of kdb+ IPC connections.
 *
 * <p>kdb+ connections are stateful and not thread-safe, so a web service serving
 * concurrent requests must not share one. This pool lends a connection per call and
 * creates new ones on demand (bounded by the queue capacity on the return path).
 * A borrowed connection is validated first; a dead one is discarded and replaced.
 */
@Component
public class KdbConnectionPool {

    private static final Logger log = LoggerFactory.getLogger(KdbConnectionPool.class);

    private final KdbProperties props;
    private final BlockingQueue<KdbConnection> pool;

    public KdbConnectionPool(KdbProperties props) {
        this.props = props;
        this.pool = new LinkedBlockingQueue<>(props.poolSize());
    }

    /** Borrow a connection, run {@code call}, and return the connection to the pool. */
    public <T> T withConnection(KdbCall<T> call) {
        KdbConnection conn = borrow();
        boolean healthy = false;
        try {
            T result = call.apply(conn);
            healthy = true;
            return result;
        } catch (com.kx.c.KException e) {
            // a q error is the caller's fault, not the connection's
            healthy = true;
            throw new KdbException("q error: " + e.getMessage(), e);
        } catch (KdbException e) {
            throw e;
        } catch (Exception e) {
            throw new KdbException("kdb+ IPC failure: " + e.getMessage(), e);
        } finally {
            if (healthy) {
                release(conn);
            } else {
                conn.close();
            }
        }
    }

    /** True if a connection can be established and answer a trivial query. */
    public boolean ping() {
        try {
            return withConnection(c -> c.k("1+1") != null);
        } catch (KdbException e) {
            return false;
        }
    }

    private KdbConnection borrow() {
        KdbConnection conn = pool.poll();
        try {
            if (conn != null && !conn.isAlive()) {
                log.debug("discarding stale kdb+ connection");
                conn.close();
                conn = null;
            }
            if (conn == null) {
                conn = new KdbConnection(props);
                log.debug("opened new kdb+ connection to {}:{}", props.host(), props.port());
            }
        } catch (Exception e) {
            throw new KdbException(
                    "cannot connect to kdb+ at %s:%d".formatted(props.host(), props.port()), e);
        }
        return conn;
    }

    private void release(KdbConnection conn) {
        if (!pool.offer(conn)) {
            conn.close(); // pool full; drop the extra connection
        }
    }
}
