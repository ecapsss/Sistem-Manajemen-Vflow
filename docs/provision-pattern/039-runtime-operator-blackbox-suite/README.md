# 039 Runtime Operator Blackbox Suite

This is a P0 suite wrapper for runtime-local operator flows that must be tested
from outside a real `vflow-server` process.

The suite currently covers:

- HumanTask + EventGateway live operator approval.
- HumanTask/EventGateway live-token resume after `kill -9` and server restart.
- Versioning, canary, shadow, promote, and rollback runtime controls.

Run:

```bash
bash examples-vflow/runtime-smoke/runtime-operator-blackbox-suite-smoke.sh
```

Expected final signal:

```text
RUNTIME_OPERATOR_BLACKBOX_SUITE_OK
```

The suite is not part of the default `run-all-local.sh` because it runs multiple
stateful real-server operator scenarios. Use
`VFLOW_EXAMPLES_WITH_OPERATOR_BLACKBOX=1 bash examples-vflow/run-all-local.sh`
when an operator-level local sign-off is needed.
