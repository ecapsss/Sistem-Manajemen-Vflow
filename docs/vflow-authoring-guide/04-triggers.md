# VWFD YAML — Trigger Catalog

A Trigger activity binds an external event to the workflow. `activity_type: Trigger` + `trigger_config.trigger_type: <kind>` picks the source. Most triggers need a paired `EndTrigger` activity for the response leg.

Webhook triggers are handled by HTTP ingress. Other trigger kinds can be declared directly in workflow YAML or through pack manifests.

## Trigger Kinds

| Kind | Use |
|---|---|
| `webhook` | HTTP request ingress. |
| `cron` | Time-based schedule. |
| `kafka` | Kafka topic event. |
| `mqtt` | MQTT message. |
| `s3_event` | Object storage event. |
| `sftp` | File arrival or file polling event. |
| `cdc` | Database change event. |
| `db_poll` | Periodic database polling trigger. |
| `fs` | Local or mounted file-system event. |
| `grpc` / `grpc_server` | gRPC unary endpoint. |
| `grpc_stream` | gRPC stream endpoint. |
| `iot` | IoT device event. |
| `evm` | Blockchain event. |
| `email` | Email delivery or mailbox event. |
| `nats` | NATS subject event. |
| `nats_js` | NATS JetStream event. |
| `nats_kv` | NATS KV event. |

---

## `webhook` — HTTP ingress

Default ingress path. Paired with `EndTrigger` for response.

| Config field | Type | Notes |
|---|---|---|
| `path` | string | URL path (e.g. `/api/users`). |
| `method` | string | `GET` \| `POST` \| `PUT` \| `DELETE` \| `PATCH`. Default `POST`. |
| `auth_type` | string | Optional auth hint. |
| `runtime_mode` | string | `standard` (default) \| `fastpath`. See **Webhook fastpath** below. |
| `response_mode` | string | `buffered` (default) \| `streaming`. Legacy alias for `response_framing`. |
| `response_framing` | string | `length_prefixed` \| `chunked`. |

**Standard stub:**
```yaml
- id: trig
  activity_type: Trigger
  trigger_config:
    trigger_type: webhook
    webhook_config: { path: /api/users, method: POST }
    response_mode: buffered
    end_activity: respond
  output_variable: trigger_payload
```

### Webhook fastpath

Set `runtime_mode: fastpath` to take the optimized synchronous response path. Use for stateless request/response workloads such as API gateway shaping, V-CEL transforms, V-Rule scoring, V-Starlark compute, or AI-gateway streaming where minimum response latency matters more than full kernel state-machine semantics.

**What changes on fastpath:**
- The hyper request handler awaits the inline executor directly — no executor-pool mpsc hop, no tokio task spawn, no scheduler wakeup between request decode and response emit.
- Allowed activity kinds: `Trigger`, `Transform`, `Expression`, `VRule`, `Compute`, `Connector`, `EndTrigger`, plus control-flow nodes (`Start`, `End`, `Noop`, `Control`, `Parallel`, `Join`, `Exclusive`, `Inclusive`).
- Detached edges still work (see `userguide/01-schema.md` "Detached edges"). Their sub-graph runs AFTER the response is emitted; Connector activities on detached branches dispatch fire-and-forget.
- Connector on the response path is also supported (lifted 2026-05-03 from "detached-only" — `await_response: true` auto-detected from graph topology, see `userguide/02-activities.md` Connector section).
- `runtime_mode` is declared inside each Trigger's `trigger_config`. Do not put it only in `spec.runtime`; the route planner reads the Trigger field.
- Body access: legacy `$.trigger_payload.body.*` still works. Byte-first convention `trigger_body` is also exposed when `webhook_config.body_schema` is set or the workflow uses `bytes_ref` source — same as gRPC fastpath.
- HMAC/webhook signature access: use `trigger_payload.raw_body` for the exact request body. Fastpath materializes it only when an expression references it.
- Headers are exposed as original, lowercase, and snake_case aliases. Prefer `trigger_payload.headers.x_callback_signature` for `X-Callback-Signature` rather than bracket indexing a hyphenated name.
- Response shape: converge response branches into the single `EndTrigger` named by `trigger_config.end_activity`. `EndTrigger` emits a client response; detached branches may still continue background work.
- Audit: `metadata.audit_log` and per-activity audit are honored on fastpath; emitter is fire-and-forget so it doesn't block the response.

