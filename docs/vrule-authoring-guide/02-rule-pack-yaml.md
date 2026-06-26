# 02 - Rule Pack YAML

A VDICL rule pack is a YAML document containing rule metadata, optional
schema information for tools, hit policy configuration, and an ordered
list of rules.

## Public Authoring Shape

```yaml
version: 1
decision_id: loan_eligibility
decision_name: Loan Eligibility
hit_policy: FIRST
schema:
  inputs:
    - name: age
      type: number
      expression: applicant.age
    - name: tier
      type: string
      expression: applicant.tier
  outputs:
    - name: decision
      type: string
rules:
  - id: r_adult_gold
    priority: 10
    enabled: true
    description: Approve adult GOLD applicants
    when: age >= 21 AND tier == "GOLD"
    then:
      - kind: SET_FIELD
        path: decision
        value: "APPROVE"
```

The runtime compiler consumes the rule definitions and compiles them
against a field dictionary. Studio and CLI tooling can present embedded
`schema:` for authoring and derive the compiler field dictionary from it.

## Top-Level Fields

| Field | Required | Authoring meaning |
|---|---:|---|
| `version` | recommended | Authoring document version. |
| `decision_id` | recommended | Stable decision identifier. |
| `decision_name` | recommended | Human-readable decision name. |
| `metadata` | optional | Deployment or ownership metadata. |
| `schema_ref` | optional | External schema reference. |
| `schema` | recommended | Input/output shape used by tools. |
| `hit_policy` | optional | Rule matching policy. Default is `FIRST`. |
| `output_conflict_policy` | optional | `LWW` or `STRICT`. Default is `LWW`. |
| `aggregate_fn` | optional | Aggregation for `COLLECT`. Default is `LIST`. |
| `functions` | optional | User functions for Starlark-backed packs. |
| `rules` | required | Rule list. |

## Rule Fields

| Field | Required | Meaning |
|---|---:|---|
| `id` | yes | Stable rule identifier. |
| `priority` | no | Signed integer used by priority-aware policies. Default is `0`. |
| `enabled` | no | Disabled rules are skipped. Default is `true`. |
| `description` | yes | Human-readable description. |
| `when` | yes | VDICL expression parsed by the compiler. |
| `then` | yes | Ordered list of actions. |

## Rule Order

Document order matters for `FIRST`, `RULE_ORDER`, and deterministic
fallback behavior. Put specific rules before fallback rules:

```yaml
rules:
  - id: r_specific_case
    description: Approve high confidence case
    when: score >= 800
    then:
      - kind: SET_FIELD
        path: decision
        value: "APPROVE"
  - id: r_fallback
    description: Review all remaining cases
    when: true
    then:
      - kind: SET_FIELD
        path: decision
        value: "REVIEW"
```
