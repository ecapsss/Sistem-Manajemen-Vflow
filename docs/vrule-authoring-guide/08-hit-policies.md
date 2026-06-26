# 08 - Hit Policies

`hit_policy` controls how matching rules are selected and executed.

## Supported Policies

| Policy | Behavior |
|---|---|
| `FIRST` | First matching rule wins. This is the default. |
| `UNIQUE` | At most one rule should match. Multiple matches are a logic error. |
| `COLLECT` | All matching rules execute. |
| `PRIORITY` | Rules are ordered by priority and the first matching priority wins. |
| `ANY` | Matching rules must agree on each output field. |
| `RULE_ORDER` | Matching rules execute in document order. |
| `OUTPUT_ORDER` | Accepted for DMN output-order compatibility; runtime dispatch is deterministic document order. |

## FIRST

```yaml
hit_policy: FIRST
rules:
  - id: r_preferred
    description: Preferred customer
    when: tier == "GOLD"
    then:
      - kind: SET_FIELD
        path: decision
        value: "APPROVE"
  - id: r_fallback
    description: Fallback
    when: true
    then:
      - kind: SET_FIELD
        path: decision
        value: "REVIEW"
```

## UNIQUE

Use `UNIQUE` when the rule set is designed so only one rule can match.

```yaml
hit_policy: UNIQUE
```

Overlapping conditions should be fixed at authoring time.

## COLLECT

Use `COLLECT` when multiple findings or outputs are expected.

```yaml
hit_policy: COLLECT
aggregate_fn: LIST
```

Supported aggregate functions:

```text
LIST, SUM, MIN, MAX, COUNT
```

## Output Conflict Policy

`output_conflict_policy` controls what happens when multiple matching
rules write different values to the same output path.

```yaml
output_conflict_policy: LWW
```

`LWW` means last write wins. `STRICT` raises an output conflict when
matching rules disagree:

```yaml
output_conflict_policy: STRICT
```

`ANY` is equivalent to collect-style agreement checking for output
fields.

## Priority

`priority` is a signed integer on each rule:

```yaml
hit_policy: PRIORITY
rules:
  - id: r_high_priority
    priority: 1
    description: Highest priority branch
    when: risk == "LOW"
    then:
      - kind: SET_FIELD
        path: decision
        value: "APPROVE"
```

Use explicit priority only when the business rule really depends on
priority ordering.
