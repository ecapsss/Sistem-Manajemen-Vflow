# 038 Blackbox Local Trigger Suite

This is a P0 suite wrapper for public, local-safe trigger-to-output examples.
It intentionally calls workflows from outside the runtime through their real
trigger surface instead of invoking compiler or kernel internals.

The suite currently covers:

- Business webhook workflows `020`-`022`.
- Email receive/send mock path `034`.
- Timer + Transform runtime contract `036`.
- Descriptor-backed gRPC unary connector contract `037`.
- Portable WASM workflow invocation `040`.
- Portable NativeCode workflow invocation `041`.

Run:

```bash
bash examples-vflow/runtime-smoke/blackbox-local-trigger-suite-smoke.sh
```

Expected final signal:

```text
BLACKBOX_LOCAL_TRIGGER_SUITE_OK
```

The suite is not part of the default `run-all-local.sh` because it boots several
real `vflow-server` instances. Use
`VFLOW_EXAMPLES_WITH_BLACKBOX_LOCAL=1 bash examples-vflow/run-all-local.sh`
when a full trigger-level local sign-off is needed.
