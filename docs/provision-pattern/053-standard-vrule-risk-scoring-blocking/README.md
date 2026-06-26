# 053 Standard V-Rule Risk Scoring Blocking

This benchmark mirrors `052`, but the audit transform is kept on the response
path. It provides the standard-runtime comparison point for detached vs
non-detached post-decision work.

Latest reference run with Vastar Bench, 5000 requests, concurrency 256:

| Scenario | RPS | Avg | P50 | P95 | P99 | Errors |
|---|---:|---:|---:|---:|---:|---:|
| `052` detached audit | 6,230.97 | 40.7ms | 41.39ms | 74.44ms | 84.11ms | 0 |
| `053` blocking audit | 5,345.00 | 47.5ms | 48.53ms | 75.97ms | 87.14ms | 0 |

Report: `benchmark-vflow/reports/standard-detach-052-053-20260502T203528/`.
