# VWFD YAML — Connector Catalog


Referenced from a Connector activity via `connector_config.connector_ref`. Two forms:
- **Bare KIND**: e.g. `connector_ref: postgres` (uses default env-configured connection).
- **Pack-scoped**: `connector_ref: "pack://<pack_id>/<conn_name>"` (resolves to a named connection declared in that pack's `pack.yaml`).

---

## KIND naming

vflow **does not enforce** a dotted-namespace. Bare KINDs are flat strings: `http`, `postgres`, `nats`, `redis`.
---

## Connector kinds and operations

The table below summarizes connector kinds and common operations.

| KIND | Registration | Operations |
|---|---|---|
| `http` | always | `GET`, `POST`, `PUT`, `DELETE`, `PATCH` |
| `sqlite` / `postgres` / `mysql` / `yugabyte` | env or pack factory | `find_one`, `find_many`, `insert`, `update`, `delete`, `count`, `execute`, `raw_query`, `batch_raw_query`, `health_check` |
| `redis` | feature/env | `get`, `set`, `set_ex`, `del`, `exists`, `incr`, `incr_by`, `decr`, `expire`, `ttl`, `hset`, `hget`, `hdel`, `hgetall` |
| `mongo` | feature/env | `find_one`, `find_many`, `insert_one`, `update_one`, `delete_one`, `count` |
| `cassandra` / `scylla` | feature/env or pack factory | `execute`, `insert`, `select`, `raw_query` |
| `clickhouse` | feature/env or pack factory | `query`, `execute`, `insert`, `ping` |
| `elastic` | feature/env | `index`, `search`, `get`, `delete` |
| `neo4j` | feature/env | `query` |
| `dynamodb` | feature/env | `put_item`, `get_item`, `delete_item`, `scan`, `query` |
| `timeseries` | feature/env | `write`, `query`, `ping` |
| `tikv` | feature/pack factory | `get`, `put`, `delete`, `scan`, `cas` |
| `etcd` | feature/pack factory | `get`, `get_prefix`, `put`, `delete`, `delete_prefix`, `lease_grant`, `lease_keep_alive`, `lease_revoke`, `cas` |
| `nats` | feature/env or pack factory | `publish`, `request`, `reply`, `js_publish`, `js_stream_create`, `js_stream_info`, `kv_put`, `kv_get`, `kv_delete`, `kv_keys` |
| `kafka` | feature/env | `publish`, `health_check` |
| `mqtt` | feature/env | `publish`, `subscribe` |
| `rabbitmq` | feature/env | `publish`, `consume`, `ack` |
| `pulsar` | feature/env | `publish` |
| `pubsub` | feature/env | `publish` |
| `sqs` | feature/env | `send`, `receive`, `delete` |
| `s3` / `seaweedfs` | feature/env or pack factory | `put_object`, `get_object`, `delete_object`, `list_objects`, `head_object` |
| `gcs` | feature/env | `upload`, `download`, `delete`, `list` |
| `azure` | feature/env | `upload_blob`, `download_blob`, `delete_blob`, `list_blobs` |
| `sftp` | feature/env | `upload`, `download`, `list`, `delete` |
| `grpc` | feature, stateless | `health_check`, `call`, `unary` |
| `websocket` | feature/env | `broadcast`, `broadcast_room` |
| `graphql` | HTTP-backed pattern | use `http` with GraphQL payload; dedicated adapter is pack/provider-specific |
| `soap` | feature/env | `call_action` |
| `modbus` | feature/env | `read_coils`, `read_registers`, `write_coil`, `write_register` |
| `opcua` | feature/env | `read_node`, `write_node` |
| `protobuf` | feature, stateless | `encode`, `decode` |
| `msgpack` | feature, stateless | `encode`, `decode` |
| `iso8583` | feature, stateless | `encode`, `decode` |

---

## Pool config (all SQL + network connectors)

Each connection in `pack.yaml` can tune its connection pool:

```yaml
connections:
    kind: postgres
    url: "postgresql://..."
    pool:
      max_size: 50
      min_idle: 5
      acquire_timeout_ms: 5000
      idle_timeout_ms: 300000
```


---

## Database connectors

### `sqlite` — SQL (sqlx)

| Config | Default | Notes |
|---|---|---|
| `path` | — | `:memory:` or file path. Env fallback: `VFLOW_SQLITE_PATH`. |

Memory-backed DBs auto-pin to `max_size: 1`. Ops: `find_one`, `find_many`, `insert`, `update`, `delete`, `count`, `raw_query`, `execute`.

### `postgres` / `mysql` — SQL (sqlx)

| Config | Notes |
|---|---|
| `url` | DSN. May be a secret reference: `env://VAR`, `secret://path`. Env fallback: `VFLOW_POSTGRES_URL` / `VFLOW_MYSQL_URL`. |

Same op set as sqlite.

### `yugabyte` — SQL (Postgres-wire)

| Config | Default | Notes |
|---|---|---|
| `url` | — | Postgres-wire protocol, default port **5433**. Warns if port 5432 detected (common copy-paste mistake). |

Same op set.
### `redis` — cache / KV

| Config | Env fallback |
|---|---|
| `url` | `VFLOW_REDIS_URL` |

Ops (extended 2026-04-26):
- **String/KV**: `get`, `set`, `set_ex`, `del`, `exists`
- **Counters**: `incr`, `incr_by`, `decr` (atomic, returns new value)
- **TTL**: `expire`, `ttl`
- **Hash**: `hset`, `hget`, `hdel`, `hgetall`

Counter / TTL / hash op errors are surfaced as `VilDbError::execute("redis", ...)` (was silent-swallow). String/KV ops follow Redis driver semantics (get returns Option<String>; set is fire-and-forget).

Input shape: `{ key, value?, ttl?, field?, delta? }`. Output shape varies per op (key always echoed; counter ops return `value`; hash ops return `field`; ttl returns `Option<i64>` — `null` for no-TTL or missing key).


### `mongo` — document store

| Config | Default | Env fallback |
|---|---|---|
| `uri` | — | `VFLOW_MONGO_URI` |
| `db` | `default` | `VFLOW_MONGO_DB` |

Ops: `insert`, `find_one`, `find_many`, `update`, `delete`.

### `cassandra` — wide-column (Cassandra / ScyllaDB)

| Config | Env fallback |
|---|---|
| `host` | `VFLOW_CASSANDRA_HOST` |
| `keyspace` | `VFLOW_CASSANDRA_KEYSPACE` |

Ops (extended 2026-04-26):
- `execute`: CQL fire-and-forget. Input `{ query, params? }`, output `{ rows: <count> }`.
- `insert`: convenience wrapper. Input `{ entity, columns: [...], params: [...] }`.
- `select`: SELECT with rows-as-JSON. Input `{ query, params? }`, output `{ rows: [{col: val, ...}], count }`. Used by audit-svc query API.
- `raw_query`: vil_query-compiled path. Input `{ sql|query, params: [JSON values], _vil_query: true }`. Sniffs SELECT prefix → routes to `query_json` (rows-as-JSON) vs `query` (rows_affected). Use with `dialect: cassandra` vil_query workflows.

`?` placeholder substitution in `query` field; `cql_quote` does SQL-92 single-quote doubling for injection safety. Errors wrapped as `VilDbError::execute("scylla", ...)` via the lossless `From<VilDbError> for ConnectorError` impl.
### `clickhouse` — OLAP analytics

| Config | Default | Env fallback |
|---|---|---|
| `url` | `http://localhost:8123` | `VFLOW_CLICKHOUSE_URL` |
| `database` | `default` | `VFLOW_CLICKHOUSE_DB` |
| `username` | — | `VFLOW_CLICKHOUSE_USER` |
| `password` | — | `VFLOW_CLICKHOUSE_PASS` |

Ops (rewritten 2026-04-26 — closes typed-fetch-only blocker):
- `query`: SELECT returning rows-as-JSON. Input `{ sql|query }`, output `{ rows: [...], count }`. Implementation: wraps user SELECT as `SELECT toJSONString(t) AS j FROM (<user_sql>) AS t`, parses each `j` as JSON. Constraint: user SQL must NOT contain a `FORMAT` clause (we wrap it).
- `execute`: DDL / fire-and-forget DML. Input `{ sql }`, output `{ executed: true }`. Use for `CREATE/DROP/ALTER`, `INSERT VALUES (...)`, `RENAME`, `TRUNCATE`.
- `insert`: batch JSON ingest via `FORMAT JSONEachRow`. Input `{ table, rows: [<json>, ...] }`, output `{ inserted, table }`. Uses `input_format_skip_unknown_fields=1` so workflow rows can have extra keys without rejection. Low-volume path; high-throughput typed ingest stays at code level.
- `ping`: `SELECT 1` health check. Input `{}`, output `{ healthy: true }`.

vil_query DSL extension: **`dialect: clickhouse`** supported with ClickHouse-specific methods `.final_clause()`, `.sample()`, `.array_join()`, `.limit_by(n, cols)` — see `05-expressions.md`. Useful for analytics workloads such as audit logs, observability metrics, and traffic aggregation. ### `elastic` — search

| Config | Env fallback |
|---|---|
| `url` | `VFLOW_ELASTIC_URL` |

Ops: `index`, `search`, `bulk`. Works with Elasticsearch / OpenSearch endpoints.

### `neo4j` — graph

| Config | Default | Env fallback |
|---|---|---|
| `url` | — | `VFLOW_NEO4J_URL` |
| `user` | `neo4j` | `VFLOW_NEO4J_USER` |
| `pass` | — | `VFLOW_NEO4J_PASS` |

Ops: `run`, `query`.

### `dynamodb` — AWS NoSQL

| Config | Env fallback |
|---|---|
| `region` | `VFLOW_DYNAMODB_REGION` |

Ops: `get_item`, `put_item`, `delete_item`, `scan`, `query`.

### `timeseries` — InfluxDB v2

| Config | Env fallback |
|---|---|
| `url` | `VFLOW_TIMESERIES_URL` |
| `org` | `VFLOW_TIMESERIES_ORG` |
| `bucket` | `VFLOW_TIMESERIES_BUCKET` |
| `token` | `VFLOW_TIMESERIES_TOKEN` |

Ops (extended 2026-04-26 — closes FluxRecord rows-blocker):
- `write`: insert one DataPoint. Input `{ measurement, tags?, fields, timestamp? }`, output `{ written: true, measurement }`. Field type inference: number→f64/i64, bool→bool, string→string.
- `query`: Flux query returning rows-as-JSON. Input `{ query }`, output `{ rows: [{col: val}], count }`. Closes prior limitation where the connector returned only `{row_count, query}` (FluxRecord wasn't Serialize). Now uses `query_json` which maps each `FluxRecord.values` → JSON object via `flux_record_to_json` (covers String/Bool/Long/UnsignedLong/Double/TimeRFC/Duration/Base64Binary→base64 + Unknown→null).
- `ping`: `/health` endpoint check. Output `{ healthy: true }`.


### `tikv` — distributed KV

| Config | Notes |
|---|---|
| `pd_endpoints` | PD server list (comma-separated). |

Ops: `get`, `put`, `delete`, `scan`, `cas`. JSON I/O with UTF-8 strings. . Feature-gated: `connector-tikv`.

### `etcd` — distributed KV

| Config | Notes |
|---|---|
| `endpoints` | etcd server URLs (comma-separated). |

Ops: `get`, `put`, `delete`, `txn`. Feature-gated: `connector-etcd`.

---

## Message-queue connectors

### `nats` — core pub/sub + JetStream + KV

| Config | Env fallback |
|---|---|
| `urls` | `VFLOW_NATS_URL` |

Ops:
- Core pub/sub: `publish`, `request`, `reply`
- JetStream: `js_publish`, `js_stream_create`, `js_stream_info`
- KV: `kv_put`, `kv_get`, `kv_delete`, `kv_keys`

Supports header injection.
### `kafka`

| Config | Env fallback |
|---|---|
| `brokers` | `VFLOW_KAFKA_BROKERS` |

Ops: `produce`, `consume_group`.

### `mqtt`

| Config | Env fallback |
|---|---|
| `url` | `VFLOW_MQTT_URL` |
| `topic` | — |

Ops: `publish`, `subscribe`.

### `rabbitmq` — AMQP

| Config | Default | Env fallback |
|---|---|---|
| `url` | — | `VFLOW_RABBITMQ_URL` |
| `exchange` | `vflow` | `VFLOW_RABBITMQ_EXCHANGE` |
| `queue` | `vflow` | `VFLOW_RABBITMQ_QUEUE` |

Ops: `publish`, `consume`.

### `pulsar`

| Config | Default | Env fallback |
|---|---|---|
| `url` | — | `VFLOW_PULSAR_URL` |
| `tenant` | `public` | `VFLOW_PULSAR_TENANT` |
| `namespace` | `default` | `VFLOW_PULSAR_NAMESPACE` |
| `topic` | `vflow` | `VFLOW_PULSAR_TOPIC` |

Ops: `produce`, `consume`.

### `pubsub` — GCP

| Config | Default | Env fallback |
|---|---|---|
| `project` | — | `VFLOW_PUBSUB_PROJECT` |
| `topic` | `vflow` | `VFLOW_PUBSUB_TOPIC` |
| `subscription` | `vflow-sub` | `VFLOW_PUBSUB_SUBSCRIPTION` |

Ops: `publish`, `pull`.

### `sqs` — AWS SQS

| Config | Env fallback |
|---|---|
| `region` | `VFLOW_SQS_REGION` |
| `queue_url` | `VFLOW_SQS_QUEUE_URL` |

Ops: `send_message`, `receive_message`, `delete_message`.

---

## HTTP + protocol connectors

### `http` — HTTP client + SSE

Always registered; the workhorse.

| Config | Type | Notes |
|---|---|---|
| `url` | string | Target URL. |
| `method` | string | `GET` \| `POST` \| `PUT` \| `DELETE` \| `PATCH`. |
| `headers` | object | Key/value headers. |
| `body` | any | JSON body. |
| `dialect` | string | SSE dialect: `openai` \| `anthropic` \| `ollama` \| `cohere` \| `gemini` \| `standard`. |
| `format` | string | `sse` \| `ndjson` \| `raw`. |
| `json_tap` | string | JSONPath extracted from each chunk (e.g. `"choices[0].delta.content"`). |
| `done_marker` | string | Literal marker signalling stream done (e.g. `[DONE]`). |
| `done_event` | string | SSE event name signalling done (e.g. `message_stop`). |
| `done_json_field` | object | `{field, value}` — done when this field/value combo appears. |
| `bearer_token` | string | Authorization: Bearer. |
| `anthropic_key` | string | `x-api-key` header. |
| `api_key_param` | string | URL query param name for API key. |
| `queue_capacity` | usize | Internal SSE chunk buffer. |


Ops: `GET`, `POST`, `PUT`, `DELETE`, `PATCH` (pick via `method`).

Auth shortcut notes:

- On webhook fastpath, `bearer_token` accepts literal tokens, `env://NAME`,
  and `${secret.NAME}` placeholders. It is applied to both non-stream HTTP
  calls and SSE stream calls.
- On standard kernel execution, map `headers.Authorization` explicitly unless
  the specific connector path you are using documents `bearer_token`
  expansion.
- If an input mapping supplies `headers.Authorization`, that explicit header
  is kept and `bearer_token` does not overwrite it.
- For fastpath JSON HTTP calls, read the connector output as the parsed
  upstream body shape. Example: if the upstream returns
  `{"success":true,"data":[...]}`, read `channels_response.data`; do not
  assume a wrapper like `channels_response.body` unless the specific connector
  operation documents one.

### `grpc` (alias `vastar.grpc`) — gRPC client

Generic descriptor-backed gRPC unary client. Operation `call`/`unary` for typed RPC, `health_check` for `grpc.health.v1.Health/Check`.

| Config | Notes |
|---|---|
| `endpoint` | URL form: `http://host:port`. |
| `service` | Fully-qualified service name (e.g. `examples.Gateway`). May appear in `connector_config` or per-call via `input_mappings`. |
| `method` | Method name (e.g. `Passthrough`). |
| `descriptor_set_b64` | Base64-encoded protobuf `FileDescriptorSet` covering the request + response message types. Generate with `protoc --include_imports --descriptor_set_out=...`. **Cached process-globally by content hash** — first call decodes, subsequent calls are cheap Arc clones. |
| `timeout_ms` | Per-call timeout. Default 30000. |
| `raw_request: true` | **Zero-copy mode** — the connector receives a byte payload directly via the `request` mapping when sourced with `language: bytes_ref`. Skips `json_to_dynamic_message` + `encode_to_vec`. Use when the payload is already a valid wire-encoded message of the request type (e.g. forwarding `trigger_body` to an upstream of the same proto type). |
| `raw_response: true` | **Zero-copy response** — the connector returns the upstream's raw proto wire bytes as `ConnectorOutput.data` and tags `metadata.response_format: "raw_proto_bytes"`. Fastpath dispatch mirrors the bytes into the variable's handle slot, so EndTrigger `bytes_ref` reads them with no JSON parse. |

**Channel pool baseline:** the connector maintains a process-global `Mutex<HashMap<endpoint, tonic::Channel>>` keyed by URL. tonic Channel HTTP/2-multiplexes streams over one TCP connection per endpoint. TCP_NODELAY is mandatory and always-on (cures the 40ms bimodal histogram from Nagle + delayed-ACK on Linux loopback).

**Plain forwarder example** (064, zero proto/JSON roundtrip):
```yaml
- id: forward
  activity_type: Connector
  connector_config:
    connector_ref: vastar.grpc
    operation: call
    timeout_ms: 5000
  input_mappings:
    - target: endpoint
      source: { language: literal, source: "http://127.0.0.1:50071" }
    - target: descriptor_set_b64
      source: { language: literal, source: "<base64 FileDescriptorSet>" }
    - target: service
      source: { language: literal, source: "examples.Gateway" }
    - target: method
      source: { language: literal, source: "Passthrough" }
    - target: request
      source: { language: bytes_ref, source: "trigger_body" }
    - target: raw_response
      source: { language: literal, source: "true" }
  output_variable: upstream_response
```

**Connector trait API**: gRPC connector overrides `Connector::execute_with_request_bytes`. Other connectors that don't override fall through to the default JSON-only path automatically; no breakage.

**Fastpath dispatch behavior:**
- **Response-path Connector** (reachable from Trigger without crossing a detached edge) — connector awaits inline; decoded response feeds the next node. Lifted from the historical "detached-only" restriction on 2026-05-03.
- **Detached-branch Connector** — fire-and-forget tokio::spawn; output_var gets `{"status": "queued"}` placeholder.

Feature-gated: `connector-grpc` (default-on).

### `websocket`

| Config | Notes |
|---|---|
| `url` | `ws://` or `wss://`. |

Ops: `broadcast`, `broadcast_room`. Feature-gated: `connector-websocket`.

### `graphql`

The portable path is the `http` connector with a GraphQL query or mutation in
the request body. A dedicated GraphQL adapter may be installed by a pack, but it
should be treated as provider-specific rather than the default runtime contract.

| Config | Notes |
|---|---|
| `endpoint` | HTTP URL. |
| `query` | GraphQL query or mutation string. |

Common ops when a dedicated adapter is installed: `query`, `mutation`.

### `sftp`

| Config | Env fallback |
|---|---|
| `host` | `VFLOW_SFTP_HOST` |
| `user` | `VFLOW_SFTP_USER` |
| `pass` | `VFLOW_SFTP_PASS` |

Ops: `upload`, `download`, `delete`, `list`.

---

## Storage connectors

### `s3` — AWS S3 (any S3-compatible)

| Config | Default | Env fallback |
|---|---|---|
| `endpoint` | — | `VFLOW_S3_ENDPOINT` |
| `region` | `us-east-1` | `VFLOW_S3_REGION` |
| `access_key` | — | `VFLOW_S3_ACCESS_KEY` |
| `secret_key` | — | `VFLOW_S3_SECRET_KEY` |
| `bucket` | — | `VFLOW_S3_BUCKET` |
| `path_style` | — | `VFLOW_S3_PATH_STYLE` (true/false) |

Ops: `get_object`, `put_object`, `delete_object`, `list_objects`.

### `gcs` — Google Cloud Storage

| Config | Env fallback |
|---|---|
| `bucket` | `VFLOW_GCS_BUCKET` |

Ops: `upload`, `download`, `delete`, `list`.

### `azure` — Azure Blob Storage

| Config | Default | Env fallback |
|---|---|---|
| `account` | — | `VFLOW_AZURE_ACCOUNT` |
| `access_key` | — | `VFLOW_AZURE_KEY` |
| `container` | `default` | `VFLOW_AZURE_CONTAINER` |

Ops: `upload_blob`, `download_blob`, `delete_blob`, `list_blobs`.

---

## Codec + protocol connectors (feature-gated)

| KIND | Registration | Operations |
|---|---|---|
| `protobuf` | `schema` (proto text) | `encode`, `decode` |
| `msgpack` | (stateless) | `encode`, `decode` |
| `iso8583` | `message_type` | `encode`, `decode` |
| `modbus` | `host`, `port`, `slave_id` | `read_coils`, `read_registers`, `write_coil`, `write_register` |
| `opcua` | `endpoint_url` | `read_node`, `write_node` |
| `soap` | `endpoint` | `call_action` |

---

## `sidecar-connector` — custom IPC

Routes through a pre-spawned sidecar process (UDS / SHM).

| Config | Notes |
|---|---|
| `target` | Sidecar name — must be registered via `app.sidecar()` or similar. |

. One sidecar can back multiple connections.

---

## Usage in workflow YAML — representative examples

**Bare KIND (env-configured) — HTTP POST:**
```yaml
- id: call
  activity_type: Connector
  connector_config:
    connector_ref: vastar.http
    operation: post
    timeout_ms: 5000
  input_mappings:
    - target: url
      source: { language: literal, source: "https://api.example.com/v1/users" }
    - target: body
      source: { language: vil-expr, source: '{ "email": trigger_payload.body.email }' }
  output_variable: response
```

**Pack-scoped — SQLite raw query:**
```yaml
- id: insert
  activity_type: Connector
  connector_config:
    operation: raw_query
  input_mappings:
    - target: sql
      source: { language: literal, source: "INSERT INTO hello (msg, at) VALUES ($1, $2)" }
    - target: params
      source: { language: v-cel, source: '[msg, now_ts]' }
  output_variable: ins
```

**NATS JetStream publish:**
```yaml
- id: emit
  activity_type: Connector
  connector_config:
    connector_ref: nats
    operation: js_publish
  input_mappings:
    - target: subject
      source: { language: literal, source: "orders.new" }
    - target: payload
      source: { language: spv1, source: "$.order" }
```

**Streaming LLM (OpenAI dialect):**
```yaml
- id: llm
  activity_type: Connector
  connector_config:
    connector_ref: vastar.http
    operation: post
    streaming: true
    format: sse
    dialect: openai
    json_tap: "choices[0].delta.content"
    bearer_token: "env://OPENAI_API_KEY"
    timeout_ms: 30000
  input_mappings:
    - target: url
      source: { language: literal, source: "https://api.openai.com/v1/chat/completions" }
    - target: body
      source: { language: vil-expr, source: '{ "model": "gpt-4", "stream": true, "messages": trigger_payload.body.messages }' }
  output_variable: chunks
```

See 07-gallery.md for file references.
