# VWFD YAML — Pack, Tier, Dispatch Markers


This file covers the three packaging + dispatch concerns that surround a workflow YAML:

1. **`pack.yaml`** — bundles connections + workflows for deployment (the user-authored deploy unit).
2. **`tier.yaml`** — operator/admin gating of capabilities, connectors, triggers (via TierSpec).
3. **Dispatch markers** — how `WasmFunction` / `NativeCode` / `Sidecar` activities find their implementations.

> **Adjacent but separate:** a newer IaC resource model (`kind: Tenant | FleetHost | Tier | Pack | Snapshot` with `apiVersion: vflow.cloud/v1` + `metadata` + `spec`) targets the same domain from an admin perspective — see [`08-iac-resources.md`](./08-iac-resources.md). In short:
> - **pack.yaml** = user-authored bundle manifest (connections + workflow file list). Consumed by pack factory at provision.
> - **Pack IaC resource** (`kind: Pack`) = admin-authored declaration that a pack is installed/available in the control plane. Consumed by PackController. Typically *references* a pack.yaml by digest.
>
> Use pack.yaml to ship a workflow bundle; use a Pack resource via `vflowctl apply -f` to register that bundle into the control plane.

---

## `pack.yaml` — deployable bundle

A pack declares a set of pre-resolved connection instances + the workflow files that use them. It's the unit of deployment for vflow.

```yaml
pack:
  id: examples/hello-db       # string; usually <org>/<name>
  version: 0.1.0              # semver
  description: "Example pack — two SQLite connections + a webhook workflow."

connections:
    kind: sqlite
    path: ":memory:"
    pool:
      max_size: 2

  - name: audit
    kind: sqlite
    path: ":memory:"

workflows:
  - bootstrap.yaml            # relative paths to workflow YAML files
  - write_hello.yaml
```

### Schema

**`pack` block** (metadata):

| Field | Type | Required | Semantics |
|---|---|---|---|
| `id` | string | yes | Pack identifier. Convention: `<org_or_scope>/<name>`. |
| `version` | string | yes | Semver. |
| `description` | string | no | Free text. |

**`connections` block** (array):

Each entry is one connection instance that workflows in this pack can reference via `connector_ref: "pack://<pack.id>/<name>"`.

| Field | Type | Required | Semantics |
|---|---|---|---|
| `name` | string | yes | Name used in `pack://` URIs. |
| `kind` | string | yes | Connector KIND — see 03-connectors.md. |
| *(connector-specific fields)* | various | — | Matches the connector's config shape. E.g. `path` for sqlite, `url` for postgres, `urls` for nats. |
| `pool` | PoolConfig | no | `{ max_size, min_idle, acquire_timeout_ms, idle_timeout_ms }` — see 03-connectors.md. |

**`workflows` block** (array of relative paths):

List of YAML files (relative to the pack root) to bundle. Each file is a full VWFD workflow — see 01-schema.md.

### Referencing pack connections from a workflow

```yaml
# Inside a workflow YAML file listed under `workflows:` in pack.yaml:
- id: insert
  activity_type: Connector
  connector_config:
    operation: raw_query
```


### Connection field reference by KIND

| KIND | Required fields | Optional fields |
|---|---|---|
| `sqlite` | `path` (e.g. `:memory:` or `/var/lib/foo.db`) | `pool.*` |
| `postgres` / `mysql` / `yugabyte` | `url` (DSN or secret ref `env://VAR` \| `secret://path`) | `pool.*` |
| `redis` | `url` | `pool.*` |
| `mongo` | `uri` | `db` (default `default`), `pool.*` |
| `cassandra` / `scylla` | `contact_points` (list), `keyspace` | `pool_id` (default 0). Use `cassandra` or `scylla` for ScyllaDB — same connector. |
| `clickhouse` | `url` (default `http://localhost:8123`) | `database` (default `default`), `username`, `password` |
| `elastic` | `url` | — |
| `neo4j` | `url` | `user` (default `neo4j`), `pass` |
| `dynamodb` | `region` | — |
| `timeseries` | `url`, `org`, `bucket`, `token` | — |
| `tikv` | `pd_endpoints` | — |
| `etcd` | `endpoints` | — |
| `nats` | `urls` | — |
| `kafka` | `brokers` | — |
| `mqtt` | `url`, `topic` | — |
| `rabbitmq` | `url` | `exchange` (default `vflow`), `queue` (default `vflow`) |
| `pulsar` | `url` | `tenant`, `namespace`, `topic` |
| `pubsub` | `project` | `topic`, `subscription` |
| `sqs` | `region` | `queue_url` |
| `http` | (none — rarely declared in pack; usually per-call config) | — |
| `s3` | `endpoint`, `access_key`, `secret_key`, `bucket` | `region` (default `us-east-1`), `path_style` |
| `gcs` | `bucket` | — |
| `azure` | `account`, `access_key` | `container` (default `default`) |
| `sidecar-connector` | `target` (name of pre-registered sidecar) | — |

