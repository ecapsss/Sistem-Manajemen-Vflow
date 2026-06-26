# 09 - DMN Unary Tests

VDICL tooling accepts DMN-style unary tests when importing decision
tables. Unary tests are expressions written relative to an implicit
left-hand side field.

If the input expression is `amount`, the unary test:

```text
< 1000
```

is translated as:

```text
amount < 1000
```

## Supported Unary Test Forms

| Unary test | Meaning |
|---|---|
| `< 10` | Less than. |
| `<= 10` | Less than or equal. |
| `> 0` | Greater than. |
| `>= 5` | Greater than or equal. |
| `!= "USD"` | Not equal. |
| `<> "USD"` | Not equal. |
| `= "ACTIVE"` | Equal. |
| `== "ACTIVE"` | Equal. |
| `[1..10]` | Closed range. |
| `]1..10[` | Open range. |
| `[1..10[` | Closed lower, open upper. |
| `]1..10]` | Open lower, closed upper. |
| `IN {"A", "B"}` | Set membership. |
| `NOT IN {"A", "B"}` | Set exclusion. |
| `-` | Any value. |

## Authoring Equivalent

After import, prefer full expressions in authored VDICL:

```yaml
when: amount >= 1 AND amount <= 10
```

Unary tests are primarily an import and table-cell syntax. Rule-pack
YAML should be explicit when practical.
