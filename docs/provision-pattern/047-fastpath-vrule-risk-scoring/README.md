# 047 Fastpath V-Rule Risk Scoring

Stateless benchmark workflow for V-Rule on `spec.runtime.mode: fastpath`.

The route accepts a payment risk payload, evaluates a preloaded VDICL rule pack
on the synchronous response path, and returns the rule decision directly from
`EndTrigger`. It is intended for blackbox webhook benchmark runs, not admin or
provision endpoint benchmarking.

```bash
SCENARIOS="047-fastpath-vrule-risk-scoring" \
TOOLS="vastar wrk" \
MODE=requests \
REQUESTS=5000 \
bash benchmark-vflow/run-primary.sh
```
