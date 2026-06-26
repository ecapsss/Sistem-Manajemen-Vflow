# VWFD YAML — Top-Level Schema


---

## Top-level keys

```yaml
version: "3.0"        # optional, default "3.0"
metadata: { ... }     # optional
spec: { ... }         # REQUIRED
visual: { ... }       # optional (ignored by compiler)
```

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `version` | string | no | `"3.0"` | VWFD format version. Canonical value is `"3.0"`. |
| `metadata` | object | no | `{}` | Workflow identity, dialect selector, durability policy. |
| `spec` | object | **yes** | — | Activities, flows, variables, controls. |
| `visual` | any | no | `null` | Visual-editor layout data. Compiler ignores. |

---

## `metadata` — VwfdMetadata

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `id` | string | no | — | Workflow identifier. User-defined; runtime may normalize to `wf_*`. |
| `name` | string | no | — | Human-readable name. |
| `description` | string | no | — | Long-form documentation. |
| `workflow_version` | any | no | — | Semver of the workflow, separate from VWFD format `version`. |
| `author` | string | no | — | Creator attribution. |
| `tags` | [string] | no | `[]` | Categorical labels. |
| `updated_at` | string | no | — | ISO 8601 timestamp of last edit. |
| `dialect` | string | no | `"vflow"` | `"vil"` \| `"vflow"`. Selects dialect-specific runtime features. |
| `dialect_version` | string | no | — | Semver of the dialect, e.g. `"1.1"`. |
| `shm` | bool | no | `false` | VFlow dialect shared-memory option. |
| `durability` | scalar or object | no | — | Workflow-level durability. See "Durability" below. |

### `metadata.durability` — two forms

**Legacy scalar** (string):
```yaml
metadata:
  durability: durable_strict   # or: observability | durable | stateless | inherit
```

**Spec-v2 struct**:
```yaml
metadata:
  durability:
    mode: external-io-snapshot
    retention:
      l2: 24h
      l3: { ... }
    snapshot:
      periodic: "0 */6 * * *"
    storage:
      compression: zstd
      encryption: aes256
```

Per-activity override: set `durability:` on an activity (see 02-activities.md).

---

## `spec` — VwfdSpec

| Field | Type | Required | Semantics |
|---|---|---|---|
| `activities` | [VwfdActivity] | **yes** | List of workflow nodes. Each has `id`, `activity_type`, and a type-specific config. |
| `flows` | [VwfdFlow] | **yes** | Edges connecting activities. |
| `controls` | [VwfdControl] | no | Explicit gateways/forks/joins. Usually inferred from `activity_type`. |
| `variables` | [VwfdVariable] | no | Declared variables (name + type + scope). |
| `settings` | any | no | Global workflow settings (reserved). |
| `error_handlers` | [any] | no | Global error handlers (reserved). |
| `durability` | DurabilityConfig | no | Per-activity durability override map. |

### Trigger `runtime_mode`

```yaml
spec:
  activities:
    - id: trigger
      activity_type: Trigger
      trigger_config:
        trigger_type: webhook
        runtime_mode: fastpath  # fastpath | standard
        webhook_config: { path: /risk/score, method: POST }
```

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `runtime_mode` | string | no | `standard` | Declared inside each Trigger's `trigger_config`. `fastpath` selects the optimized synchronous response path for stateless request/response workloads. `standard` selects the normal kernel path. Durability remains controlled by `metadata.durability` / `spec.durability`. |

Accepted values:

- `standard`: default when omitted. Use for durable orchestration, stateful execution, parked HumanTask/EventGateway flows, retry/resume behavior, and general integration workflows.
- `fastpath`: optimized synchronous response path for webhook request/response workloads. Use for stateless response flows such as API gateway shaping, V-CEL transforms, V-Rule scoring, and V-Starlark compute.

Fastpath rules:

- A webhook `Trigger` must have a non-detached path to `EndTrigger`.
- `EndTrigger` is the client response exit.
- Edges marked `detached: true` start background work. Detached branches must not rejoin the response path or feed `final_response`.
- Detached fastpath branches are queued after the response is emitted. Use this for audit, notification, or non-critical side-effect work that must not block the caller; the runtime captures only variables referenced by that branch.
- Control-flow nodes such as Exclusive, Inclusive, Parallel, and Join are allowed on the response path. If they block, the client waits.
- Stateless compute nodes are allowed on the response path when the runtime has the required engine loaded, including `Transform`, `VRule`, and `Compute` with `language: v-starlark`.
- Stateful, parked, or external-side-effect activities should normally stay on the standard path or move behind a detached edge.
- Stream behavior remains an activity/connector concern, for example `connector_config.streaming: true`; it is not encoded in runtime mode.
- Other workflow behavior such as durable checkpoints, observability, retry, and resume is configured by the durability and activity fields.

Standard mode example:

```yaml
spec:
  activities:
    - id: trigger
      activity_type: Trigger
      trigger_config:
        trigger_type: webhook
        webhook_config: { path: /orders, method: POST }
      output_variable: trigger_payload
```

