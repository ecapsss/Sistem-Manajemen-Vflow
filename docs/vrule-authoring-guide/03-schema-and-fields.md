# 03 - Schema And Fields

VDICL expressions are checked against a field dictionary at compile
time. The dictionary defines the available input paths, scalar kinds,
and nullability.

## Authoring Schema

Studio and CLI authoring usually show a compact schema:

```yaml
schema:
  inputs:
    - name: age
      type: number
      expression: applicant.age
    - name: tier
      type: string
      expression: applicant.tier
    - name: verified
      type: boolean
      expression: applicant.verified
  outputs:
    - name: decision
      type: string
```

The compiler-level field dictionary uses scalar names:

```yaml
version: 1
namespace: lending
schema_version: 1
domain: lending
entity: applicant
fields:
  - path: applicant.age
    scalar: I64
    nullable: false
  - path: applicant.tier
    scalar: SYM
    nullable: false
  - path: applicant.verified
    scalar: BOOL
    nullable: false
```

## Scalar Kinds

The runtime schema model supports these scalar kinds:

| Scalar kind | Typical authoring type | Meaning |
|---|---|---|
| `NULL` | null | Null value. |
| `BOOL` | boolean | Boolean. |
| `I32`, `I64` | number | Signed integer. |
| `U32`, `U64` | number | Unsigned integer. |
| `F64` | number | Floating-point number. |
| `DECIMAL128` | decimal | Decimal number. |
| `SYM` | string | Canonicalized symbolic text. |
| `BYTES` | string | Byte-preserved string data. |
| `DATE_DAYS` | date | Date represented as day count. |
| `DATETIME_MICROS` | datetime | Datetime represented as microseconds. |
| `TIME_MICROS` | time | Time represented as microseconds. |
| `DAY_TIME_DURATION` | duration | Day-time duration. |
| `YEAR_MONTH_DURATION` | duration | Year-month duration. |
| `JSON` | json | JSON payload. |
| `PATH` | path | Path value. |
| `LIST` | list | List value. |
| `OBJECT` | object | Context/object value. |

## Field Paths

Use dotted paths for nested input:

```yaml
when: applicant.creditScore >= 650
when: applicant.address.country == "ID"
```

Field paths must resolve to schema fields. Unknown fields are compile
errors unless a tool-specific translation layer creates them before
compile.

## Nullability

Nullable fields may evaluate to `null`. Use explicit null checks where
business logic depends on presence:

```yaml
when: applicant.npwp IS NOT NULL AND applicant.npwp != ""
```

Use `COALESCE` for defaulting:

```yaml
when: COALESCE(applicant.monthlyIncome, 0) >= 5000000
```
