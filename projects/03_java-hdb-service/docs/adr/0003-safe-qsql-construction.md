# 3. Construct qSQL safely (validate symbols, clamp limits)

- **Status:** Accepted
- **Date:** 2026-10-05
- **Deciders:** George Kpai

## Context

qSQL is sent to kdb+ as a **string** over IPC; q has no bind variables / prepared
statements. Interpolating user input directly into a query string is an injection risk
(e.g. a symbol containing a backtick or `;`). User-supplied row limits could also request
unbounded data.

## Decision

- Validate any symbol interpolated into a query against `^[A-Za-z0-9._-]{1,32}$` and reject
  otherwise (`IllegalArgumentException` → HTTP 400).
- Clamp row limits to `[1, 1000]`.
- Keep all qSQL construction inside `KdbQueryService` (one place to audit).

## Consequences

- **Positive:** the injection surface is closed for the values that reach q; API abuse is
  bounded; the rules are centralised and unit-tested via the web layer.
- **Negative:** some exotic-but-legal kdb+ symbols (with spaces, etc.) are rejected —
  acceptable for a market-data service whose symbols are tickers.
