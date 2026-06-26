# 031 Versioning Canary Shadow Rollback

Scenario: a pricing workflow ships as v1, receives a v2 candidate, runs canary
and shadow routing, promotes v2, then rolls back to v1.

The live smoke starts a real `vflow-server`, uploads both YAML versions under a
single workflow id, and calls runtime-local admin APIs:

```bash
bash examples-vflow/runtime-smoke/versioning-canary-shadow-rollback-smoke.sh
```

Expected behavior:

- `workflow-v1.yaml` and `workflow-v2.yaml` upload as versions of
  `versioning-canary-shadow-rollback`.
- Canary split installs on `/examples/versioning/pricing`.
- Shadow mode installs v2 while v1 remains the client response path.
- Promotion activates v2.
- Rollback activates v1 again.
- History, diff, and shadow report endpoints return operator state.
- The HTTP route returns the expected versioned `pricing_engine` response
  across install, promote, and rollback.

This example intentionally documents current-version `Retry` semantics only.
Pinned-version `Replay` is a separate runtime-console action. This example
focuses on rollout controls; add a focused E2E action smoke when proposal docs
need direct UI proof for Replay.