Fastpath example:

```yaml
spec:
  activities:
    - id: trigger
      activity_type: Trigger
      trigger_config:
        trigger_type: webhook
        runtime_mode: fastpath
        webhook_config: { path: /risk/score, method: POST }
      output_variable: trigger_payload

    - id: score
      activity_type: VRule
      rule_config:
        rule_set_id: fastpath_risk_v1
      input_mappings:
        - target: amount
          source: { language: spv1, source: "$.trigger_payload.body.amount" }
      output_variable: risk_result

    - id: respond
      activity_type: EndTrigger
      end_trigger_config:
        trigger_ref: trigger
        final_response: { language: spv1, source: "$.risk_result" }

  flows:
    - { id: f1, from: { node: trigger }, to: { node: score } }
    - { id: f2, from: { node: score }, to: { node: respond } }
```

---

## `spec.variables` — VwfdVariable

```yaml
variables:
  - name: user_data
    type: object
    scope: workflow
  - name: items
    type: array
  - name: counter
    type: integer
```

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `name` | string | yes | — | Variable name. Referenced by expressions. |
| `type` | string | yes | — | `string` \| `number` \| `integer` \| `boolean` \| `object` \| `array` \| `null`. |
| `scope` | string | no | `workflow` | Variable scope hint for runtime and tooling. |

---

## `spec.flows` — VwfdFlow

Edges connect activities. A flow from `A` to `B` means "when A emits, advance to B".

```yaml
flows:
  - id: f_main
    from: { node: trig }
    to:   { node: respond }

  - id: f_branch_high
    from: { node: gate }
    to:   { node: expensive }
    condition: "amount > 10000"
    priority: 1

  - id: f_fork_bg
    from: { node: parallel_root }
    to:   { node: background_task }
    detached: true
```

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `id` | string | **yes** | — | Unique edge id. |
| `from` | FlowEndpoint | **yes** | — | `{ node: <activity_id>, port?: <port_name> }`. |
| `to` | FlowEndpoint | **yes** | — | `{ node: <activity_id>, port?: <port_name> }`. |
| `flow_type` | string | no | — | Edge type. Usually inferred. Special value: `"error"` — see below. |
| `condition` | string | no | — | V-CEL expression evaluated on emit. Only taken if true. |
| `priority` | i8 | no | `0` | Higher first. Used by ExclusiveGateway to pick the winning branch when multiple conditions match. |
| `detached` | bool | no | `false` | Edge marks a **background branch**. Sub-graph reached through this edge runs after the response is emitted (fastpath) or in parallel with the main path (standard). Restrictions + semantics in the **Detached edges** subsection below. |

### Detached edges (background branches)

`detached: true` on an outgoing edge marks the entire sub-graph reachable through it as a **background branch**. The runtime evaluates it in parallel with the main response path; the response is NOT delayed by the detached branch.

```yaml
flows:
  - id: f_main
    from: { node: trigger }
    to:   { node: score_risk }
  - id: f_respond
    from: { node: score_risk }
    to:   { node: respond }
  - id: f_audit
    from: { node: score_risk }
    to:   { node: build_audit_record }
    detached: true                     # ← audit branch runs after respond
  - id: f_audit_publish
    from: { node: build_audit_record }
    to:   { node: publish_to_nats }    # part of detached sub-graph
```

**Semantics:**
- **Fastpath**: detached branches are queued AFTER the response is emitted to the caller. They cannot block the response. Connector activities on a detached branch dispatch fire-and-forget (`tokio::spawn`) and the output variable receives `{"status": "queued"}` — no `await` for the result.
- **Standard runtime**: detached branches run in parallel with the main path; the kernel does not block the response on them.
- **Variables captured**: only variables actually referenced by the detached sub-graph are passed. Unused state stays on the main path. Reduces memory pressure for high-RPS workloads.

**Restrictions** (validator enforces these):
- Detached sub-graph must NOT rejoin the main response path. Forking back into the response is a compile error.
- Detached sub-graph must NOT feed `EndTrigger.final_response`.
- A webhook/gRPC `Trigger` must have at least one non-detached path to its `EndTrigger`.

**Common patterns:**
- Audit-record construction + emission (NATS, ClickHouse, audit sink). Example: `050-fastpath-vrule-risk-scoring-detached/`.
- Notification fan-out (email, Slack). The caller gets the response immediately; notifications go out async.
- Metrics emission, observability hooks.
- Cache-warming or pre-computation for the next request.

**Join interaction:** when a `Join` activity has incoming edges, a detached edge into it tells the Join barrier to NOT wait for that branch. Use this when one branch is a side-effect that the join doesn't need to synchronize on.

Reference examples:
- `050-fastpath-vrule-risk-scoring-detached/` vs `051-...-blocking/` — apple-to-apple bench fixture for detached vs blocking audit overhead.
- `052-standard-vrule-risk-scoring-detached/` vs `053-...-blocking/` — same comparison on standard runtime.
- `055-standard-vrule-risk-scoring-detached-nats-publish/` + `058-fastpath-vrule-risk-scoring-detached-nats-publish/` — detached materialized NATS publish patterns.

