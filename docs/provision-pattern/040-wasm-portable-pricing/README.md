# 040 WASM Portable Pricing

Business story: an order workflow calls a tenant-provided WASM pricing module.
The module is compiled for WASI and reads JSON from stdin, then writes JSON to
stdout. This makes the example portable and runtime-local.

Covered surface:

- `activity_type: Function` with `wasm_config`.
- Auto-provisioning from `VFLOW_WASM_DIR`.
- WASI stdin/stdout invocation through the real runtime worker pool.
- Trigger-to-output blackbox smoke.

Run:

```bash
bash examples-vflow/runtime-smoke/wasm-portable-pricing-smoke.sh
```

Expected response:

```json
{
  "status": "wasm_pricing_ok",
  "engine": "wasm",
  "base_price_cents": 1500,
  "discount_bps": 1000,
  "final_price_cents": 1350
}
```
