# 056 Fastpath V-Rule Risk Scoring Audit Log

Fastpath payment risk scoring with request-level `metadata.audit_log`.
This keeps the same request payload, V-Rule pack, mappings, and response
shape as `047-fastpath-vrule-risk-scoring`, then emits one audit envelope per
HTTP request after the response path completes.

This fixture validates the fastpath audit rule: audit is request-scoped,
async, fail-open, and does not emit per response chunk.

```bash
VFLOW_NATS_URL=nats://127.0.0.1:4222 \
SCENARIOS="047-fastpath-vrule-risk-scoring 056-fastpath-vrule-risk-scoring-audit-log" \
TOOLS="vastar wrk" \
MODE=requests \
REQUESTS=5000 \
CONCURRENCY=256 \
bash benchmark-vflow/run-primary.sh
```
