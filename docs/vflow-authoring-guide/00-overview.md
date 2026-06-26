# Workflow Declaration Guide — VWFD YAML

VWFD is the declarative workflow format used by VIL OSS and VFlow. It describes workflow metadata, activities, graph edges, triggers, connectors, expressions, durability, audit envelopes, packs, tiers, and deployment-facing resources in YAML.


## Dialect Focus

This guide currently uses the `vflow` dialect in examples:

```yaml
metadata:
  dialect: vflow
```

VIL OSS and VFlow share the VWFD declaration model. The `vflow` dialect exposes the commercial runtime surface: runtime-local workflow console, durable execution modes, advanced V-CEL, V-Rule, Compute/Starlark, audit envelopes, pack/tier gating, and runtime deployment controls. VIL-compatible declarations can move toward VFlow by selecting the `vflow` dialect and using the runtime features available to that deployment.

## What You Can Declare

VWFD covers three related YAML surfaces:

1. Workflow YAML:
   The workflow graph itself. It contains `version`, `metadata`, `spec.activities`, `spec.flows`, variables, durability settings, trigger definitions, connector calls, expressions, and response handling.

2. Pack and tier manifests:
   Pack manifests define reusable connections, handler artifacts, and workflow bundles. Tier manifests define capability policy, connector allow-lists, trigger allow-lists, rate limits, and deployment constraints.

3. Infrastructure resources:
   VFlow control-plane resources use a Kubernetes-style YAML shell such as `apiVersion`, `kind`, `metadata`, and `spec` for tenants, fleet hosts, packs, tiers, and snapshots.

## Runtime Modes

Every workflow runs in one of two runtime modes:

| Mode | Default | Use For | Notes |
|---|---:|---|---|
| `standard` | yes | Durable workflows, stateful orchestration, parked HumanTask/EventGateway flows, retries, resume, audit-heavy processes, and integration workflows where kernel semantics are more important than minimum response latency. | Omit `trigger_config.runtime_mode` or set `runtime_mode: standard` on the Trigger. |
| `fastpath` | no | Stateless request/response workflows that need an immediate webhook response, such as API gateway transforms, lightweight V-CEL transforms, V-Rule scoring, and V-Starlark compute on the synchronous response path. | Set `trigger_config.runtime_mode: fastpath` on every Trigger in the workflow. Detached edges may continue background work after the response path. |

`fastpath` means optimized synchronous response path plus optional detached async side paths. It does not mean "durable" or "streaming"; durability is still configured through durability fields, and streaming remains a connector/activity setting.

```yaml
spec:
  activities:
    - id: trigger
      activity_type: Trigger
      trigger_config:
        trigger_type: webhook
        runtime_mode: fastpath
        webhook_config: { path: /risk/score, method: POST }
```

If `trigger_config.runtime_mode` is omitted, the workflow uses `standard`.

For the gRPC trigger surface, `runtime_mode: fastpath` declared inside `trigger_config` enables the proto-native data path (zero JSON ser/deser) — see `04-triggers.md` and `examples-vflow/provision-pattern/061-fastpath-vrule-risk-scoring-grpc/`.

## Server-level Runtime Tuning

The vflow-server binary reads these env vars at boot. They are **process-level transport tuning**, not per-workflow knobs:

| Env var | Default | When to set |
|---|---|---|
| `VFLOW_PORT` | required | HTTP admin/webhook port |
| `VFLOW_PIPELINE_PORT` | required | Pipeline listener port |
| `VFLOW_STATE_DIR` | required | Persistence root (state, journals, gRPC config file) |
| `VFLOW_AUDIT_EMITTER` | `nats` | `none` for tests; `nats` for production |
| `VIL_LOG_OFF` | unset | `1` silences runtime logs in benches |
| `VFLOW_TOKIO_WORKERS` | `num_cpus` | Tokio worker thread count. **Set to `2` for gRPC-heavy production** — mechanism investigation (2026-05-03) confirmed work-stealing thrash makes default `num_cpus` add 2× context switches per request without RPS gain. See `benchmark-vflow/2026-05-03-grpc-gateway-vflow-vs-envoy.md`. |