See 03-connectors.md for per-connector env-variable fallbacks.

### Complete example — enterprise-sidecar pack


```yaml
pack:
  id: examples/enterprise-sidecar
  version: 0.1.0
  description: >
    Demonstrates pack-level routing to a pre-spawned sidecar via
    `kind: sidecar-connector`. Requires a sidecar named
    `acme-fraud-scorer` to be live in the host's SidecarRegistry
    before pack install.

connections:
  - name: fraud_api
    kind: sidecar-connector
    target: acme-fraud-scorer        # must match a registered sidecar

  # Dual-role example: same sidecar, different connection name.
  - name: fraud_api_alt
    kind: sidecar-connector
    target: acme-fraud-scorer

workflows:
  - score_transaction.yaml
```

A workflow inside this pack references the connection via `pack://examples/enterprise-sidecar/fraud_api`.

### Example references (runtime pack.yaml files)

| Pack | Path | Shows |
|---|---|---|
| `hello-db` | `examples-vflow/packs/hello-db/pack.yaml` | Minimal single-connection pack (sqlite `:memory:`). |
| `multi-conn` | `examples-vflow/packs/multi-conn/pack.yaml` | Two named connections + two workflows. |
| `enterprise-sidecar` | `examples-vflow/packs/enterprise-sidecar/pack.yaml` | `kind: sidecar-connector` + dual-role routing. |

---

## `tier.yaml` — capability + allow-list gating

A tier spec is the admin-level policy governing what a tenant can use. It gates connectors, triggers, sidecars, WASM modules, and compute roles.


```yaml
version: 1
kind: TierSpec
metadata:
  id: standard
  name: "Standard tier (SMB)"
  version: "1.0"
  description: "SMB-facing tier. Full connector set, moderate compute."

capabilities:
  sidecar:   { roles: [compute, connector] }
  wasm:      { roles: [compute] }
  native:    { roles: [] }                 # disabled for this tier
  multi_pack: true
  hot_pack_install: true
  workflow_versioning: true

connectors:
  database:
    allow: [sqlite, postgres, mysql, yugabyte, redis, mongo, cassandra, clickhouse]
  mq:
    allow: [nats, nats_js, nats_kv, kafka, mqtt, rabbitmq]
  protocol:
    allow: [http, grpc, websocket, sftp]
  storage:
    allow: [s3, gcs, azure]

triggers:
  allow: [webhook, cron, nats, nats_js, nats_kv, kafka, mqtt, s3_event, grpc_server, fs]

secrets:
  backends:
    allow: [env, vault, aws_secrets_manager]

sidecars:
  allow:
    - name: fraud_scorer
      roles: [compute]
      artifact:
        kind: binary
        digest: "sha256:…"
        size_mb: 45
        command: "python -m fraud_service"
      resources:
        rss_mb: 256
        cpu_millicores: 500

wasm:
  allow:
    - { name: currency_convert, memory_pages: 256 }

limits:
  max_payload_size_mb: 10
  max_concurrent_activities: 100

orchestrators:
  allow: [workflow_runtime]
```

### Schema (abbreviated)

| Block | Purpose |
|---|---|
| `version: 1` | Tier spec schema version. |
| `kind: TierSpec` | Marker — required. |
| `metadata` | `{ id, name, version, description }`. |
| `capabilities` | Per-role allow flags. `sidecar.roles`, `wasm.roles`, `native.roles` may be `[compute]` / `[connector]` / both. `multi_pack` / `hot_pack_install` / `workflow_versioning` as bool gates. |
| `connectors` | Allow-list per category (`database`, `mq`, `protocol`, `storage`). Only listed KINDs may appear in workflows. |
| `triggers` | Allow-list of trigger types. |
| `secrets.backends` | Allowed secret-resolver backends. |
| `sidecars.allow` | Per-sidecar registration with artifact digest + resource caps. |
| `wasm.allow` | Per-module registration with memory cap. |
| `limits` | Payload + concurrency caps. |
| `orchestrators.allow` | Allowed orchestrator implementations. |

