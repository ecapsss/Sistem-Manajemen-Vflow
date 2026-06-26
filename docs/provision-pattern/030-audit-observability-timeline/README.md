# 030 Audit Observability Timeline

Scenario: an incident-response workflow emits audit envelopes while the
operator timeline merges runtime state, checkpoints, cancel/retry actions,
HumanTask/EventGateway park state, and audit backends.

The workflow YAML demonstrates the author-facing `metadata.audit_log` and
per-activity `audit_log` declarations. The smoke script validates the concrete
timeline adapter surface that the runtime console uses:

```bash
bash examples-vflow/runtime-smoke/audit-observability-timeline-smoke.sh
```

Adapter coverage:

- JSONL audit-envelope timeline source.
- ClickHouse HTTP source with named tenant/execution parameters.
- Runtime console timeline merge tests.

Operational boundary: the audit dashboard is runtime-local. vflow-cloud may
handoff the user to the runtime console, but it must not proxy this workflow
timeline traffic.
