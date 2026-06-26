# 058 Fastpath V-Rule Risk Scoring Detached NATS Publish

Fastpath payment risk scoring with **user-authored** detached NATS publish
for the audit event. Same V-Rule pack, mappings, request payload, and
response shape as `047-fastpath-vrule-risk-scoring`. The detached branch
runs `Transform → Connector(vastar.nats:publish)` to materialize and
publish a plain-JSON business event.

## Why this exists

`056-fastpath-vrule-risk-scoring-audit-log` and `058` are both
fastpath workflows that publish a NATS event for every successful
request. They differ in mechanism:

| Aspect                 | 056 (framework)                          | 058 (this example, user)                 |
|------------------------|------------------------------------------|------------------------------------------|
| Trigger                | `metadata.audit_log` block               | Detached edge → Transform → Connector    |
| Pipeline               | `vflow_audit_sinks::nats::NatsEmitter`   | Workflow `Connector` activity            |
| Envelope               | CloudEvents Binary Mode (`ce-*` headers) | Plain JSON                               |
| Server-side dedup      | Yes (`Nats-Msg-Id = ce-id`)              | No                                       |
| Schema metadata        | `schema_version`, `schema_compat`, etc.  | None                                     |
| Resolver               | `SinkPackResolver`                       | Connector registry                       |
| `_audit` snapshot      | Auto-populated (status/bytes/duration)   | Not present                              |

Use 056 vs 058 to measure the cost difference between the framework
audit emitter pipeline (envelope wrapping, dedup, sink resolver) and a
user-authored detached business-event publish — both on fastpath, both
landing on NATS.

The closest standard-runtime analog is `055-standard-vrule-risk-scoring-detached-nats-publish`,
which uses the same user-authored detached pattern but on the standard
runtime path. Compare 058 vs 055 to isolate the standard-vs-fastpath
delta with the same audit pipeline shape.

## Reproduce

```bash
VFLOW_NATS_URL=nats://127.0.0.1:4222 \
SCENARIOS="047-fastpath-vrule-risk-scoring 056-fastpath-vrule-risk-scoring-audit-log 058-fastpath-vrule-risk-scoring-detached-nats-publish" \
TOOLS="vastar wrk" \
MODE=requests \
REQUESTS=5000 \
VFLOW_AUDIT_EMITTER=nats \
bash benchmark-vflow/run-primary.sh
```