**Fastpath stub:**
```yaml
- id: trigger
  activity_type: Trigger
  trigger_config:
    trigger_type: webhook
    runtime_mode: fastpath
    webhook_config: { path: /bench/fastpath/vrule-risk, method: POST }
    response_framing: length_prefixed
    end_activity: respond
  output_variable: trigger_payload
```

### Examples

- `examples-vflow/provision-pattern/006-full-vcel-lambda-fastpath/` — fastpath full V-CEL (apple-to-apple with `006-full-vcel-lambda` standard).
- `examples-vflow/provision-pattern/047-fastpath-vrule-risk-scoring/` — fastpath V-Rule risk decision (canonical fastpath benchmark fixture).
- `examples-vflow/provision-pattern/048-fastpath-vstarlark-pricing/` + `048-fastpath-vstarlark-risk-scoring/` — fastpath V-Starlark Compute.
- `examples-vflow/provision-pattern/049-standard-vrule-risk-scoring/` — standard-runtime variant of 047 (apple-to-apple).
- `examples-vflow/provision-pattern/050-fastpath-vrule-risk-scoring-detached/` ↔ `051-...-blocking/` — detached-vs-blocking on fastpath.
- `examples-vflow/provision-pattern/056-fastpath-vrule-risk-scoring-audit-log/` — fastpath + request-level `metadata.audit_log`.
- `examples-vflow/provision-pattern/057-fastpath-ai-gateway-stream-audit-summary/` — fastpath AI gateway stream + per-request audit summary.

For the underlying runtime-mode design (durability orthogonal, streaming as connector setting), see `userguide/00-overview.md` "Runtime Modes".

---

## `cron` — time-based schedule

| Config field | Type | Notes |
|---|---|---|
| `schedule` | string | Interval (parsed as ms or a cron expression). E.g. `"2s"`, `"5000"`, `"0 */6 * * *"`. |
| `path` | string | Internal route. |

Emits variables: `_trigger: "cron"`, `_schedule`, `_fired_at` (RFC3339).



**Stub:**
```yaml
- id: tick
  activity_type: Trigger
  trigger_config:
    trigger_type: cron
    schedule: "2s"
    path: /internal/cron/tick
  output_variable: tick
```

Reference: `examples-vflow/vwfd-compile-time-pattern/cron-smoke/workflows/cron-tick.yaml`.

---

## `kafka` — consumer-group based

| Config field | Type | Notes |
|---|---|---|
| `brokers` | string | Comma-separated broker addrs. |
| `group_id` | string | Consumer group id. |
| `topics` | [string] | Subscribed topics. |
| `path` | string | Internal route. |

---

## `mqtt` — IoT pub/sub

| Config field | Notes |
|---|---|
| `url` | MQTT broker URL. |
| `topic` | Subscribed topic. |
| `route` | Internal workflow route. |

---

## `s3_event` — S3 bucket notification (via SQS)

| Config field | Notes |
|---|---|
| `bucket` | S3 bucket name. |
| `prefix` | Optional prefix filter. |
| `route` | Internal workflow route. |

Polls the paired SQS queue. Emits `bucket`, `key`, `size`, `event`.

---

## `sftp` — file arrival

| Config field | Notes |
|---|---|
| `host` | SFTP host. |
| `watch_dir` | Remote directory to watch. |
| `route` | Internal workflow route. |

---

## `cdc` — Change Data Capture

| Config field | Notes |
|---|---|
| `database_url` | Source database DSN. |
| `table` | Table to watch. |
| `path` | Internal route. |

---

## `db_poll` — periodic SQL

| Config field | Notes |
|---|---|
| `database_url` | DB DSN. |
| `query` | SQL executed each tick. |
| `interval_ms` | Tick interval. |
| `path` | Internal route. |

Fires once per row returned.

---

## `fs` — filesystem watch

| Config field | Notes |
|---|---|
| `watch_path` | Path to watch (file or dir). |
| `path` | Internal route. |

Emits on create / modify / delete.

---

## `grpc_stream` — outbound gRPC stream

| Config field | Notes |
|---|---|
| `endpoint` | `host:port`. |
| `service` | gRPC service name. |
| `method` | Method. |
| `path` | Internal route. |

---

## `grpc` (alias: `grpc_server`) — inbound gRPC server

