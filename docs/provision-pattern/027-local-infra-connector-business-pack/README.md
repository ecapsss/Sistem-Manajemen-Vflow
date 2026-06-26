# 027 Local Infra Connector Business Pack

Scenario: a return-merchandise authorization workflow receives a customer
return, reserves an idempotency lock, writes service routing config, checks a
wide-row customer backend, stores evidence, drops a warehouse manifest, and
touches analytics/audit infrastructure.

This example is intentionally local/lab-infra scoped. The workflow YAML is part
of the default compile regression. Real connector execution is handled by the
skip-aware local-infra smoke:

```bash
bash examples-vflow/runtime-smoke/local-infra-connector-business-pack-smoke.sh
```

Strict mode fails if any configured connector is missing:

```bash
VFLOW_LOCAL_INFRA_STRICT=1 \
bash examples-vflow/runtime-smoke/local-infra-connector-business-pack-smoke.sh
```

Business behavior:

- Redis provides the idempotency lock for retry-safe intake.
- Etcd stores the route/config snapshot used by downstream return handling.
- Cassandra/Scylla represents a customer/account wide-row lookup.
- S3/SeaweedFS stores the evidence bundle.
- SFTP drops a manifest for a warehouse/WMS integration.
- ClickHouse is the analytics/audit backend readiness check.
- SQLite pack write shows that user-owned packs can sit beside built-in
  connector families.

Side-effect note: operator retry is still current-version retry. Any production
version of this pattern must preserve `return_id` and `idempotency_key` across
retry.
