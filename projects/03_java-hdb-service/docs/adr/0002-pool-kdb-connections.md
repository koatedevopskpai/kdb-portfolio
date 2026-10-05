# 2. Pool kdb+ connections

- **Status:** Accepted
- **Date:** 2026-10-05
- **Deciders:** George Kpai

## Context

A `com.kx.c` connection is stateful and **not thread-safe**. A Spring MVC service handles
requests on many Tomcat threads concurrently, so a single shared connection would corrupt
messages (interleaved reads/writes). Opening a fresh TCP connection per request is correct
but wasteful (handshake + connection setup on every call).

## Decision

Introduce a small `KdbConnectionPool`:

- a bounded `BlockingQueue` of idle connections; `borrow()` / `release()`;
- connections are validated before use and discarded/replaced if dead (self-healing);
- new connections are created on demand; extra ones are closed when the pool is full;
- `KdbQueryService` uses `withConnection(call)` so return-to-pool is guaranteed.

## Consequences

- **Positive:** thread-safe by construction; connection reuse; survives a kdb+ restart
  (stale connections are detected and replaced); no external pooling library needed.
- **Negative:** a tiny validation round-trip per borrow; a real deployment might prefer a
  dedicated pool or per-thread connections. Acceptable at this scale and easy to swap.