Both `trigger_type: grpc` and `trigger_type: grpc_server` are accepted. Enable the listener via `$VFLOW_STATE_DIR/grpc_server.json`:

```json
{"enabled": true, "port": 50071}
```

| Config field | Notes |
|---|---|
| `grpc.service` | Fully-qualified service name (e.g. `examples.RiskScoring`). |
| `grpc.method` | Method (e.g. `ScoreRisk`). |
| `grpc.body_schema` | Proto message FQN used for typed binding (e.g. `examples.RiskRequest`). Must be registered via `POST /api/admin/proto/upload`. |
| `runtime_mode` | `standard` (default) \| `fastpath`. Fastpath gRPC is the typed proto-native data path with zero JSON ser/deser. See **gRPC fastpath** below. |
| `response_framing` | `length_prefixed` (default for gRPC) \| `chunked`. |
| `end_activity` | ID of the EndTrigger. |
| `path` | Internal synthesised route `/grpc/<service>/<method>`. |

**Standard (typed binding):**

```yaml
- id: trigger
  activity_type: Trigger
  trigger_config:
    trigger_type: grpc
    grpc:
      service: "examples.RiskScoring"
      method: "ScoreRisk"
      body_schema: "examples.RiskRequest"
    response_framing: length_prefixed
    end_activity: respond
  output_variable: trigger_payload
```

With `body_schema` set, downstream V-CEL expressions read typed fields from `trigger_body` directly (proto-field tier — see `userguide/05-expressions.md`). The body bytes are exposed as a typed `ProtoHandle` to fastpath; standard runtime JSON-shape access also works for backward compat.

### gRPC fastpath

Set `runtime_mode: fastpath` to take the inline-dispatched proto-native data path:

- Bytes flow client → tonic → gRPC adapter → `ProtoHandle` → workflow → EndTrigger `bytes_ref` with **zero proto/JSON roundtrip** when paired with the gRPC connector's `raw_response: true` mode (see `userguide/03-connectors.md`).
- `EndTrigger` should use `language: bytes_ref, source: "<handle_var>"` to return raw proto bytes; pair with `body_schema` so the gRPC adapter frames the response correctly.
- V-Rule packs gain proto-native input + output via `bind_proto` + `output_proto_schema` schema fields (see `userguide/11-vrule-vdicl.md`).
- Connector with `await_response: true` (auto-detected from response-path placement) is supported on the fastpath since 2026-05-03; previously detached-only.

```yaml
- id: trigger
  activity_type: Trigger
  trigger_config:
    trigger_type: grpc
    runtime_mode: fastpath
    grpc:
      service: "examples.Gateway"
      method: "Passthrough"
      body_schema: "examples.GatewayMessage"
    response_framing: length_prefixed
    end_activity: respond
  output_variable: trigger_payload

- id: respond
  activity_type: EndTrigger
  end_trigger_config:
    trigger_ref: trigger
    final_response:
      language: bytes_ref
      source: "trigger_body"
```

**Tail-tuning baseline (production):** TCP_NODELAY is mandatory on the gRPC adapter (already always-on as of 2026-05-03). Set `VFLOW_TOKIO_WORKERS=2` for tightest p99/p50 latency ratio on RPC workloads — see `benchmark-vflow/2026-05-03-grpc-gateway-vflow-vs-envoy.md` for mechanism details.

### Examples

- `examples-vflow/provision-pattern/013-grpc-trigger/` — basic gRPC trigger + descriptor-backed connector contract
- `examples-vflow/provision-pattern/060-standard-vrule-risk-scoring-grpc/` — standard runtime gRPC + V-Rule risk scoring
- `examples-vflow/provision-pattern/061-fastpath-vrule-risk-scoring-grpc/` — fastpath gRPC + V-Rule (apple-to-apple with 047 webhook fastpath)
- `examples-vflow/provision-pattern/062-fastpath-grpc-passthrough/` — pure passthrough ceiling test (Trigger → EndTrigger bytes_ref)
- `examples-vflow/provision-pattern/063-vflow-gateway-vstarlark/` — vflow gateway with V-Starlark business logic + gRPC connector (head-to-head with Envoy + Lua filter)
- `examples-vflow/provision-pattern/064-vflow-gateway-plain/` — plain forwarder gateway, zero proto/JSON roundtrip via `raw_request: true` + `raw_response: true` (head-to-head with Envoy plain proxy)

---

## `iot` — IoT broker

