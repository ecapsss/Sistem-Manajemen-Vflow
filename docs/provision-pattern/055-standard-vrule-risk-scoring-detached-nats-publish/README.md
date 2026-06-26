# 055 Standard V-Rule Risk Scoring Detached NATS Publish

Standard-mode payment risk scoring with direct detached NATS publish for the
audit event. This uses the same request payload, V-Rule pack, mappings, and
response shape as `049-standard-vrule-risk-scoring`, then sends the materialized
decision event from a detached branch through `vastar.nats:publish`.

Use this fixture to compare direct business-event publish against
`metadata.audit_log` emission in example `054`.

```bash
VFLOW_NATS_URL=nats://127.0.0.1:4222 \
SCENARIOS="049-standard-vrule-risk-scoring 054-standard-vrule-risk-scoring-audit-log 055-standard-vrule-risk-scoring-detached-nats-publish" \
TOOLS="vastar wrk" \
MODE=requests \
REQUESTS=5000 \
CONCURRENCY=256 \
bash benchmark-vflow/run-primary.sh
```