### Error edges

To route a thrown error from an activity to a fallback, use `flow_type: error`:

```yaml
flows:
  - id: f_ok
    from: { node: risky }
    to:   { node: respond_ok }
  - id: f_err
    flow_type: error
    from: { node: risky }
    to:   { node: fallback }
```

See `examples-vflow/vwfd-compile-time-pattern/error-edge-smoke/workflows/error-catch.yaml` for a working reference.

### Conditional edges — ExclusiveGateway

```yaml
flows:
  - id: f_hi
    from: { node: gate }
    to:   { node: premium_path }
    condition: "amount > 1000 && user.tier == 'premium'"
    priority: 1
  - id: f_default
    from: { node: gate }
    to:   { node: standard_path }
    priority: 0         # lowest — the fallback
```

For **InclusiveGateway** the engine takes ALL edges whose condition is true (multi-branch). ExclusiveGateway takes exactly one — the first-matching by priority.

### Detached edges — Join barrier

`detached: true` on an edge entering a Join tells the Join barrier to not wait for that branch. Used for fire-and-forget background work.

---

## `spec.activities` — VwfdActivity core fields

Every activity shares this shell. Type-specific config goes in the matching field (see 02-activities.md).

```yaml
- id: pay
  activity_type: Connector
  name: "Charge card"
  description: "Debit the user's card"
  connector_config: { ... }      # type-specific
  input_mappings: [ ... ]
  output_variable: payment_result
  durability: inherit
  persistence:
    mode: payload-async
    capture: { input: false, output: true, scope: full }
  compensation:                  # for Saga rollback
    connector_ref: vastar.http
    operation: post
    input_mappings: [ ... ]
  quick_transform:
    select: "$.data.amount"
```

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `id` | string | **yes** | — | Unique within workflow. Referenced in flows. |
| `activity_type` | string | **yes** | — | Variant name. See 02-activities.md for full list. |
| `name` | string | no | — | Human-readable label. |
| `description` | string | no | — | Docstring. |
| `label` | string | no | — | Short visual label for UI. |
| `annotations` | any | no | — | Arbitrary metadata; kernel ignores. |
| `output_variable` | string | no | — | Variable to bind activity output. |
| `durability` | string | no | `inherit` | `non_durable` \| `eventual` \| `immediate` \| `inherit`. |
| `persistence` | object or string | no | — | Per-activity persistence — see "Persistence" below. |
| `compensation` | CompensationConfig | no | — | Saga compensation block — see "Compensation". |
| `quick_transform` | object | no | — | Universal SPv1 `select` + optional `filter`. Applied to this activity's output. |
| `aggregate` | bool | no | `false` | Streaming activities only: `true` buffers all events into one payload; `false` forwards chunks. |
| `input_ports` | [Port] | no | — | Explicit port definitions. |
| `output_ports` | [Port] | no | — | Explicit output port definitions. |
| `input_mappings` | [InputMapping] | no | — | Wire variables to activity inputs. See 05-expressions.md. |
| `trigger_config` / `connector_config` / `wasm_config` / `code_config` / `sidecar_config` / `sub_workflow_config` / `human_task_config` / `rule_config` / `end_trigger_config` / `end_config` / `signal_config` / `validate_config` / `event_gateway_config` / `loop_config` | type-specific object | exactly one, matching `activity_type` | — | See 02-activities.md. |

### `persistence` — two forms

**Legacy shorthand** (string):
```yaml
```

**Spec-v2 struct**:
```yaml
persistence:
  capture:
    input: false
    output: true
    scope: full              # or: headers-only | partial
    buffer_cap: 256kb
    on_overflow: hash-tail   # or: drop | block
```

Common values by use case:
- `skip`: no snapshot (stateless compute, streaming inner nodes).
- `eventual` / `immediate`: when to flush state to disk.

### `compensation` — Saga rollback

Executed in reverse order on workflow failure.

```yaml
- id: charge
  activity_type: Connector
  connector_config: { ... }
  compensation:
    connector_ref: vastar.http
    operation: post
    input_mappings:
      - target: payment_id
        source:
          language: spv1
          source: '$.charge'
```

Reference: `examples-vflow/vwfd-compile-time-pattern/saga-smoke/workflows/checkout.yaml`.

### `quick_transform` — universal output shaper

SPv1 `select` + optional `filter`, applied to this activity's output regardless of activity type.

```yaml
quick_transform:
  select: "$.results[*].name"
  filter: "$.status == 'active'"
```

Distinct from connector-specific `json_tap` (which is an HTTP/SSE chunk extractor).

### `input_mappings` — wiring variables into inputs

```yaml
input_mappings:
  - target: url
    source:
      language: literal
      source: "http://api.example.com/v1/chat"
  - target: body
    source:
      language: vil-expr
      source: '{ "q": trigger_payload.body.q }'
  - target: headers
    source:
      language: spv1
      source: '$.config.headers'
```

See 05-expressions.md for full language reference.
