# 05 - Literals And Values

VDICL expressions support null, booleans, numbers, strings, sets, lists,
and contexts.

## Null And Booleans

```yaml
when: verified == true
when: blocked == false
when: npwp IS NULL
```

Use lowercase `true`, `false`, and `null` in expressions.

## Numbers

Integers, decimals, negative numbers, and exponent notation are accepted:

```yaml
when: amount > 1000000
when: ratio >= 0.75
when: score >= .5
when: exposure < 1.25e6
```

Decimal literals can use `m` or `M` suffix:

```yaml
when: margin >= 12.50m
```

## Strings

Use double quotes for normal exact string literals:

```yaml
when: tier == "GOLD"
when: country == "ID"
```

Use single quoted expression strings only when you intentionally want
legacy symbolic canonicalization behavior. Public authored packs should
prefer double quoted expression strings.

Use raw byte-preserved single quote form only for cases that need exact
byte behavior:

```yaml
when: MATCHES_REGEX(code, b'^[A-Z]{3}[0-9]{4}$')
```

## Sets

Sets are useful with `IN` and `NOT IN`:

```yaml
when: tier IN {"GOLD", "PLATINUM"}
```

## Lists

List values are primarily produced by input JSON and list functions.
Use list builtins such as `COUNT`, `SUM`, `SUBLIST`, `APPEND`, and
`DISTINCT` to work with list data.

```yaml
when: COUNT(requiredDocuments) >= 3
expr: APPEND(flags, "MANUAL_REVIEW")
```

## Contexts

Context/object values are primarily produced by context functions and
JSON input.

```yaml
expr: CONTEXT("decision", decision, "reason", reasonCode)
expr: GET_VALUE(applicantContext, "tier")
```

## Literal Output Values

`SET_FIELD.value` is a literal string field in the rule model:

```yaml
- kind: SET_FIELD
  path: decision
  value: "APPROVE"
```

For numeric, boolean, or computed output, use `EVAL_SET_FIELD`:

```yaml
- kind: EVAL_SET_FIELD
  path: approvedLimit
  expr: monthlyIncome * 12
```
