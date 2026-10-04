# 2. Write the feed handler in C++ using the raw kdb+ IPC protocol

- **Status:** Accepted
- **Date:** 2026-09-28
- **Deciders:** George Kpai

## Context

On a trading floor the process that connects to an exchange is written in C++ (or Java) for
latency and control over bytes. It parses the exchange's binary protocol and pushes
normalised tables into the q tickerplant. We needed a C++ feed handler, but the KDB-X
distribution does not ship the classic C API library, and the KDB-X binary does not export
the `k()` symbols.

## Decision

Implement the **kdb+ IPC wire protocol directly** in C++ (raw TCP + little-endian
serialization) rather than depend on a KX library. The serialization lives in a header-only
library (`qipc.hpp`) so it can be unit tested. Correctness is verified **byte-for-byte**
against q's own `-8!` output.

## Consequences

- **Positive:** zero external dependencies; demonstrates protocol-level understanding;
  portable; testable without a network.
- **Negative:** we own the serialization and must track protocol changes; only the
  outbound/async subset is implemented (sufficient for a feed handler).
- Verified: the unit test compares our bytes to q's `-8!` for a fixed table and passes.
