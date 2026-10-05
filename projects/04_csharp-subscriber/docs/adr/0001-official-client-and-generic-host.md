# 1. Use the official KX C# client inside a .NET generic host

- **Status:** Accepted
- **Date:** 2026-10-05
- **Deciders:** George Kpai

## Context

The subscriber must connect to kdb+ over IPC and **deserialize** the tables the tickerplant
broadcasts. The official KX client (`CSharpKDB`, from KxSystems/csharpkdb) is on NuGet and
targets `net8.0`. We also want standard .NET service behaviour: configuration, logging,
dependency injection and graceful shutdown.

## Decision

- Depend on `CSharpKDB` for the IPC/type mapping (including subscription reads via
  `ks`/`kAsync`).
- Host the service with `Microsoft.Extensions.Hosting`; the subscriber and the status
  reporter are `BackgroundService` implementations; settings bind from `appsettings.json`.

## Consequences

- **Positive:** official, maintained client; no protocol code to maintain in C#; idiomatic
  .NET service structure (DI, config, logging, Ctrl+C shutdown for free).
- **Negative:** extra dependencies; the client's global `c.e` encoding flag is static
  (a small quirk worked around in code).
- Contrast with project 02, where the C++ feed **hand-rolls** the protocol because no KX
  library was available — here the library exists, so we use it and focus on the service.
