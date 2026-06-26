# 049 Standard V-Rule Risk Scoring

Standard-mode benchmark workflow for the same payment risk decision used by
`047-fastpath-vrule-risk-scoring`.

This example intentionally reuses the same `fastpath_risk_v1` V-Rule pack,
request payload, field mappings, decision order, and response shape as example
047. The only behavioral difference is runtime mode: this workflow omits
`spec.runtime.mode`, so it runs through the default `standard` kernel path.

```bash
SCENARIOS="047-fastpath-vrule-risk-scoring 049-standard-vrule-risk-scoring" \
TOOLS="vastar wrk" \
MODE=requests \
REQUESTS=5000 \
CONCURRENCY=256 \
bash benchmark-vflow/run-primary.sh
```
