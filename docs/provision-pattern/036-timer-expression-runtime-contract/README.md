# 036 Timer Transform Runtime Contract

Business story: a loyalty adjustment workflow calculates an order score, waits
for a short debounce window, then returns the computed routing decision. The
example exists to prove `activity_type: Transform` and `activity_type: Timer`
as runtime behavior, not only YAML compile coverage.

Covered surface:

- Webhook trigger and `EndTrigger` response.
- `Transform` activity with V-CEL mappings used by the final response.
- `Timer` activity with explicit `timer_config.delay_ms`.
- Runtime-local smoke assertion through `vflow-server`.

Run:

```bash
VFLOW_EXAMPLES_WITH_TIMER_EXPRESSION_LIVE=1 bash examples-vflow/run-all-local.sh
```

Focused:

```bash
bash examples-vflow/runtime-smoke/timer-expression-runtime-smoke.sh
```

Expected response:

```json
{
  "status": "timer_expression_ok",
  "customer_id": "cust_036",
  "score": 75,
  "priority": "standard",
  "timer_delay_ms": 25
}
```
