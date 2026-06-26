# `audit_log:` — Declarative Audit Envelopes

Use `audit_log:` when a workflow needs structured audit events without hand-wiring separate Connector activities for every lifecycle event.

Audit events are emitted from the runtime to user-owned sinks. The pipeline is workflow YAML → kernel multiplex → NATS Binary Mode (CloudEvents v1.0 canonical format via `vflow_audit_format`) → `vil-event-collector` sidecar → ClickHouse + per-vendor batched fan-out.

### Vendor sinks shipped (verified in `crates/vflow_audit_sinks/src/`)

| Sink | Module | Notes |
|---|---|---|
| Webhook | `webhook.rs` | Generic HTTP POST CloudEvents |
| NATS | `nats.rs` | Subject-routed, dedup via `Nats-Msg-Id` |
| Sumo Logic | `sumologic.rs` | HTTP collector source endpoint |
| Better Stack | `betterstack.rs` | Logtail HTTP ingest |
| New Relic | `newrelic.rs` | Logs API |
| Datadog | `datadog.rs` | HTTP intake |
| Grafana Loki | `loki.rs` | Push API |
| Elasticsearch | `elasticsearch.rs` | Bulk index API |
| Azure Log Analytics | `azure_log_analytics.rs` | Data Collector API |

Plus pack-scoped connectors via `sink_ref: "pack://<pack>/<conn>"` reach any connector configured in the pack (S3, ClickHouse, etc).

§10 Rev2 P0 sinks pending: Kafka, AWS CloudWatch+S3, OTLP, GCP Logging+BigQuery (Webhook overlaps with shipped).

## What `audit_log:` Does

`audit_log:` can be declared at workflow level and activity level:

- Workflow-level audit emits events such as `workflow_started`, `workflow_succeeded`, and `workflow_failed`.
- Activity-level audit emits events such as `activity_started`, `activity_succeeded`, and `activity_failed`.
- `sink_ref` points to a user-owned pack connection.
- `extras` evaluates expressions against workflow variables and attaches the result to the audit envelope.
- `emit_mode` controls whether emission is best-effort async or durable async.

## Workflow-Level Shape

```yaml
version: "3.0"
metadata:
  id: payment-process
  name: "Payment Process"
  dialect: vflow

  audit_log:
    enabled: true
    schema_version: "1.0"
    sink_ref: "pack://payment/audit-nats"
    subject: "company.payment.audit.workflow.v1"
    on:
      - workflow_started
      - workflow_succeeded
      - workflow_failed
    emit_mode: async_durable
    extras:
      tenant_id:
        language: v-cel
        source: "trigger_body.tenant_id"
      payment_amount_cents:
        language: v-cel
        source: "int(trigger_body.amount * 100)"
      iso_currency_code:
        language: v-cel
        source: "trigger_body.currency"
```

## Per-Activity Shape

```yaml
spec:
  activities:
    - id: charge_card
      activity_type: Connector
      connector_config:
        connector_ref: "pack://payment/stripe"
        operation: charge

      audit_log:
        enabled: true
        sink_ref: "pack://payment/audit-nats"
        subject: "company.payment.audit.activity.v1"
        on:
          - activity_succeeded
          - activity_failed
        extras:
          stripe_charge_id:
            language: v-cel
            source: "_last_output.charge_id"
          amount_charged_cents:
            language: v-cel
            source: "int(_last_output.amount * 100)"
```

## Fastpath Request Audit

When `trigger_config.runtime_mode: fastpath` is used, audit is request-level. VFlow emits
one envelope when the synchronous response path succeeds or fails.

Use this for gateway, scoring, and low-latency webhook paths where audit should
not add durable delivery work to the response path.

Fastpath rules:

- Declare `metadata.audit_log`, not activity-level `audit_log`.
- Use `emit_mode: async`.
- Do not use `delivery:` in fastpath.
- Use workflow events such as `workflow_succeeded` and `workflow_failed`.
- Use `_audit` in `extras` when you need bounded request counters.

```yaml
metadata:
  audit_log:
    enabled: true
    schema_version: "1.0"
    sink_ref: "pack://examples/risk-bench-audit/audit_nats"
    subject: "bench.risk.audit.fastpath.request.v1"
    on: [workflow_succeeded, workflow_failed]
    emit_mode: async
    extras:
      decision: { language: spv1, source: "$.risk_result.decision" }
      status: { language: spv1, source: "$._audit.status" }
      bytes_in: { language: spv1, source: "$._audit.bytes_in" }
      bytes_out: { language: spv1, source: "$._audit.bytes_out" }
      chunks_out: { language: spv1, source: "$._audit.chunks_out" }
      duration_ms: { language: spv1, source: "$._audit.duration_ms" }

spec:
  activities:
    - id: trigger
      activity_type: Trigger
      trigger_config:
        trigger_type: webhook
        runtime_mode: fastpath
        webhook_config: { path: /risk/score, method: POST }
```

For streaming workflows, `_audit.bytes_out` and `_audit.chunks_out` summarize
the forwarded response. The runtime does not audit every chunk and does not
buffer the stream for audit.

## Multi-Sink Shape

Use `sinks` when audit events must be delivered to more than one destination.

