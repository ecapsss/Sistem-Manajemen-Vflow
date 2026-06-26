# 046 Runtime Console Action Blackbox

Real-server operator smoke for runtime-local execution actions:

- route pause/resume affects real HTTP dispatch
- `Retry` re-triggers persisted input against the current active version
- `Replay` pins persisted input to an explicit workflow version
- `Cancel` writes the durable marker and asks the live kernel to stop at a
  cooperative node/IO boundary

Run:

```bash
bash examples-vflow/runtime-smoke/runtime-console-action-blackbox-smoke.sh
```

Expected signal:

```text
RUNTIME_CONSOLE_ACTION_BLACKBOX_SMOKE_OK
```
