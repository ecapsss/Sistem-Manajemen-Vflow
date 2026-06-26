# Compute Activity — Starlark-Compatible Logic

Use a Compute activity when a workflow needs custom logic that is too large for a one-line Transform expression and too procedural for a decision table.

Compute supports Starlark-compatible scripts. In the VFlow dialect, `v-starlark` is the performance-oriented runtime surface. In the VIL OSS direction, `starlark` is the portable Starlark-compatible surface.

## When To Use Compute

| Need | Use |
|---|---|
| One expression or field mapping | V-CEL Transform |
| Decision tables or scoring rules | VRule / VDICL |
| Loops, algorithms, custom functions, multi-step shaping | Compute |
| External IO | Connector |

## YAML Shape

```yaml
- id: compute_price
  activity_type: Compute
  compute_config:
    language: v-starlark
    entry: run
    timeout_ms: 5000
    source: |
      def run(ctx):
          subtotal = ctx["subtotal"]
          vip = ctx.get("vip", False)
          discount = 0.15 if vip else 0.05
          return {
              "subtotal": subtotal,
              "discount": discount,
              "final_price": subtotal * (1.0 - discount),
          }
  input_mappings:
    - target: subtotal
      source: { language: spv1, source: "$.cart.subtotal" }
    - target: vip
      source: { language: v-cel, source: "customer.tier == 'vip'" }
  output_variable: pricing
```

## Fields

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `language` | string | yes | — | `starlark` or `v-starlark`. See **Engine selection** below. |
| `entry` | string | no | `run` | Function name called by the runtime. Often spelled `entry_fn`. |
| `source` | string | yes | — | Script source. |
| `timeout_ms` | integer | no | runtime default | Execution timeout (wall clock). |
| `budget_profile` | string | no | `default` | `none` \| `default` \| `balanced` \| `heavy`. Controls instruction + allocation budget. `none` disables cap (use only for trusted workflows). |
| `vdicl_rule` | object | no | — | Optional VRule pack reference for rule-assisted compute logic. |

The entry function receives a JSON-like `ctx` object built from `input_mappings` and returns a JSON-like value.

### Engine selection

Two engines are wired (verified in `crates/`):

| `language:` | Engine crate | Use when |
|---|---|---|
| `starlark` | `starkit_eval` (thin wrapper around upstream `starlark-rust`) | Spec-pure portable Starlark; no extensions, no PreparedModule cache. Default for VIL OSS workflows, baseline parity for VFlow workflows that don't need the optimized path. |
| `v-starlark` | `vstark_compiler` + `vstark_runtime` (`PreparedModule` + opcode VM + budget enforcement) | VFlow performance-tier compute; cold-start parse cost amortized via prepared bytecode, budget enforcement at instruction + allocation layers, `BudgetConfig::from_profile` selectable. Used by `048-fastpath-vstarlark-risk-scoring`, `063-vflow-gateway-vstarlark`. |

Spec-compliant code switches between the two with **zero behavior diff** — V-Starlark only adds extensions on top of upstream Starlark semantics, and the `vstark_compiler::lint` cross-engine router suggests V-CEL / VDICL / SPV1 alternatives when patterns would be better expressed in another engine.

## Calling VRule From Compute

V-Starlark can use VRule for structured decisions and then continue with custom logic.

```yaml
- id: score_policy
  activity_type: Compute
  compute_config:
    language: v-starlark
    entry: run
    vdicl_rule:
      rule_set_id: payment_risk_v2
      rule_pack: "compiled/payment_risk_v2.vdicl"
      eval_mode: bytecode
    source: |
      def run(ctx):
          decision = ctx["rule_result"]["outputs"]["decision"]
          base = ctx["amount"]
          if decision == "manual_review":
              return {"route": "review", "hold_amount": base}
          return {"route": "auto", "hold_amount": 0}
  input_mappings:
    - target: amount
      source: { language: v-cel, source: "trigger_payload.body.amount" }
  output_variable: policy_route
```

Use this pattern when rules define the business decision and Compute adds orchestration-specific shaping, scoring, or routing.

## Return Values

Compute can return scalars, arrays, or objects:

```python
def run(ctx):
    return {
        "customer_id": ctx["customer_id"],
        "flags": ["vip", "manual_review"],
        "score": 91,
        "approved": False,
    }
```

The returned value is bound to `output_variable`.

## Determinism Guidance

- Keep Compute logic deterministic for retry and replay-friendly workflows.
- Pass time, random values, request IDs, and external data through inputs instead of generating them inside Compute.
- Use Connector activities for external IO.
- Use VRule for business decisions that need explainable findings.

## Complete Example

```yaml
version: "3.0"
metadata:
  id: compute-pricing
  dialect: vflow

spec:
  activities:
    - id: trigger
      activity_type: Trigger
      trigger_config:
        trigger_type: webhook
        webhook_config: { path: /pricing, method: POST }
        end_activity: respond
      output_variable: trigger_payload

    - id: price
      activity_type: Compute
      compute_config:
        language: v-starlark
        entry: run
        source: |
          def run(ctx):
              subtotal = ctx["subtotal"]
              tier = ctx.get("tier", "standard")
              discount = 0.2 if tier == "enterprise" else 0.05
              return {
                  "subtotal": subtotal,
                  "discount": discount,
                  "final_price": subtotal * (1.0 - discount),
              }
      input_mappings:
        - target: subtotal
          source: { language: v-cel, source: "trigger_payload.body.subtotal" }
        - target: tier
          source: { language: v-cel, source: "trigger_payload.body.tier" }
      output_variable: pricing

    - id: respond
      activity_type: EndTrigger
      end_trigger_config:
        trigger_ref: trigger
        final_response:
          language: v-cel
          source: '{"ok": true, "pricing": pricing}'

  flows:
    - { id: f1, from: { node: trigger }, to: { node: price } }
    - { id: f2, from: { node: price }, to: { node: respond } }
```
