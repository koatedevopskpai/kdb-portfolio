# 4. Extract pure helpers into lib.q for testability

- **Status:** Accepted
- **Date:** 2026-10-01
- **Deciders:** George Kpai

## Context

The trickiest logic lived inline inside process files: the snapshot/live de-duplication
guard in the RDB, and the HDB partition-path builder. Logic embedded in a long-running
process file (that opens sockets on load) cannot be unit tested in isolation.

## Decision

Move side-effect-free logic into `lib.q` as pure functions:

- `applyUpd[lastSeq;t;seq]` — should this broadcast be applied?
- `hdbPath[hdbDir;d;t]` — the splayed partition path.

`rdb.q` and `hdb.q` load `lib.q`; `tests/test_units.q` tests the helpers directly.

## Consequences

- **Positive:** the risky logic is unit tested; it is DRY (defined once); each function has
  a single, clear responsibility. Writing `applyUpd` for an unknown table immediately
  surfaced a null-comparison bug (`seq > ::` is a type error) that was fixed with a
  conditional before it could hit production.
- **Negative:** one more file to load (negligible).
