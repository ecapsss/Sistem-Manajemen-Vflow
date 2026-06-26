# VWFD YAML — Activity Types


Every activity has a shell (see 01-schema.md §activities) plus exactly one type-specific config field matching its `activity_type`.

---

## Activity type → config field map

| `activity_type` | Config field |
|---|---|
| `Trigger` | `trigger_config` |
| `Connector` | `connector_config` |
| `Function` / `WasmFunction` | `wasm_config` |
| `NativeCode` | `code_config` |
| `Sidecar` | `sidecar_config` |
| `SubWorkflow` | `sub_workflow_config` |
| `HumanTask` | `human_task_config` |
| `VRule` | `rule_config` |
| `Compute` | `compute_config` |
| `Timer` | `timer_config` |
| `EndTrigger` | `end_trigger_config` |
| `End` | `end_config` |
| `Signal` | `signal_config` |
| `EventGateway` | `event_gateway_config` |
| `Validate` | `validate_config` |
| `LoopForEach` / `LoopWhile` / `LoopRepeat` | `loop_config` |
| `Transform` | uses `input_mappings` + `output_variable` |
| `Noop` | none |
| `ErrorBoundary` | error-edge driven |
| `ExclusiveGateway` / `InclusiveGateway` / `Parallel` / `Join` | edge-driven |

---

## Trigger

Inbound entry point. Binds external event to workflow variables.

**Config field:** see the YAML fields below.

| Field | Type | Required | Semantics |
|---|---|---|---|
| `trigger_type` | string | yes | `webhook` \| `cron` \| `kafka` \| `nats` \| `nats_js` \| `nats_kv` \| `grpc` (alias `grpc_server`) \| `s3_event` \| `mqtt` \| `sftp` \| `cdc` \| `db_poll` \| `fs` \| `iot` \| `evm` \| `email` \| `grpc_stream`. See 04-triggers.md for per-type config. |
| `route` | string | no | Router path / topic. |
| `response_framing` | string | no | `chunked` \| `length_prefixed`. Legacy: `response_mode: streaming \| buffered`. |
| `stream_format` | string | no | Format hint for streaming. |
| `end_activity` | string | no | ID of the EndTrigger that emits the response. |
| `input_schema` | JSON Schema | no | Validates request body. |
| `filter` | string (V-CEL) | no | Only enter the kernel if true. |
| `transform` | string (V-CEL) | no | Transform payload pre-kernel. |
| `webhook` / `cron` / `kafka` / `grpc_server` / `s3_event` / ... | nested object | no | Type-specific details — see 04-triggers.md. |

**Stub — webhook trigger:**
```yaml
- id: trig
  activity_type: Trigger
  trigger_config:
    trigger_type: webhook
    webhook_config: { path: /api/users, method: POST }
    response_framing: chunked
    end_activity: respond
  output_variable: trigger_payload
```

---

## Connector

Calls an external system (HTTP, DB, queue, etc.).

**Config field:** see the YAML fields below.

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `connector_ref` | string | yes | — | Connector kind (e.g. `vastar.http`, `vastar.grpc`, `postgres`) or `pack://<pack_id>/<conn_name>` for pack-scoped references. |
| `operation` | string | yes | — | Operation name from the connector catalog, e.g. `post`, `find_one`, `insert`, `publish`, `call`. |
| `streaming` | bool | no | `false` | Enable streaming events instead of a single response. |
| `stream_format` | string | no | — | `sse` \| `ndjson` \| `raw`. |
| `timeout_ms` | u32 | no | — | Operation timeout in milliseconds. |
| `retry_policy_id` | string | no | — | Reference to a named retry policy. |
| `retry_policy` | RetryPolicyConfig | no | — | Inline retry policy: `{ max_attempts, base_delay_ms, max_delay_ms, backoff_factor }`. |
| `config` | any | no | — | Connector-specific static config. |
| `params` | any | no | — | Connector-specific runtime params. |
| `format` / `dialect` / `json_tap` / `done_marker` / `done_event` / `done_json_field` / `bearer_token` / `anthropic_key` / `api_key_param` / `queue_capacity` | HTTP/SSE shortcuts | no | — | VIL HTTP dialect extensions — see 03-connectors.md. |

**Fastpath dispatch semantics (await vs detached):** when a workflow runs in `runtime_mode: fastpath`, the Connector's dispatch mode is determined automatically by the plan-builder based on graph topology:

- **Response-path Connector** (reachable from Trigger without crossing a detached edge) — connector awaits inline; the decoded response feeds the next node. Use this for thin gateway / RPC-forwarder workflows.
- **Detached-branch Connector** — fire-and-forget `tokio::spawn`; the output variable receives a `{"status": "queued"}` placeholder so chained nodes don't block on the side-effect.

Restriction lifted 2026-05-03 (was previously detached-only). Public examples: `063-vflow-gateway-vstarlark/` (V-Starlark validation + gRPC connector forward + V-Starlark response shaping), `064-vflow-gateway-plain/` (zero-copy bytes-mode forwarder via `vastar.grpc` `raw_request: true` + `raw_response: true`).

**Stub — HTTP streaming (OpenAI dialect):**
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
    bearer_token: "sk-..."
    timeout_ms: 30000
    retry_policy:
      max_attempts: 3
      base_delay_ms: 1000
      max_delay_ms: 10000
      backoff_factor: 2.0
  input_mappings:
    - target: url
      source: { language: literal, source: "https://api.openai.com/v1/chat/completions" }
    - target: body
      source: { language: vil-expr, source: '{ "model": "gpt-4", "messages": trigger_payload.body.messages }' }
  output_variable: response
```

---

## Function / WasmFunction

Invokes a WASM module (compiled extension).

`Function` is the preferred VFlow dialect spelling for WASM-backed functions.
`WasmFunction` and `wasm_function` are accepted compatibility aliases and map to
the same runtime node.

**Config field:** see the YAML fields below.

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `module_ref` | string | yes | — | WASM module name. Resolves via registry key `wasm.{module_ref}`. |
| `function_name` | string | no | `execute` | Function within the module. |
| `pool_size` | u32 | no | `4` | Pre-warmed instance count. |
| `max_memory_pages` | u32 | no | `256` | 1 page = 64 KB; default cap is 16 MB. |
| `timeout_ms` | u32 | no | `5000` | Execution timeout. |

**Stub:**
```yaml
- id: transform
  activity_type: Function
  wasm_config:
    module_ref: currency_convert
    function_name: execute
    pool_size: 8
    timeout_ms: 10000
  input_mappings:
    - target: amount
      source: { language: spv1, source: '$.trigger_payload.body.amount' }
  output_variable: converted
```

Reference: `examples-vil/003-basic-hello-server/vwfd/workflows/convert.yaml`
is a legacy VIL-derived reference only. Public vflow runtime docs should use a
proper `examples-vflow/` WASM artifact example; see
`examples-vflow/FEATURE_EXAMPLE_ENHANCEMENT_PLAN.md`.

---

## NativeCode

Invokes a native Rust handler registered at boot.

**Config field:** see the YAML fields below.

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `handler_ref` | string | yes | — | Handler name. Resolves via registry key `code.{handler_ref}`. |
| `timeout_ms` | u32 | no | `30000` | Execution timeout. |
| `exec_class` | string | no | `async` | `async` \| `blocking` \| `dedicated_thread`. |

**Stub:**
```yaml
- id: score
  activity_type: NativeCode
  code_config:
    handler_ref: fraud_detector
    exec_class: async
    timeout_ms: 5000
  input_mappings:
    - target: transaction
      source: { language: spv1, source: '$.txn' }
  output_variable: fraud_score
```

---

## Sidecar

Invokes an out-of-process runtime (Python, Node, etc.) via RPC + shared memory.

**Config field:** see the YAML fields below.

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `target` | string | yes | — | Sidecar name. Resolves via registry key `sidecar.{target}`. |
| `method` | string | no | `execute` | Method or function to invoke. |
| `command` | string | no | — | Spawn command, e.g. `python -m fraud_service`. |
| `source` | string | no | — | Source file for auto-detection. |
| `pool_size` | u32 | no | `4` | Connection pool size. |
| `shm_size` | u64 | no | `64MB` | Shared-memory region size in bytes. |
| `timeout_ms` | u32 | no | `30000` | Execution timeout. |
| `fallback_wasm` | string | no | — | WASM fallback if all sidecars are down. |

**Stub:**
```yaml
- id: fraud_sc
  activity_type: Sidecar
  sidecar_config:
    target: fraud_detector_py
    method: score_transaction
    pool_size: 8
    timeout_ms: 10000
    failover_target: fraud_detector_backup
    fallback_wasm: fraud_fallback
  input_mappings:
    - target: txn_data
      source: { language: spv1, source: '$.transaction' }
  output_variable: fraud_result