### When a tier is enforced

- **At pack install time**: The tier compiler rejects pack.yaml that references a connector KIND outside the tier's allow-list.
- **At runtime**: any workflow referencing a disallowed connector/trigger fails with a tier-policy error.

### Example tier references

- `examples-vflow/tiers/standard.yaml` — SMB tier.
- `examples-vflow/tiers/starter.yaml` / `premium.yaml` / `enterprise.yaml` — other reference tiers (if present).

---

## Dispatch marker convention — `handler_lookup`

For dispatch-style activities (`WasmFunction`, `NativeCode`, `Sidecar`), the kernel routes via a single `handler_lookup` closure that resolves `"<type>.<name>"` keys. This is the pluggable boundary between VWFD activities and actual implementations.


| Activity type | Config field | Registry key | Resolves to |
|---|---|---|---|
| `WasmFunction` | `wasm_config.module_ref: my_mod` | `"wasm.my_mod"` | WASM module (loaded from .wasm file, pre-warmed pool). |
| `NativeCode` | `code_config.handler_ref: my_fn` | `"code.my_fn"` | Native Rust function registered at boot. |
| `Sidecar` | `sidecar_config.target: my_sc` | `"sidecar.my_sc"` | Sidecar process registered via `app.sidecar()` or equivalent. |

### Key implications for YAML authors

1. **No file extensions in YAML.** Don't write `.wasm` / `.native` / `.sidecar` suffixes. Just use the registered name.
2. **The name must match the registration.** If the Rust side registered `fraud_detector`, the YAML uses `handler_ref: fraud_detector`.
3. **Tier gates by name.** A tier's `sidecars.allow[].name` and `wasm.allow[].name` must include the name referenced in the workflow.

### Registration side (for reference, not YAML)

On the Rust side, handlers register into the registry at boot:

```rust
// NativeCode
code_registry.insert("fraud_detector", Box::new(fraud_detector_fn));

// WasmFunction
wasm_registry.insert("currency_convert", load_wasm("currency_convert.wasm")?);

// Sidecar
sidecar_registry.insert("fraud_scorer", spawn_sidecar(sidecar_cfg)?);
```

The VWFD YAML just references `handler_ref: fraud_detector`, `module_ref: currency_convert`, `target: fraud_scorer` — the `handler_lookup` closure maps them.

---

## VWF (provisionable) provisioning flow

For runtime-uploaded workflows (VWF, not VWFD compile-time):

```
POST /api/admin/workflow/upload
Content-Type: application/yaml
<YAML body>
```

Server auto-detects YAML via the Content-Type header. The compiler produces VWFC (binary) in memory. The `WorkflowRouter` stores the compiled VWFC + metadata. At runtime the kernel loads VWFC directly — no re-parse.

Admin-level APIs:
- `POST /api/admin/workflow/upload` — upload / replace.
- `POST /api/admin/event/fire` — inject a named event (for `EventGateway` await-mode).

---

## Tier vs Pack: responsibility split

| Concern | Pack (pack.yaml) | Tier (tier.yaml) |
|---|---|---|
| **Connection instances** | Declares them (with URL, credentials, pool). | Gates which KINDs are permitted. |
| **Workflow files** | Lists them (`workflows:` array). | (Not relevant — tier doesn't list workflows.) |
| **Sidecars** | References by name. | Registers + budgets each sidecar. |
| **WASM modules** | References by name. | Registers + caps memory. |
| **Who writes it** | Pack author / service owner. | Platform operator / admin. |
| **When applied** | Deployment time. | Install-time gate + runtime policy. |

Typical flow: platform admin publishes a `tier.yaml`; a tenant authors a `pack.yaml` + workflow YAML files; tier-compiler validates pack against tier at install; runtime enforces tier.

---

## Gotchas

- **`pack://` URI not validated at YAML parse.** If you typo the pack id or connection name, you get a runtime error when the first activity tries to resolve. Test by provisioning the pack in a dev environment.
- **Tier is not visible to the workflow author.** The YAML references a connector by KIND; whether the tenant's tier allows it is enforced elsewhere. Check the deployment target's tier before using an unusual KIND.
- **Sidecar + WASM/NativeCode registration is out-of-band.** The YAML references names; the names must be pre-registered on the Rust side. Runtime failure is "handler not found" — not a YAML schema error. Runtime artifact upload endpoints return the computed `sha256`; strict artifact policy can require a matching checksum and trusted native/plugin upload metadata.
