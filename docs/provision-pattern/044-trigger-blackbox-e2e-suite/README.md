# 044 Trigger Blackbox E2E Suite

Suite marker for trigger-first blackbox validation. The runner executes public
examples from outside the process, starts a real `vflow-server` where needed,
and validates trigger-to-workflow-to-side-effect behavior.

Run:

```bash
bash examples-vflow/runtime-smoke/trigger-blackbox-e2e-suite.sh
```

Optional provider-backed labs are controlled by the underlying smoke scripts;
use `VFLOW_043_BOOTSTRAP=heavy` when Kafka and S3/SQS local labs should be
started automatically.