```

Reference: `examples-vflow/vwfd-compile-time-pattern/sidecar-smoke/workflows/fraud-check.yaml`.

---

## SubWorkflow

Invokes another provisioned workflow (nested kernel execution).

**Config field:** see the YAML fields below.

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `workflow_ref` | string | yes | — | Workflow ID (`metadata.id`) or hashed `wf_<crc32>`. |
| `timeout_ms` | u32 | no | `60000` | Execution timeout. |
| `input_strategy` | string | no | `mapped` | `pass_all` (forward all vars) \| `mapped` (use input_mappings). |

**Stub:**
```yaml
- id: child
  activity_type: SubWorkflow
  sub_workflow_config:
    workflow_ref: child-double
    timeout_ms: 120000
    input_strategy: mapped
  input_mappings:
    - target: value
      source: { language: spv1, source: '$.trigger_payload.body.value' }
  output_variable: child_result
```

Reference: `examples-vflow/vwfd-compile-time-pattern/subworkflow-smoke/workflows/parent-square.yaml`.

---

## HumanTask

Routes work to a human operator.

**Config field:** see the YAML fields below.

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `task_type` | string | yes | — | e.g. `approval`, `review`. |
| `assignee` | string (V-CEL) | no | — | Resolves to a user or group. |
| `candidate_groups` | [string] | no | — | OR semantics. |
| `title` | string | no | — | Template; may contain V-CEL. |
| `description` | string | no | — | Template. |
| `form_ref` | string | no | — | Form schema id for UI. |
| `priority` | u8 | no | `50` | 0-100. |
| `due_date` | string (V-CEL) | no | — | Resolves to ISO8601 or epoch. |
| `timeout_ms` | u64 | no | — | Auto-escalation trigger. |
| `escalation_target` | string | no | — | Escalation user or group on timeout. |

---

## VRule

Executes a rule set through the runtime rule engine.

**Config field:** see the YAML fields below.

| Field | Type | Required | Semantics |
|---|---|---|---|
| `rule_set_id` | string | no | Rule set identifier. |
| `version_policy` | string | no | `latest` \| `pinned` \| `<semver>`. |

---

## Compute

Executes a Starlark code block (loop / algorithm / multi-step
logic). Two engines selectable via `language:`:

- `language: starlark` — spec-pure (VIL OSS + vflow)
- `language: v-starlark` — vflow performance variant (PreparedModule
  + 2-layer budget; per-call floor 162 ns)

**Config:** ComputeConfig (full spec at
[`12-compute-activity.md`](./12-compute-activity.md)). The compiler, graph
node, kernel dispatch, ctx marshalling, and real-server `v-starlark` smoke are

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `language` | string | yes | — | `starlark` \| `v-starlark` |
| `source` | string | yes | — | Full Starlark code; must define entry function. |
| `entry_fn` | string | no | `run` | Function called with one positional `ctx` dict. |
| `timeout_ms` | u32 | no | `5000` | Wall-clock per-call cap. |
| `budget_profile` | string | no | `default` | `default` \| `balanced` \| `heavy` (`v-starlark` only). |
| `vdicl_rule` | object | no | — | Compile-time VDICL rule-pack reference to transpile into Starlark. Same shape as `VRule.rule_config`. |

**Stub:**
```yaml
- id: pricing_compute
  activity_type: Compute
  compute_config:
    language: v-starlark
    source: |
      def run(ctx):
          discount = 0
          for tier in ctx["tiers"]:
              if ctx["base"] >= tier["min"]:
                  discount = tier["pct"]
          return ctx["base"] * (100 - discount) / 100
    budget_profile: balanced
  input_mappings:
    - target: base
      source: { language: spv1, source: '$.cart.subtotal' }
    - target: tiers
      source: { language: v-cel, source: 'pricing.tiers' }
  output_variable: final_price
