# 059 Fastpath AI Gateway Stream Detached NATS Publish

AI gateway streaming with **user-authored** detached NATS publish for the
audit event. Same workflow shape as `057-fastpath-ai-gateway-stream-audit-summary`
on the response path (Trigger → streaming Connector → EndTrigger), but
the audit emit is performed by a user-authored detached branch
(Transform → Connector(vastar.nats:publish)) instead of the framework
`metadata.audit_log` pipeline.

## Why this exists

`057` and `059` are both fastpath stream workflows that publish a NATS
event for every successful streaming request. They differ in mechanism:

| Aspect              | 057 (framework)                                  | 059 (this example, user)                      |
|---------------------|--------------------------------------------------|-----------------------------------------------|
| Trigger             | `metadata.audit_log` block                       | Detached edge from `respond`                  |
| Pipeline            | `vflow_audit_sinks::nats::NatsEmitter`           | `Transform → Connector(vastar.nats:publish)`  |
| Envelope            | CloudEvents Binary Mode (`ce-*` headers)         | Plain JSON                                    |
| Server-side dedup   | Yes (`Nats-Msg-Id = ce-id`)                      | No                                            |
| Schema metadata     | `schema_version`, `schema_compat`, `channel`...  | None                                          |
| Resolver            | `SinkPackResolver`                               | Connector registry                            |
| Audit fields        | spv1 expressions evaluated by emitter            | v-cel expressions evaluated by Transform      |

Use 057 vs 059 to measure the cost difference between the framework
audit emitter pipeline (envelope wrapping, dedup, sink resolver) and a
user-authored detached business-event publish — both on fastpath stream,
both landing on NATS.

## Apple-to-apple matrix

| Comparison                           | Setup                          | What it isolates                         |
|--------------------------------------|--------------------------------|------------------------------------------|
| 047 vs 056 (transform / compute)     | fastpath compute, no audit vs framework | Framework cost on FAST response path |
| 047 vs 058 (transform / user)        | fastpath compute, no audit vs user      | User detached cost on fast path     |
| **018 vs 057 (stream / framework)**  | fastpath stream, no audit vs framework  | Framework cost on SLOW (I/O) path   |
| **018 vs 059 (stream / user)**       | fastpath stream, no audit vs user       | User detached cost on slow path     |

Together these four points map the cost of audit emit vs main-path
budget. Compute-bound: ~40% RPS hit (056). Stream/I/O-bound: a few
percent (057). User detached: near-zero overhead in both cases.

## Reproduce

```bash
VFLOW_NATS_URL=nats://127.0.0.1:4222 \
SCENARIOS="018-ai-gateway-simulator 057-fastpath-ai-gateway-stream-audit-summary 059-fastpath-ai-gateway-stream-detached-nats-publish" \
TOOLS="vastar wrk" \
MODE=requests \
REQUESTS=5000 \
VFLOW_AUDIT_EMITTER=nats \
bash benchmark-vflow/run-primary.sh
```
