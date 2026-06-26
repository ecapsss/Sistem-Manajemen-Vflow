# 023 Human Approval Event Gateway

High-value order review example for runtime-local operator flows.

It demonstrates:

- webhook intake and payload validation
- HumanTask parking for manual approval
- EventGateway wait/resume from an external fraud signal
- Signal cancellation branch for rejected fraud signals
- statestore-facing `persistence: ssot` annotations for operator decisions

The live smoke starts a real `vflow-server`, sends a high-value order, completes
the parked HumanTask through the admin API, fires the fraud-cleared event, and
asserts the final HTTP response.

```bash
VFLOW_EXAMPLES_WITH_HUMAN_APPROVAL_LIVE=1 \
  bash examples-vflow/run-all-local.sh
```
