# VDICL Authoring Guide

This directory is the public authoring guide for VDICL rule packs.
It describes the language surface that authors should write and that
V-Rule tooling should generate.

The implementation source of truth is the VFlow VDICL compiler, runtime,
schema model, and rule-pack FlatBuffer schema. This guide intentionally
keeps only the public authoring surface.

## Authoring Standard

Use plain YAML scalars for fields that contain rule text:

```yaml
description: Approve GOLD tier with a high limit
when: tier == "GOLD" AND approvedLimit > 10000
path: decision
```

Do not wrap the whole `when` expression in YAML quotes. Quotes belong
inside the expression only when the expression needs a string literal.

For action values, use quotes when the value itself is a string literal:

```yaml
value: "APPROVE"
```

Computed output must use `EVAL_SET_FIELD` and an unquoted expression:

```yaml
kind: EVAL_SET_FIELD
path: approvedLimit
expr: monthlyIncome * 12
```

## Documents

1. `01-authoring-style.md` - canonical YAML and expression style.
2. `02-rule-pack-yaml.md` - rule-pack structure and top-level fields.
3. `03-schema-and-fields.md` - field dictionary and supported scalar kinds.
4. `04-expressions-and-operators.md` - expression grammar, precedence, and operators.
5. `05-literals-and-values.md` - numbers, booleans, null, strings, lists, and contexts.
6. `06-functions.md` - public builtin function surface by category.
7. `07-actions-and-outputs.md` - rule actions, findings, decisions, and output fields.
8. `08-hit-policies.md` - hit policy, aggregation, and output conflict behavior.
9. `09-dmn-unary-tests.md` - DMN decision-table unary test syntax accepted by tooling.
10. `10-validation-and-runtime.md` - compile/runtime behavior that matters to authors.

## Minimal Rule Pack

```yaml
version: 1
decision_id: eligibility
decision_name: Eligibility Decision
hit_policy: UNIQUE
schema:
  inputs:
    - name: tier
      type: string
      expression: applicant.tier
    - name: approvedLimit
      type: number
      expression: applicant.approvedLimit
  outputs:
    - name: decision
      type: string
rules:
  - id: r_gold_high_limit
    description: Approve GOLD tier with approved limit above 10000
    when: tier == "GOLD" AND approvedLimit > 10000
    then:
      - kind: SET_FIELD
        path: decision
        value: "APPROVE"
  - id: r_default_review
    description: Review all cases not matched by a specific rule
    when: true
    then:
      - kind: SET_FIELD
        path: decision
        value: "REVIEW"
```
