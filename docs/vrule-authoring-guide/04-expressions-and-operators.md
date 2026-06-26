# 04 - Expressions And Operators

The `when` field and `EVAL_SET_FIELD.expr` field contain VDICL
expressions. The compiler parses those fields as expressions, not as
ordinary YAML strings.

## Examples

```yaml
when: age >= 21
when: tier == "GOLD" AND approvedLimit > 10000
when: applicant.country IN {"ID", "SG", "MY"}
when: applicant.npwp IS NOT NULL
```

## Operator Precedence

From highest to lowest:

| Level | Operators and forms |
|---|---|
| Atom | literals, paths, function calls, grouped expressions |
| Unary | `NOT`, unary `-` |
| Power | `**` |
| Multiplicative | `*`, `/`, `%` |
| Additive | `+`, `-` |
| Comparison | `==`, `!=`, `<>`, `<`, `<=`, `>`, `>=`, `IN`, `NOT IN` |
| Suffix predicates | `IS NULL`, `IS NOT NULL`, `IS BLANK`, `IS EMPTY` |
| Range sugar | `BETWEEN min AND max` |
| Type check | `instance of number`, `instance of string`, `instance of boolean`, `instance of null`, `instance of list`, `instance of context`, `instance of object` |
| Logical AND | `AND` |
| Logical OR | `OR` |

Use parentheses when a rule would be clearer with explicit grouping:

```yaml
when: (tier == "GOLD" OR tier == "PLATINUM") AND approvedLimit > 10000
```

## Comparison

```yaml
when: amount == 1000000
when: amount != 0
when: amount <> 0
when: age >= 21
when: riskScore < 40
```

`<>` is accepted as a not-equal alias.

## Membership

```yaml
when: tier IN {"GOLD", "PLATINUM"}
when: country NOT IN {"IR", "KP"}
```

## Null And Blank Checks

```yaml
when: email IS NOT NULL
when: phone IS BLANK
when: attachments IS EMPTY
```

## Conditional Expression

Conditional expressions use FEEL-style `if then else`:

```yaml
expr: if score >= 700 then "APPROVE" else "REVIEW"
```

## Iterators And List Expressions

The parser accepts:

```yaml
when: exists item in riskFlags satisfies item == "FRAUD"
when: every item in requiredChecks satisfies item == true
expr: for item in scores return item * 2
```

List filtering is accepted with bracket predicate syntax:

```yaml
expr: transactions[item.amount > 1000000]
```
