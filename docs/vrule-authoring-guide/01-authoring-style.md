# 01 - Authoring Style

VDICL authoring uses YAML as a container and VDICL expressions as values
inside selected YAML fields. Keep those two layers separate.

## Canonical YAML Style

Write `description`, `when`, `path`, and `expr` as plain YAML scalars:

```yaml
description: Applicant must be at least 21
when: applicant.age < 21
path: decision
expr: applicant.monthlyIncome * 12
```

Avoid wrapping the whole field value in YAML quotes. The compiler can
deserialize quoted YAML scalars, but that style makes editor tooling
treat the whole expression as an ordinary YAML string. The canonical
authoring style keeps expressions visible to LSP, diagnostics,
highlighting, and AI editing tools.

## String Literals

Use double quotes only where the expression or action value needs a
string literal:

```yaml
when: tier == "GOLD" AND region == "ID"
value: "APPROVE"
```

For exact byte-preserved string matching in expressions, use double
quoted string literals. Single quoted expression strings are accepted
by the compiler, but they are canonicalized as symbol text.

## Description Text

Keep descriptions plain and human-readable:

```yaml
description: Reject applications below minimum age
```

For long descriptions, use a YAML block scalar instead of wrapping text
in quotes:

```yaml
description: |
  Reject applications below the product minimum age.
  This rule is evaluated before income and credit checks.
```

## Logical Operators

The canonical authoring form is:

```yaml
when: active == true AND score >= 700
when: tier == "GOLD" OR tier == "PLATINUM"
when: NOT blocked
```

The runtime parser also accepts symbolic operators such as `&&` and
`||`, but authored packs should use `AND`, `OR`, and `NOT` for clarity.

## Paths

Paths are dotted identifiers:

```yaml
when: applicant.creditScore >= 650
path: approvedLimit
```

Do not wrap paths in quotes. A quoted path is still a YAML string, but
authoring tools cannot safely treat it as a navigable path expression.

## Computed Versus Literal Output

Use `SET_FIELD` for literal output values:

```yaml
- kind: SET_FIELD
  path: decision
  value: "APPROVE"
```

Use `EVAL_SET_FIELD` for computed output:

```yaml
- kind: EVAL_SET_FIELD
  path: approvedLimit
  expr: applicant.monthlyIncome * 12
```

Do not put computed expressions under `value`. The `value` field is a
literal string field in the rule model.
