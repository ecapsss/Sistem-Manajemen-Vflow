# 051 Fastpath V-Rule Risk Scoring Blocking

This benchmark uses the same payment risk decision and audit-record work as
`050`, but the audit transform stays on the response path.

Use it to measure how much latency is saved by detaching post-decision audit
work in `050`.

Latest reference run with Vastar Bench, 5000 requests, concurrency 256:

| Scenario | RPS | Avg | P50 | P95 | P99 | Errors |
|---|---:|---:|---:|---:|---:|---:|
| `050` detached audit | 82,163.24 | 2.7ms | 2.55ms | 5.03ms | 6.99ms | 0 |
| `051` blocking audit | 53,793.46 | 4.4ms | 4.37ms | 7.53ms | 9.31ms | 0 |

Report: `benchmark-vflow/reports/detach-worker-queue-047-050-051-20260502T202903/`.
