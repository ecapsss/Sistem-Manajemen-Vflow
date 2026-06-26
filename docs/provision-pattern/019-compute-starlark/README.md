# 019 Compute/Starlark

Scope: local compile contract plus runtime-ready workflow shape.

This example documents the public `activity_type: Compute` authoring surface
for hand-written Starlark/V-Starlark compute. It keeps the workflow
side-effect-free so it can stay in the default examples regression runner.

Expected behavior:

- The webhook receives a JSON body containing `subtotal` and `tiers`.
- `pricing` maps those values into the Compute `ctx` dict.
- The Starlark `run(ctx)` function chooses the matching discount tier and
  returns a quote object.
- `respond` returns the computed quote to the trigger.

Example input:

```json
{
  "subtotal": 1500,
  "tiers": [
    { "min": 500, "pct": 5 },
    { "min": 1000, "pct": 10 }
  ]
}
```

Expected compute result:

```json
{
  "base": 1500,
  "discount_pct": 10,
  "final_price": 1350
}
```
