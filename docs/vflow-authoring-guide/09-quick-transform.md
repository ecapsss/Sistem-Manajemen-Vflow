# VWFD YAML — `quick_transform` and SPv1

`quick_transform` is a lightweight output shaper that can be attached to any activity. It runs after an activity emits data and before the output is bound to `output_variable`.

Use it when you need to extract, filter, or reshape output without adding a dedicated Transform activity.

## Where It Runs

```yaml
activities:
  - id: fetch
    activity_type: Connector
    connector_config:
      connector_ref: http
      operation: POST
    quick_transform:
      select: "$.choices[0].delta.content"
      filter: "$[?(@.finish_reason == null)]"
      on_empty: drop
    output_variable: model_text
```

## YAML Shape

| Field | Type | Required | Default | Semantics |
|---|---|---|---|---|
| `select` | string | yes | — | SPv1 selector evaluated against the activity output. |
| `filter` | string | no | — | SPv1 predicate evaluated after selection. |
| `on_empty` | string | no | `drop` | What to do when `select` misses or `filter` rejects. |

## `on_empty`

| Value | Behavior |
|---|---|
| `drop` | Skip the emission. Downstream receives no event for this item or chunk. |
| `pass` | Emit the original pre-transform payload. |
| `error` | Surface an error to the workflow runtime. |

## Execution Modes

| Mode | Triggered By | Use Case |
|---|---|---|
| Leaf scan | Simple dot-path selectors such as `choices[0].delta.content` | Hot streaming paths where the payload shape is known. |
| SPv1 VM | Selectors using `$`, wildcard, filters, slices, unions, or relative paths | General JSON-like extraction and filtering. |

## SPv1 Path Syntax

| Syntax | Semantics |
|---|---|
| `$` | Root document. |
| `$.foo` | Object field access. |
| `$.foo.bar` | Nested field access. |
| `$['a']` | Quoted key access. |
| `$[0]` | Array index. |
| `$[*]` | Array wildcard. |
| `$.*` | Object wildcard. |
| `$[1:5]` | Slice. |
| `$[0:10:2]` | Slice with step. |
| `$['a','b']` | Union of keys. |
| `$[0,3,99]` | Union of indices. |

## Filter Predicates

Inside a filter, `@` refers to the current item.

| Syntax | Example |
|---|---|
| `@` | `[?(@)]` |
| `@.field` | `[?(@.active == true)]` |
| `@.nested.path` | `[?(@.meta.active)]` |
| Comparisons | `[?(@.price > 100)]` |
| Logical AND | `[?(@.active && @.verified)]` |
| Logical OR | `[?(@.vip \|\| @.priority)]` |
| Logical NOT | `[?(!@.disabled)]` |

## Filter Functions

| Function | Semantics |
|---|---|
| `exists(@.field)` | True if a field resolves, including `null`. |
| `len(@.field)` | Length of a string, array, or object. |
| `to_number(@.field)` | Coerce numeric text to a number. |
| `to_string(@.field)` | Coerce a value to text. |

## Type Rules

- Missing fields evaluate to `null`.
- Cross-type equality is false.
- Ordered comparisons require comparable values.
- `null == null` is true.
- Wildcard ordering is deterministic.

## Streaming

For streaming connectors, `quick_transform` can run per chunk.

```yaml
connector_config:
  connector_ref: http
  operation: POST
  streaming: true
  format: sse
  json_tap: "choices[0].delta.content"
quick_transform:
  select: "$"
  on_empty: drop
```

Use connector-native `json_tap` for the fastest dialect-aware streaming extraction. Use `quick_transform` when you need predicates, activity-independent shaping, or the same syntax across activity types.

## Buffered Activity Output

For non-streaming activities, `quick_transform` runs once against the full output.

```yaml
- id: load_customer
  activity_type: Connector
  connector_config:
    connector_ref: postgres
    operation: find_one
  quick_transform:
    select: "$.rows[0]"
    on_empty: error
  output_variable: customer
```

## Examples

Extract one field:

```yaml
quick_transform:
  select: "$.data.customer_id"
```

Keep only active items:

```yaml
quick_transform:
  select: "$.items[*]"
  filter: "$[?(@.active == true)]"
```

Select first high-value item:

```yaml
quick_transform:
  select: "$.items[?(@.amount > 1000000)][0]"
  on_empty: pass
```

## When To Use It

| Need | Prefer |
|---|---|
| Extract one or a few fields from an activity output | `quick_transform` |
| Filter streaming chunks | `json_tap` plus `quick_transform.filter` |
| Create a new structured object from multiple variables | Transform activity with V-CEL |
| Implement custom algorithmic logic | Compute activity |
