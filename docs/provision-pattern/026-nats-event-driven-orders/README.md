# 026 NATS Event Driven Orders

Event-driven order workflow for runtime-local NATS integration.

It demonstrates:

- NATS trigger subscription
- NATS connector publish
- event envelope shaping with order status payloads
- skip-aware live smoke for developer/lab NATS brokers

```bash
VFLOW_EXAMPLES_WITH_NATS_WORKFLOW_LIVE=1 \
VFLOW_NATS_URL=nats://localhost:4222 \
  bash examples-vflow/run-all-local.sh
```

The live smoke requires a reachable broker and the `nats` CLI. If either is
missing, it reports `SKIP` unless strict mode is enabled.
