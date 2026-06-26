# 050 Fastpath V-Rule Risk Scoring Detached

This benchmark keeps the payment risk decision on the synchronous response
path and moves audit-record construction to a detached background branch.

It is paired with:

- `047-fastpath-vrule-risk-scoring`: same V-Rule decision without an audit branch.
- `051-fastpath-vrule-risk-scoring-blocking`: same audit branch but blocking the response path.

```bash
SCENARIOS="047-fastpath-vrule-risk-scoring 050-fastpath-vrule-risk-scoring-detached 051-fastpath-vrule-risk-scoring-blocking" \
TOOLS="vastar wrk" \
MODE=requests \
REQUESTS=5000 \
bash benchmark-vflow/run-primary.sh
```

Latest reference run:

| Scenario | RPS | Avg | P50 | P95 | P99 | Errors |
|---|---:|---:|---:|---:|---:|---:|
| `047` no audit branch | 86,778.90 | 2.5ms | 2.42ms | 4.37ms | 6.19ms | 0 |
| `050` detached audit | 82,163.24 | 2.7ms | 2.55ms | 5.03ms | 6.99ms | 0 |
| `051` blocking audit | 53,793.46 | 4.4ms | 4.37ms | 7.53ms | 9.31ms | 0 |

Report: `benchmark-vflow/reports/detach-worker-queue-047-050-051-20260502T202903/`.
The detached branch preserves most of the response-path throughput while the
same audit work blocks the response path in `051`.