```yaml
metadata:
  audit_log:
    enabled: true
    schema_version: "1.0"
    on: [workflow_started, workflow_succeeded, workflow_failed]
    sinks:
      - sink_ref: "pack://payment/audit-nats"
        subject: "company.payment.audit.workflow.v1"
      - sink_ref: "pack://payment/audit-clickhouse"
        table: workflow_audit_events
```

## Field Reference

| Field | Type | Required | Notes |
|---|---|---|---|
| `enabled` | bool | no | Enables audit emission for this scope. |
| `schema_version` | string | recommended | Audit envelope schema version. |
| `sink_ref` | string | yes for single sink | Pack-scoped connection reference, usually `pack://<pack>/<connection>`. |
| `sinks` | array | no | Multiple sink declarations. |
| `subject` | string | connector-dependent | NATS or broker subject. |
| `table` | string | connector-dependent | Database or analytics table. |
| `on` | array | yes | Lifecycle events to emit. |
| `emit_mode` | string | no | `async` or `async_durable`. |
| `extras` | object | no | Extra fields computed from expressions. |
| `data_classification` | object | no | Classification hints such as PII, PCI, PHI, and legal basis. |
| `required_region` | string | no | Region residency requirement for the sink. |
| `delivery` | object | no | Retry, DLQ, batching, deduplication, and timeout policy. |

## Lifecycle Events

| Event | Scope | Meaning |
|---|---|---|
| `workflow_started` | workflow | Emitted when a workflow execution starts. |
| `workflow_succeeded` | workflow | Emitted when execution reaches a successful terminal state. |
| `workflow_failed` | workflow | Emitted when execution fails. |
| `activity_started` | activity | Emitted when an activity starts. |
| `activity_succeeded` | activity | Emitted when an activity completes successfully. |
| `activity_failed` | activity | Emitted when an activity fails. |

## Audit Envelope

Audit envelopes follow a CloudEvents-style shape:

```json
{
  "specversion": "1.0",
  "id": "evt_01h...",
  "source": "vflow://runtime/workflows/payment-process",
  "type": "vflow.workflow.succeeded",
  "subject": "company.payment.audit.workflow.v1",
  "time": "2026-05-01T10:00:00Z",
  "datacontenttype": "application/json",
  "data": {
    "workflow_id": "payment-process",
    "execution_id": "exec_01h...",
    "tenant_id": "tenant_acme",
    "payment_amount_cents": 125000,
    "iso_currency_code": "IDR"
  }
}
```

## Delivery Policy

```yaml
audit_log:
  enabled: true
  sink_ref: "pack://payment/audit-nats"
  subject: "company.payment.audit.workflow.v1"
  emit_mode: async_durable
  delivery:
    max_attempts: 8
    timeout_ms: 3000
    backoff:
      initial_ms: 100
      max_ms: 5000
      multiplier: 2.0
    dlq:
      sink_ref: "pack://payment/audit-dlq"
      subject: "company.payment.audit.dlq.v1"
    dedup:
      key:
        language: v-cel
        source: "execution_id + ':' + event_type"
```

## Multi-Channel Audit

Use channels to split audit traffic by purpose.

```yaml
metadata:
  audit_log:
    enabled: true
    channels:
      compliance:
        sink_ref: "pack://audit/compliance"
        subject: "company.audit.compliance.v1"
        on: [workflow_started, workflow_succeeded, workflow_failed]
      trace:
        sink_ref: "pack://audit/trace"
        subject: "company.audit.trace.v1"
        on: [activity_started, activity_succeeded, activity_failed]
      business:
        sink_ref: "pack://audit/business"
        subject: "company.audit.business.v1"
        on: [workflow_succeeded]
```

## Validation Rules

- `sink_ref` must point to a pack-scoped user connection.
- Workflow-level events belong under `metadata.audit_log`.
- Activity-level events belong under the activity object.
- Fastpath only supports request-level workflow audit with `emit_mode: async`.
- `extras` expressions should be deterministic and should avoid secrets.
- `required_region` and `data_classification` should match the sink's policy.
- Use `async_durable` when audit delivery must survive runtime restart.

## Worked Example

```yaml
version: "3.0"
metadata:
  id: onboarding-flow
  dialect: vflow
  audit_log:
    enabled: true
    schema_version: "1.0"
    sink_ref: "pack://ops/audit-nats"
    subject: "company.onboarding.audit.workflow.v1"
    on: [workflow_started, workflow_succeeded, workflow_failed]
    emit_mode: async_durable
    extras:
      customer_id:
        language: v-cel
        source: "trigger_body.customer_id"

spec:
  activities:
    - id: trigger
      activity_type: Trigger
      trigger_config:
        trigger_type: webhook
        webhook_config: { path: /onboarding, method: POST }
        end_activity: respond
      output_variable: trigger_payload

    - id: create_account
      activity_type: Connector
      connector_config:
        connector_ref: "pack://crm/accounts"
        operation: create
      audit_log:
        enabled: true
        sink_ref: "pack://ops/audit-nats"
        subject: "company.onboarding.audit.activity.v1"
        on: [activity_succeeded, activity_failed]
      output_variable: account

    - id: respond
      activity_type: EndTrigger
      end_trigger_config:
        trigger_ref: trigger
        final_response:
          language: v-cel
          source: '{"ok": true, "account_id": account.id}'

  flows:
    - { id: f1, from: { node: trigger }, to: { node: create_account } }
    - { id: f2, from: { node: create_account }, to: { node: respond } }
```
