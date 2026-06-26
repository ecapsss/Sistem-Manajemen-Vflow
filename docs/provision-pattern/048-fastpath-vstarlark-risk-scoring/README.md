# 048 Fastpath V-Starlark Risk Scoring

Stateless benchmark workflow for the same payment risk decision implemented in
`047-fastpath-vrule-risk-scoring`, but using `Compute` with
`language: v-starlark` on `spec.runtime.mode: fastpath`.

The input payload, business rule order, decision semantics, and response shape
are intentionally aligned with the V-Rule example so the benchmark compares
workflow E2E engine behavior instead of different business workloads.

```bash
SCENARIOS="048-fastpath-vstarlark-risk-scoring" \
TOOLS="vastar wrk" \
MODE=requests \
REQUESTS=5000 \
bash benchmark-vflow/run-primary.sh
```