| Config field | Notes |
|---|---|
| `broker_url` | Broker URL. |
| `topic` | Topic filter. |
| `path` | Internal route. |

---

## `evm` — EVM contract event

| Config field | Notes |
|---|---|
| `rpc_url` | Ethereum RPC endpoint. |
| `contract` | Contract address. |
| `path` | Internal route. |

---

## `email` — IMAP arrival

| Config field | Notes |
|---|---|
| `imap_url` | IMAP server URL. |
| `mailbox` | Mailbox (e.g. INBOX). |
| `path` | Internal route. |

Polling-based.

---

## `nats` — core pub/sub

| Config field | Notes |
|---|---|
| `urls` | Comma-separated NATS servers. |
| `subject` | Subject — wildcards allowed (e.g. `orders.>`). |
| `queue_group` | Optional. Competing-consumer semantics. |
| `path` | Internal route. |



**Stub:**
```yaml
- id: nats_trig
  activity_type: Trigger
  trigger_config:
    trigger_type: nats
    urls: "nats://localhost:4222"
    subject: "orders.>"
    queue_group: "order-service"
    path: /internal/nats/orders
  output_variable: msg
```

---

## `nats_js` — JetStream durable consumer

Redelivers on failure (Slice 9b). Routes to DLQ on exhaustion.

| Config field | Type | Notes |
|---|---|---|
| `urls` | string | NATS servers. |
| `stream` | string | Stream name. |
| `durable_name` | string | Durable consumer name. |
| `filter_subject` | string | Subject filter. |
| `ack_policy` | string | `explicit` \| `all` \| `none`. |
| `deliver_policy` | string | `all` \| `last` \| `new` \| `by_start_sequence` \| `by_start_time`. |
| `start_sequence` | u64 | For `by_start_sequence`. |
| `start_time` | RFC3339 | For `by_start_time`. |
| `max_deliver` | i64 | Redelivery cap. |
| `path` | string | Internal route. |



**Stub:**
```yaml
- id: js_trig
  activity_type: Trigger
  trigger_config:
    trigger_type: nats_js
    urls: "nats://localhost:4222"
    stream: ORDERS
    durable_name: order-processor
    filter_subject: "orders.created"
    ack_policy: explicit
    deliver_policy: new
    max_deliver: 5
    path: /internal/js/orders
  output_variable: msg
```

---

## `nats_kv` — KV bucket watcher

Fires on any key update in the watched bucket, including updates written by
external NATS clients.

| Config field | Notes |
|---|---|
| `urls` | NATS servers. |
| `bucket` | KV bucket name. |
| `key_prefix` | Optional key filter. |
| `route` | Internal workflow route. |



---

## Trigger + EndTrigger pairing

Most triggers need an `EndTrigger` activity to ship the response:

```yaml
spec:
  activities:
    - id: trig
      activity_type: Trigger
      trigger_config:
        trigger_type: webhook
        webhook_config: { path: /api/echo, method: POST }
        end_activity: respond         # name the EndTrigger here
      output_variable: trigger_payload

    - id: respond
      activity_type: EndTrigger
      end_trigger_config:
        trigger_ref: trig
        final_response:
          language: vil-expr
          source: '{"_status": 200, "body": trigger_payload.body}'

  flows:
    - { id: f1, from: { node: trig }, to: { node: respond } }
```

See 02-activities.md §EndTrigger for full config.

---

## Streaming triggers (chunked response)

For SSE / NDJSON / streaming HTTP responses:

```yaml
- id: trig
  activity_type: Trigger
  trigger_config:
    trigger_type: webhook
    webhook_config: { path: /api/stream, method: POST }
    response_framing: chunked
    end_activity: respond
  output_variable: trigger_payload

- id: llm_stream
  activity_type: Connector
  connector_config:
    connector_ref: vastar.http
    operation: post
    streaming: true
    format: sse
    dialect: openai
    json_tap: "choices[0].delta.content"
  #...

- id: respond
  activity_type: EndTrigger
  end_trigger_config:
    trigger_ref: trig
    response_framing: chunked
    final_response:
      language: vil-expr
      source: '_last_output'
```

Reference: `examples-vil/001b-vilapp-ai-gw-benchmark/vwfd/workflows/ai-gateway-filtered.yaml`
is a legacy VIL-derived reference. Back-port the pattern into `examples-vflow/`
before citing it as public runtime proof.