The gRPC adapter is enabled per-process via `$VFLOW_STATE_DIR/grpc_server.json`:

```json
{"enabled": true, "port": 50071}
```

TCP_NODELAY is mandatory and always-on for both ingress (hyper accepted streams) and egress (tonic Channel pool). No knob; cures the 40 ms bimodal latency histogram from Nagle + delayed-ACK on Linux loopback.

## Guide Map

| File | Covers | Use When |
|---|---|---|
| [`01-schema.md`](./01-schema.md) | Top-level workflow keys, metadata, `spec`, variables, graph edges, durability, retry, compensation, and persistence. | Starting a new workflow YAML. |
| [`02-activities.md`](./02-activities.md) | Trigger, Connector, WasmFunction, NativeCode, Sidecar, SubWorkflow, HumanTask, VRule, Compute, EndTrigger, End, Signal, EventGateway, Validate, Transform, loop, gateway, and error boundary nodes. | Choosing and configuring activity nodes. |
| [`03-connectors.md`](./03-connectors.md) | Database, queue, broker, HTTP, gRPC, object storage, protocol, codec, and industrial connectors. | Calling external systems from a workflow. |
| [`04-triggers.md`](./04-triggers.md) | Webhook, cron, broker, storage event, CDC, DB poll, file-system, gRPC, IoT, EVM, email, NATS, and NATS JetStream triggers. | Designing workflow entry points. |
| [`05-expressions.md`](./05-expressions.md) | `literal`, `spv1`, `vil-expr`, `v-cel`, and `vil_query` expressions. | Mapping inputs, writing guards, shaping output, and building queries. |
| [`06-pack-tier.md`](./06-pack-tier.md) | `pack.yaml` and `tier.yaml` bundle and policy declarations. | Packaging reusable workflow assets and limiting runtime capabilities. |
| [`07-examples.md`](./07-examples.md) | Example selection and authoring patterns. | Looking for a working pattern before writing a new workflow. |
| [`08-iac-resources.md`](./08-iac-resources.md) | Control-plane resource YAML for tenants, fleet hosts, packs, tiers, and snapshots. | Managing runtime infrastructure declaratively. |
| [`09-quick-transform.md`](./09-quick-transform.md) | `quick_transform` and SPv1 output shaping. | Extracting, filtering, or reshaping activity output cheaply. |
| [`10-vcel-transform.md`](./10-vcel-transform.md) | V-CEL syntax, operators, built-ins, proto support, and worked examples. | Writing CEL-compatible expressions for transforms and guards. |
| [`11-vrule-vdicl.md`](./11-vrule-vdicl.md) | V-Rule and VDICL rule packs, schemas, hit policies, actions, and VRule activities. | Encoding decision tables, compliance checks, scoring, and business rules. |
| [`12-compute-activity.md`](./12-compute-activity.md) | Compute activity with Starlark-compatible logic. | Writing multi-step logic that is too large for a Transform expression. |
| [`13-audit-log.md`](./13-audit-log.md) | Declarative audit envelope emission. | Emitting workflow and activity audit events to user-owned sinks. |

## Minimal Workflow

```yaml
version: "3.0"
metadata:
  id: hello-workflow
  name: "Hello World"
  dialect: vflow

spec:
  activities:
    - id: trig
      activity_type: Trigger
      trigger_config:
        trigger_type: webhook
        webhook_config: { path: /api/hello, method: POST }
        end_activity: respond
      output_variable: trigger_payload

    - id: respond
      activity_type: EndTrigger
      end_trigger_config:
        trigger_ref: trig
        final_response:
          language: vil-expr
          source: '{"_status": 200, "body": {"ok": true}}'

  flows:
    - { id: f1, from: { node: trig }, to: { node: respond } }
```

Runtime upload uses the runtime-local API:

```http
POST /api/admin/workflow/upload
Content-Type: application/yaml
```

VFlow Cloud may hand a user to the runtime console, but workflow authoring, execution, observability, and operator actions remain local to the runtime.
