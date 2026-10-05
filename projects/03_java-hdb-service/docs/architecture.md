# Architecture — hdb-service

Detailed diagrams for project 03. See [`../README.md`](../README.md) and
[`adr/`](adr/) for the decisions.

## Components

```mermaid
flowchart TB
    subgraph Web["Web layer"]
        CTRL["HdbController\n@RestController"]
        EXH["ApiExceptionHandler\n@RestControllerAdvice"]
    end
    subgraph Query["Query layer"]
        QSVC["KdbQueryService\nqSQL builders + param safety"]
        QV["QValue\nq -> JSON-friendly Java"]
    end
    subgraph Ipc["kdb+ IPC layer"]
        POOL["KdbConnectionPool\nborrow / return / self-heal"]
        CONN["KdbConnection\ncom.kx.c wrapper"]
    end
    CFG["KdbProperties\nkdb.* config"]
    KDB[("kdb+ HDB :5012")]

    CTRL --> QSVC --> POOL --> CONN
    QSVC --> QV
    CTRL -.-> EXH
    CFG -.-> POOL
    CONN <-->|"kdb+ IPC"| KDB
```

## Request flow

```mermaid
sequenceDiagram
    autonumber
    participant C as HTTP client
    participant Ctrl as HdbController
    participant S as KdbQueryService
    participant P as KdbConnectionPool
    participant K as kdb+ HDB

    C->>Ctrl: GET /api/stats
    Ctrl->>S: allStats()
    S->>P: withConnection(c -> c.k(qSQL))
    P->>P: borrow (validate, or open if none)
    P->>K: sync query ("0!select ... by sym from trade")
    K-->>P: q result (Flip)
    P-->>S: Object
    P->>P: return connection to pool
    S->>S: QValue.toJson(Flip) -> List<Map>
    S-->>Ctrl: rows
    Ctrl-->>C: 200 application/json
```

## Error mapping

```mermaid
flowchart LR
    A["IllegalArgumentException\n(bad symbol)"] --> B["400 bad request"]
    C["KdbException\n(kdb down / q error)"] --> D["503 kdb+ unavailable"]
    E["q error (KException)"] --> C
```

## Dependencies

- `spring-boot-starter-web` — embedded Tomcat, REST, Jackson
- `spring-boot-starter-validation`
- `com.kx:javakdb:2.2` — the official KX Java client for kdb+ IPC (Apache-2.0)
- `spring-boot-starter-test` — JUnit 5, MockMvc, Mockito, AssertJ
