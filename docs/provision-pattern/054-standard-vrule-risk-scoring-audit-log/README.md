# 054 Standard V-Rule Risk Scoring Audit Log

Standard-mode payment risk scoring with workflow-level `metadata.audit_log`.
This keeps the same request payload, V-Rule pack, mappings, and response shape
as `049-standard-vrule-risk-scoring`, then emits one user-owned audit envelope
on `workflow_succeeded`. The envelope uses `audit_log.extras` to materialize
the decision, score, finding count, and selected request fields.

Use this fixture to compare baseline standard runtime cost against the
runtime audit emitter path.

```bash
VFLOW_NATS_URL=nats://127.0.0.1:4222 \
SCENARIOS="049-standard-vrule-risk-scoring 054-standard-vrule-risk-scoring-audit-log" \
TOOLS="vastar wrk" \
MODE=requests \
REQUESTS=5000 \
CONCURRENCY=256 \
bash benchmark-vflow/run-primary.sh
```
