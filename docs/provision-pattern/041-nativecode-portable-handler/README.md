# 041 NativeCode Portable Handler

Business story: an enterprise tenant installs a small native pricing handler as
a runtime-local plugin. The workflow invokes it through `activity_type:
NativeCode` and returns the handler output.

Covered surface:

- `activity_type: NativeCode` with `code_config.handler_ref`.
- Auto-provisioning from `VFLOW_PLUGIN_DIR`.
- Real `.so` plugin ABI: `vflow_plugin_name`, `vflow_plugin_execute`,
  `vflow_plugin_free`.
- Trigger-to-output blackbox smoke.

Run:

```bash
bash examples-vflow/runtime-smoke/nativecode-portable-handler-smoke.sh
```

Expected response:

```json
{
  "status": "native_pricing_ok",
  "engine": "nativecode",
  "base_price_cents": 2000,
  "discount_bps": 1250,
  "final_price_cents": 1750
}
```
