# 1. Use the official KX Java client for kdb+ IPC

- **Status:** Accepted
- **Date:** 2026-10-05
- **Deciders:** George Kpai

## Context

The service must talk to kdb+ over IPC, both sending queries and **deserializing** the
responses (tables, vectors, dicts). In project 02 we hand-rolled the C++ wire protocol
because no KX C API was available for KDB-X. For Java, the official KX client
(`com.kx:javakdb`) is published on Maven Central under an Apache-2.0 licence.

## Decision

Depend on `com.kx:javakdb:2.2` and use `com.kx.c` for connections and queries. It provides
full serialize/deserialize support, so we don't reimplement q's type system in Java.

## Consequences

- **Positive:** battle-tested client; complete type coverage (including temporal types that
  render cleanly to strings); no protocol code to maintain; a normal Maven dependency.
- **Negative:** one more third-party dependency; unlike the C++ project, we don't own the
  protocol layer here (which is the right trade-off — this project is about the *service*,
  not the protocol).
