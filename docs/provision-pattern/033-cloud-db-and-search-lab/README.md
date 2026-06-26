# 033 Cloud DB And Search Lab

Scenario: a customer 360 enrichment workflow writes the canonical profile to a
primary SQL backend, mirrors query-optimized views into document/search/graph
stores, and records a low-latency key/value projection.

This is a lab/provider example. It is part of the compile regression and is
validated by:

```bash
bash examples-vflow/runtime-smoke/cloud-db-search-lab-smoke.sh
```

Current boundary:

- PostgreSQL, MySQL, and Yugabyte share the SQLx connector family. Yugabyte is
  documented as PostgreSQL-wire compatible but kept as a separate `connector_ref`
  in examples so operators can reason about placement and credentials.
- MongoDB, Elasticsearch/OpenSearch, Neo4j, and DynamoDB require provider or
  local lab infrastructure before live behavior is claimed.
- SQLite remains the laptop-safe SQL baseline elsewhere in `examples-vflow`.

Failure semantics:

- SQL writes and document/index writes are side effects and use
  `persistence: ssot`.
- Retry requires idempotent keys: `customer_id`, `profile_version`, and
  `idempotency_key`.
- Missing provider endpoints are `SKIP` by default and fail only under strict
  mode.
