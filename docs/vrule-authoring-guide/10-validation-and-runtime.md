# 10 - Validation And Runtime

This document summarizes behavior that authors need to understand when
a rule pack is compiled and evaluated.

## Compile-Time Checks

The compiler parses each rule's `when` field as a VDICL expression:

```yaml
when: tier == "GOLD" AND approvedLimit > 10000
```

Field references must resolve to the schema dictionary. Unknown field
references are compile errors.

`EVAL_SET_FIELD.expr` is also parsed and bound as an expression:

```yaml
expr: monthlyIncome * 12
```

`SET_FIELD.value` is not parsed as an expression. It is a literal value
field:

```yaml
value: "APPROVE"
```

## Runtime Result Envelope

The runtime can produce different output modes. The common decision
envelope includes:

| Field | Meaning |
|---|---|
| `decision` | Decision text such as `ACCEPT`, `REJECT`, or `REVIEW`. |
| `total_score` | Accumulated score from `ADD_SCORE`. |
| `findings_count` | Number of findings or helper requests surfaced. |
| `out` | Materialized fields written by `SET_FIELD` or `EVAL_SET_FIELD`. |

Diagnostic modes may include full findings, reasons, matched rule
counts, and runtime details.

## Null Behavior

Many builtins return `null` when an input is `null`. Write explicit
fallbacks for business-critical comparisons:

```yaml
when: COALESCE(monthlyIncome, 0) >= 5000000
```

## String Behavior

Use double quoted expression literals for authoring:

```yaml
when: tier == "GOLD"
```

Single quoted expression strings are accepted by the compiler and are
canonicalized as symbolic text. That can be useful for compatibility,
but public authored packs should use double quoted expression literals
for string values.

## Disabled Rules

Rules default to enabled. A disabled rule is skipped:

```yaml
enabled: false
```

## Stable Fallback Rule

Every decision rule pack should have an explicit fallback unless the
business policy intentionally returns no decision when nothing matches:

```yaml
- id: r_default_review
  description: Review all cases not matched by a specific rule
  when: true
  then:
    - kind: SET_FIELD
      path: decision
      value: "REVIEW"
```

## Recommended Validation Flow

1. Parse YAML.
2. Validate rule-pack shape.
3. Bind expressions against schema.
4. Compile to runtime pack.
5. Run representative test cases.
6. Review diagnostics before publishing.

Authoring tools and AI assistants should follow the same flow before
offering an apply or publish action.
