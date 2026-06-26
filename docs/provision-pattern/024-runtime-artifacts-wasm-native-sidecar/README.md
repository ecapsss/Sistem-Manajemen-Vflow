# 024 Runtime Artifacts WASM Native Sidecar

Pricing example for runtime-local artifact controls and handler invocation.

It demonstrates:

- `Function`/WASM invocation shape
- `NativeCode` invocation shape
- real `Sidecar` invocation through a registered Python sidecar process
- artifact registration remains runtime-local and is not proxied by
  vflow-cloud

The live smoke registers the sidecar against a real `vflow-server`, triggers
the pricing workflow, and asserts the sidecar-computed final price. WASM/native
plugin binaries remain optional because portable real binaries are handled by
the runtime-console artifact E2E harness.

```bash
VFLOW_EXAMPLES_WITH_ARTIFACTS_LIVE=1 \
  bash examples-vflow/run-all-local.sh
```