```

For full semantics + label-switching guarantee + engine-selection rule,
see [`12-compute-activity.md`](./12-compute-activity.md).

Reference: `examples-vflow/provision-pattern/019-compute-starlark/workflow.yaml`
and `examples-vflow/runtime-smoke/compute-starlark-live-smoke.sh`.

---

## EndTrigger

Sends the response back to the trigger (mid-execution for streaming, or final response).

**Config field:** see the YAML fields below.

| Field | Type | Required | Semantics |
|---|---|---|---|
| `trigger_ref` | string | yes | ID of the source Trigger. |
| `response_framing` | string | no | `chunked` \| `length_prefixed`. |
| `final_response` | object | no | `{ language, source, encoding? }` — expression evaluated for the response body. |

**Stub — HTTP JSON response:**
```yaml
- id: respond
  activity_type: EndTrigger
  end_trigger_config:
    trigger_ref: trig
    final_response:
      language: vil-expr
      source: '{"_status": 200, "body": { "ok": true, "data": _last_output }}'
```

**Stub — gRPC proto response (base64 over webhook transport):**
```yaml
- id: respond
  activity_type: EndTrigger
  end_trigger_config:
    trigger_ref: trigger
    final_response:
      language: spv1
      source: '$.resp'        # previously encoded via proto_encode_typed()
      encoding: base64
```

**Stub — gRPC native byte-pass response (`bytes_ref` source):**

Read raw bytes from a variable's handle slot; ideal for fastpath gRPC where V-Rule's `output_proto_schema` already wrote proto wire bytes, or where a Connector's `raw_response: true` mode mirrored upstream bytes verbatim.

```yaml
- id: respond
  activity_type: EndTrigger
  end_trigger_config:
    trigger_ref: trigger
    final_response:
      language: bytes_ref
      source: "risk_result"     # V-Rule output handle slot (see 11-vrule-vdicl.md)
```

The optional `$.` prefix is accepted (`source: "$.risk_result"` ≡ `"risk_result"`). See `userguide/05-expressions.md` for the `bytes_ref` language details, and examples `061-fastpath-vrule-risk-scoring-grpc/`, `062-fastpath-grpc-passthrough/`, `064-vflow-gateway-plain/` for full workflow shapes.

Reference: `vflow-cloud/services/tenant-lifecycle-svc/workflows/grpc_provision.yaml:77-84`
`examples-vflow/provision-pattern/025-internal-grpc-proto-contract/`.

---

## End

Marks workflow termination (without response).

**Config field:** see the YAML fields below.

| Field | Type | Required | Semantics |
|---|---|---|---|
| `status` | string | no | e.g. `success`, `failure`. Optional metadata. |

---

## Signal

Sends a control signal.

**Config field:** see the YAML fields below.

| Field | Type | Required | Semantics |
|---|---|---|---|
| `signal` | string | yes | `cancel` (clean abort) \| `terminate` / `abort` (fail) \| custom. |
| `target` | string | no | Target workflow / activity (optional). |

**Stub:**
```yaml
- id: abort
  activity_type: Signal
  signal_config:
    signal: cancel
  persistence: skip
```

Reference: `examples-vflow/vwfd-compile-time-pattern/signal-gateway-smoke/workflows/route.yaml`.

---

## EventGateway

Parks the workflow until a named event fires (external injection via `POST /api/admin/event/fire`).

**Config field:** see the YAML fields below.

| Field | Type | Required | Semantics |
|---|---|---|---|
| `await` | [string] | yes | Event names to wait for (any-of). |
| `timeout_ms` | u64 | no | Timeout — activity fails if no event arrives. |

**Stub:**
```yaml
- id: wait_pay
  activity_type: EventGateway
  event_gateway_config:
    await: [pay_ok, pay_failed, cancelled]
    timeout_ms: 600000
  output_variable: event

# Downstream edges guard on `event` payload:
flows:
  - { id: f_ok, from: { node: wait_pay }, to: { node: fulfil }, condition: "event.event == 'pay_ok'", priority: 2 }
  - { id: f_fail, from: { node: wait_pay }, to: { node: refund }, condition: "event.event == 'pay_failed'", priority: 1 }
  - { id: f_cancel, from: { node: wait_pay }, to: { node: cancel_handler }, condition: "event.event == 'cancelled'", priority: 0 }
