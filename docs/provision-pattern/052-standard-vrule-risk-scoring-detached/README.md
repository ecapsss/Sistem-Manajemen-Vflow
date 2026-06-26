# 052 Standard V-Rule Risk Scoring Detached

This benchmark mirrors `050` on the standard runtime path. The payment risk
decision returns through `EndTrigger`; audit-record construction is marked as a
detached branch.

Compare with `049-standard-vrule-risk-scoring` and
`053-standard-vrule-risk-scoring-blocking`.

Latest reference run with Vastar Bench, 5000 requests, concurrency 256:

| Scenario | RPS | Avg | P50 | P95 | P99 | Errors |
|---|---:|---:|---:|---:|---:|---:|
| `049` no audit branch | 6,568.03 | 38.7ms | 39.60ms | 71.41ms | 81.27ms | 0 |
| `052` detached audit | 6,230.97 | 40.7ms | 41.39ms | 74.44ms | 84.11ms | 0 |
| `053` blocking audit | 5,345.00 | 47.5ms | 48.53ms | 75.97ms | 87.14ms | 0 |

Reports:

- `benchmark-vflow/reports/standard-baseline-049-20260502T203602/`
- `benchmark-vflow/reports/standard-detach-052-053-20260502T203528/`
