# 07 - Actions And Outputs

Each rule has a `then` list. Actions run when the rule's `when`
expression evaluates true.

## SET_FIELD

Use `SET_FIELD` for literal output values:

```yaml
- kind: SET_FIELD
  path: decision
  value: "APPROVE"
```

`SET` is accepted by the compiler, but `SET_FIELD` is the public
authoring form.

## EVAL_SET_FIELD

Use `EVAL_SET_FIELD` for computed values:

```yaml
- kind: EVAL_SET_FIELD
  path: approvedLimit
  expr: monthlyIncome * 12
```

`EVAL_SET` is accepted by the compiler, but `EVAL_SET_FIELD` is the
public authoring form.

## EMIT

Use `EMIT` to produce a finding:

```yaml
- kind: EMIT
  severity: ERROR
  code: AGE_BELOW_MIN
  field: applicant.age
  msg: Applicant is below minimum age
```

Supported severities are:

```text
PASS, INFO, WARN, ERROR, CRITICAL
```

## ADD_SCORE

Use `ADD_SCORE` to add to the runtime score:

```yaml
- kind: ADD_SCORE
  score_delta: 25
```

## SET_DECISION

Use `SET_DECISION` to set the rule-pack decision envelope:

```yaml
- kind: SET_DECISION
  decision: REVIEW
```

Supported decisions are:

```text
UNSET, ACCEPT, REJECT, REVIEW, CHALLENGE_MFA, CHALLENGE_APPROVAL
```

## Control Actions

`RETURN` stops the current rule after prior actions in that rule.

```yaml
- kind: RETURN
```

`ABORT` stops evaluation and marks the result as aborted.

```yaml
- kind: ABORT
  msg: Critical eligibility invariant failed
```

`LOG` is available for diagnostic text:

```yaml
- kind: LOG
  msg: Rule reached manual review branch
```

## ASSIGN

`ASSIGN` writes a literal value to an internal path:

```yaml
- kind: ASSIGN
  path: tmp.reason
  value: "LOW_SCORE"
```

For computed internal values, use `EVAL_SET_FIELD` where the destination
is an output path supported by the runtime output surface.

## CALL_HELPER

`CALL_HELPER` surfaces a helper request for host integration:

```yaml
- kind: CALL_HELPER
  name: fetch_credit_bureau
  arg: applicant.nik
```

Host applications decide which helper names are allowed and how helper
requests are handled.

## Action Order

Actions are ordered. Put finding/score actions before terminal control
actions:

```yaml
then:
  - kind: EMIT
    severity: CRITICAL
    code: BLOCKED_CUSTOMER
    msg: Customer is blocked
  - kind: SET_DECISION
    decision: REJECT
  - kind: RETURN
```