```

Reference: `examples-vflow/vwfd-compile-time-pattern/event-wait-smoke/workflows/checkout.yaml`.

---

## Validate

Validates a variable against a JSON Schema subset.

**Config field:** see the YAML fields below.

| Field | Type | Required | Semantics |
|---|---|---|---|
| `input` | string (SPv1) | yes | Path to the value to validate (e.g. `$.trigger_payload.body`). |
| `schema` | JSON Schema subset | yes | `{ type, properties, required, pattern, enum, minimum, maximum, items, ... }`. |

Validation failure routes down the error-edge (`flow_type: error`).

**Stub:**
```yaml
- id: validate
  activity_type: Validate
  validate_config:
    input: "$.trigger_payload.body"
    schema:
      type: object
      required: [name, age, email]
      properties:
        name: { type: string, minLength: 1 }
        age:  { type: integer, minimum: 0, maximum: 150 }
        email: { type: string, pattern: "^[^@]+@[^@]+\\.[^@]+$" }
```

Reference: `examples-vflow/vwfd-compile-time-pattern/validate-smoke/workflows/signup.yaml`.

---

## Transform

Pure data transformation. No dedicated config — uses `input_mappings` + `output_variable`.

**Stub:**
```yaml
- id: reshape
  activity_type: Transform
  input_mappings:
    - target: out
      source:
        language: v-cel
        source: 'items.filter(i, i.price > 100000).map(i, {name: i.name, price: i.price})'
  output_variable: filtered_items
```

---

## Timer

Parks the workflow token for a runtime-local delay, then advances along the
normal outgoing edge.

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `delay_ms` | u64 | no | `1000` | Delay in milliseconds before the token resumes. |

```yaml
- id: debounce_window
  activity_type: Timer
  timer_config:
    delay_ms: 25
```

---

## Control-flow activities (no dedicated config)

### ExclusiveGateway

Picks the first matching outgoing edge (by priority). Exactly one edge taken.

```yaml
- id: router
  activity_type: ExclusiveGateway

flows:
  - { id: f_high, from: { node: router }, to: { node: premium }, condition: "amount > 1000", priority: 1 }
  - { id: f_def,  from: { node: router }, to: { node: standard }, priority: 0 }
```

### InclusiveGateway

Takes ALL edges whose condition evaluates to true (multi-branch fan-out).

### Parallel

Forks one token into N tokens (one per outgoing edge, unconditional).

### Join

Barrier: waits for all incoming tokens. Edges with `detached: true` are not awaited.

```yaml
- id: fork
  activity_type: Parallel
- id: enrich_a
  activity_type: Connector
  connector_config: { ... }
- id: enrich_b
  activity_type: Connector
  connector_config: { ... }
- id: merge
  activity_type: Join

flows:
  - { id: f1, from: { node: fork }, to: { node: enrich_a } }
  - { id: f2, from: { node: fork }, to: { node: enrich_b } }
  - { id: f3, from: { node: enrich_a }, to: { node: merge } }
  - { id: f4, from: { node: enrich_b }, to: { node: merge } }
```

### Noop

No-op. Useful as loop-body terminator or control-flow anchor.

---

## Loop activities

**Config:** LoopConfig. Used by `LoopForEach`, `LoopWhile`, `LoopRepeat`.

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `collection` | string | ForEach | — | Variable or expression resolving to an array. |
| `item_variable` | string | ForEach | — | Variable name for current item. |
| `condition` | string (V-CEL) | While | — | Continue while true. |
| `repeat_count` | u32 | Repeat | — | Fixed number of iterations. |
| `max_iterations` | u32 | no | `10000` | Safety limit. |
| `mode` | string | no | `sequential` | `sequential` \| `parallel` (forks N tokens). |
| `max_concurrency` | u32 | no | — | Cap on in-flight tokens in parallel mode. |

**Kernel-set variables inside loop body:**
- `_loop_index` — 0-based iteration number.
- `_loop_done` — true on the exit edge.
- `_loop_results` — array of body outputs (if aggregate).

**Stub — LoopForEach:**
```yaml
- id: iter
  activity_type: LoopForEach
  loop_config:
    collection: "items"
    item_variable: current_item
    mode: parallel
    max_iterations: 1000
  output_variable: loop_state

# Body edges:
flows:
  - { id: f_in,  from: { node: iter },         to: { node: process_item } }
  - { id: f_body, from: { node: process_item }, to: { node: iter } }
  - { id: f_out, from: { node: iter },         to: { node: after },       condition: "_loop_done" }
```
