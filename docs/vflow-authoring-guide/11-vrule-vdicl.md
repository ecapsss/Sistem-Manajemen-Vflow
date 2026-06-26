# VRule and VDICL

VRule is the VWFD activity for decisioning and rule evaluation. The rule language is VDICL, a table-friendly rule language for eligibility, risk, compliance, pricing, routing, scoring, and validation logic.

VRule is separate from V-CEL and Compute:

| Surface | Best For |
|---|---|
| V-CEL | Short expressions, guards, mappings, filters, and transforms. |
| VRule / VDICL | Decision tables, rule packs, hit policies, compliance logic, and explainable findings. |
| Compute / Starlark | Multi-step custom logic, loops, algorithms, and custom functions. |

V-Starlark can call V-Rule when custom logic needs to evaluate a rule pack as part of a larger algorithm.

## Rule Pack Shape

```yaml
id: payment_risk_v2
version: "2.0.0"
hit_policy: PRIORITY
output_conflict_policy: STRICT

rules:
  - id: high_value_new_customer
    when:
      all:
        - field: amount
          op: ">"
          value: 10000000
        - field: customer_age_days
          op: "<"
          value: 30
    priority: 100
    actions:
      - type: set_output
        key: risk_level
        value: high
      - type: add_finding
        severity: warning
        code: HIGH_VALUE_NEW_CUSTOMER
        message: "High value transaction from a new customer"
```

## Functions (optional, enables FEEL closure semantics)

Top-level `functions:` section accepts user-declared functions in **native
Starlark** body syntax. When present, the entire rule pack auto-routes to
the V-Starlark backend at compile time — transparently. The author still
writes VDICL YAML; the runtime swap is hidden.

```yaml
functions:
  - name: priority_for_tier
    params: [tier]
    body: |
      if tier == "gold":
          return 100
      elif tier == "silver":
          return 50
      return 10

  - name: sort_descending
    params: [a, b]
    body: a > b   # single-expression form; auto-wrapped with `return`

rules:
  - id: route_high_priority
    when: "priority_for_tier(customer_tier) >= 100"
    then:
      - kind: SET_DECISION
        decision: VIP_QUEUE
```

This unlocks `sort(list, custom_comparator)`, recursive functions, and
closures referencing outer-scope variables — features that VDICL native
runtime doesn't implement directly. V-Starlark provides them; VDICL
delegates the whole pack execution.

Without a `functions:` section, packs compile to native VDICL bytecode
(fastest path; ~7.58M decision-only evals/s at 1-rule). With functions,
packs compile to a Starlark module wrapped in a `VRSL`-prefixed format
that `vrule_eval::evaluate` dispatches accordingly.

## Schema Shape

```yaml
fact:
  amount: number
  customer_age_days: integer
  country: string
  merchant_category: string
  has_chargeback_history: boolean
```

The schema defines the fields that a rule pack can read from the input fact. Use it to keep rule packs explicit and reviewable.

### Proto-native fact + output (gRPC fastpath)

For workflows triggered over gRPC with `body_schema`, the schema can declare a typed proto binding so V-Rule reads facts directly from the `DynamicMessage` (no JSON intermediate) and writes its decision back as proto bytes:

```yaml
schema:
  bind_proto: examples.RiskRequest          # gRPC native input
  output_proto_schema: examples.RiskResponse # gRPC native output
  fact:
    amount: number
    country: string
    card_bin: string
    merchant_category: string
    customer_tier: string
    velocity_1h: integer
```

Behaviour:
- `bind_proto` — V-Rule's input dispatch detects a matching `ProtoHandle` on the variable bound to the trigger body and reads facts directly from the cached `DynamicMessage`. Skips JSON object construction entirely on the proto branch (Phase 2 of the gRPC-native data path).
- `output_proto_schema` — V-Rule's output is encoded to proto wire bytes for the named message type and stashed on the V-Rule output variable's handle slot. EndTrigger `bytes_ref` reads them with no re-encoding (Phase 3).

The same compiled V-Rule pack drives BOTH webhook (JSON in/out) and gRPC (proto in/out) consumers. Public examples: `examples-vflow/provision-pattern/047-fastpath-vrule-risk-scoring/schemas/fastpath_risk_fact_v1.yaml` (declares both fields) + `060-standard-vrule-risk-scoring-grpc/` + `061-fastpath-vrule-risk-scoring-grpc/`.

## VRule Activity

```yaml
spec:
  activities:
    - id: risk_decision
      activity_type: VRule
      rule_config:
        rule_set_id: payment_risk_v2
        rule_pack: "compiled/payment_risk_v2.vdicl"
        eval_mode: bytecode
      input_mappings:
        - target: amount
          source: { language: v-cel, source: "order.amount" }
        - target: customer_age_days
          source: { language: v-cel, source: "order.customer_age_days" }
      output_variable: risk_result
```

The activity output contains the rule result, selected outputs, findings, and metadata needed by downstream workflow nodes.

## Runtime Modes

VRule can run in both VWFD runtime modes:

| Mode | Use For | Behavior |
|---|---|---|
| `standard` | Durable orchestration, stateful execution, retries, parked flows, audit-heavy workflows, and side-effecting integration paths. | Runs through the normal kernel path. This is the default when `trigger_config.runtime_mode` is omitted. |
| `fastpath` | Stateless webhook response decisions where latency is the priority. | Runs on the optimized synchronous response path. VRule packs are prepared at route activation and inputs are built from `input_mappings`. |

Fastpath keeps the same rule semantics as standard mode. The difference is the workflow execution path. Detached edges can still start background work, but they must not feed `EndTrigger.final_response`.

```yaml
spec:
  activities:
    - id: trigger
      activity_type: Trigger
      trigger_config:
        trigger_type: webhook
        runtime_mode: fastpath
        webhook_config: { path: /risk/score, method: POST }
      output_variable: trigger_payload

    - id: risk
      activity_type: VRule
      rule_config:
        rule_set_id: fastpath_risk_v1
      input_mappings:
        - target: amount
          source: { language: spv1, source: "$.trigger_payload.body.amount" }
      output_variable: risk_result

    - id: respond
      activity_type: EndTrigger
      end_trigger_config:
        trigger_ref: trigger
        final_response: { language: spv1, source: "$.risk_result" }
```

Reference examples:

| Example | Mode | Purpose |
|---|---|---|
| `examples-vflow/provision-pattern/047-fastpath-vrule-risk-scoring/` | `fastpath` | Payment risk scoring on the optimized response path. |
| `examples-vflow/provision-pattern/049-standard-vrule-risk-scoring/` | `standard` | The same rule pack, payload, mapping, and response shape on the normal kernel path. |
| `examples-vflow/provision-pattern/050-fastpath-vrule-risk-scoring-detached/` | `fastpath` + detached branch | Same scoring response with audit-record construction detached from the response path. |
| `examples-vflow/provision-pattern/051-fastpath-vrule-risk-scoring-blocking/` | `fastpath` blocking branch | Same scoring and audit work, but audit remains on the response path. |
| `examples-vflow/provision-pattern/052-standard-vrule-risk-scoring-detached/` | `standard` + detached branch | Standard-runtime version of the detached audit comparison. |
| `examples-vflow/provision-pattern/053-standard-vrule-risk-scoring-blocking/` | `standard` blocking branch | Standard-runtime version with audit work kept on the response path. |
| `examples-vflow/provision-pattern/054-standard-vrule-risk-scoring-audit-log/` | `standard` + workflow `audit_log` | Standard-runtime scoring with user-owned audit envelope emission through the audit emitter. |
| `examples-vflow/provision-pattern/055-standard-vrule-risk-scoring-detached-nats-publish/` | `standard` + detached NATS publish | Standard-runtime scoring with direct materialized business-event publish on a detached branch. |

Representative E2E webhook comparison on the same machine and same rule pack:

| Scenario | Runtime mode | Requests | Concurrency | RPS | Avg | P50 | P95 | P99 | Errors |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `047-fastpath-vrule-risk-scoring` | `fastpath` | 5000 | 256 | 86,778.90 | 2.5ms | 2.42ms | 4.37ms | 6.19ms | 0 |
| `050-fastpath-vrule-risk-scoring-detached` | `fastpath` + detached audit | 5000 | 256 | 82,163.24 | 2.7ms | 2.55ms | 5.03ms | 6.99ms | 0 |
| `051-fastpath-vrule-risk-scoring-blocking` | `fastpath` + blocking audit | 5000 | 256 | 53,793.46 | 4.4ms | 4.37ms | 7.53ms | 9.31ms | 0 |
| `049-standard-vrule-risk-scoring` | `standard` | 5000 | 256 | 6,557.77 | 38.8ms | 39.00ms | 72.77ms | 83.84ms | 0 |
| `052-standard-vrule-risk-scoring-detached` | `standard` + detached audit | 5000 | 256 | 6,230.97 | 40.7ms | 41.39ms | 74.44ms | 84.11ms | 0 |
| `053-standard-vrule-risk-scoring-blocking` | `standard` + blocking audit | 5000 | 256 | 5,345.00 | 47.5ms | 48.53ms | 75.97ms | 87.14ms | 0 |
| `054-standard-vrule-risk-scoring-audit-log` | `standard` + workflow `audit_log` to NATS | 5000 | 256 | 5,201.88 | 48.7ms | 47.56ms | 76.27ms | 88.77ms | 0 |
| `055-standard-vrule-risk-scoring-detached-nats-publish` | `standard` + detached NATS publish | 5000 | 256 | 5,038.78 | 50.5ms | 50.47ms | 73.90ms | 85.08ms | 0 |

Detached audit keeps post-decision side work out of the response path. In the fastpath fixture it preserves most of the no-audit throughput; in the standard fixture it is still closer to baseline than the blocking branch. Use `054` vs `055` when comparing workflow-level audit envelopes with `audit_log.extras` against direct detached business-event publish.

## Expression Grammar

VDICL supports decision-oriented expression forms:

| Category | Examples |
|---|---|
| Boolean logic | `AND`, `OR`, `NOT` |
| Comparisons | `=`, `!=`, `>`, `>=`, `<`, `<=` |
| Set membership | `IN`, `NOT IN` |
| Ranges | `BETWEEN` |
| Existence | `EXISTS`, `IS NULL`, `IS NOT NULL` |
| Quantifiers | `ANY`, `EVERY` |
| String helpers | `STARTS_WITH`, `ENDS_WITH`, `CONTAINS`, `SUBSTR`, `CONCAT` |
| Numeric helpers | `ABS`, `MIN`, `MAX`, `ROUND`, `FLOOR`, `CEIL` |
| Temporal constructors | `date(s)`, `time(s)`, `date and time(s)`, `date and time(date, time)`, `duration(s)` |
| Temporal property access | `D.year`, `D.month`, `D.day`, `D.weekday`, `T.hour`, `T.minute`, `T.second`, `T.offset` / `T.time offset`, `T.timezone`, `Dur.years`, `Dur.months`, `Dur.days`, `Dur.hours`, `Dur.minutes`, `Dur.seconds` |
| Temporal arithmetic | `Date - Date → DayTimeDuration`, `DateTime - DateTime → DayTimeDuration`, `Time - Time → DayTimeDuration`, `Date ± Duration`, `DateTime ± Duration`, `Time ± DayTimeDuration`, `Duration ± Duration` |
| Duration helpers | `DUR_DAYS`, `DUR_HOURS`, `DUR_MINUTES`, `DUR_SECONDS`, `DUR_MICROS` |
| Null helpers | `COALESCE`, `IS_EMPTY`, `IS_PRESENT` |

Temporal property access keeps the FEEL local-tz view: `DateTime.day`
returns the day in the value's original tz suffix, not in UTC. The two-
word `time offset` accessor is accepted as a synonym of `offset` per the
DMN spec. Temporal accessors also work when the value reaches the
expression as an ISO 8601 string (e.g. via chained-DRG threading from
an upstream V-Rule decision pack), not only as a tagged temporal.

## Hit Policies

| Policy | Semantics |
|---|---|
| `FIRST` | Return the first matching rule. |
| `UNIQUE` | Require at most one matching rule. |
| `COLLECT` | Collect all matching rule outputs and findings. |
| `PRIORITY` | Pick the matching rule with the highest priority. |
| `ANY` | Return any matching rule where all matches are equivalent. |
| `RULE_ORDER` | Evaluate and collect matches in rule order. |

## Actions

Rule actions can set outputs, add findings, assign severity, emit structured metadata, and drive downstream workflow routing.

```yaml
actions:
  - type: set_output
    key: decision
    value: manual_review
  - type: add_finding
    severity: warning
    code: MANUAL_REVIEW_REQUIRED
    message: "Transaction needs manual review"
```

## Output Conflict Policy

Use an explicit conflict policy when multiple matching rules can write the same output key.

| Policy | Semantics |
|---|---|
| `STRICT` | Treat conflicting output writes as an error. |
| `LWW` | Last writer wins according to evaluation order. |

## FEEL Conformance

VDICL tracks **FEEL** (Camunda's reference DMN expression language; engine:
`feel-scala 1.21+`) as the canonical baseline. As of Phase 1-6 work, VDICL
provides **138 builtins**, **14 grammar additions**, and a **113-case
conformance suite** ported from feel-scala unit tests — covering numeric,
string, list, range, temporal, context, conversion, 3-valued logic, for
comprehension, filter, path broadcast, and function-definition surfaces.

Function definitions (`functions:` YAML section, native Starlark bodies)
auto-route at compile time to the V-Starlark backend via a magic-prefix
pack format. User-facing transparent — author writes VDICL YAML, gets
FEEL semantics + closure support without per-call boundary crossing.

See `crates/vdicl_ssot_tests/CONFORMANCE.md` for the divergence list and
methodology.

### DMN TCK conformance

VDICL is also driven against the **OMG DMN TCK** (Decision Model and
Notation Technology Compatibility Kit) via the `feel2vdicl` translator.
The harness compiles every TCK `.dmn` model, runs each test case through
the VDICL runtime, and compares materialized output against the expected
`<resultNode>` values.

Current state (slice 7d-11):

| Phase | Metric | Status |
|---|---:|---|
| Phase B (compile) | 154 / 154 | every TCK model compiles cleanly |
| Phase C (execute + compare) | **3432 / 3433** | 99.97 % — full match per `<testCase>` |
| Compliance Level 3 surface | 0007 / 0030 / 0031 / 0086 / 0088 / 0089 / 0092 | all passing (UDF, recursion, imports, lambdas, date/time, FEEL flow control) |

The remaining failure is `non-compliant/0019-flight-rebooking` (multi-day
list-replacement scenario, deferred). Compliance-level 1, 2, and 3 cases
all pass.

The conformance harness lives in `vrule_cli/tests/tck_phase_c.rs`;
run with `TCK_PATH=…/dmn-tck/TestCases cargo test --test tck_phase_c`.

## Performance Notes

VDICL is compiled to compact bytecode and evaluated by a stack-register
VM. It is designed for high-throughput decisioning inside workflows.

Representative decision-only throughput (`evaluate_prepared_decision`,
local dev box, post P1-P8 perf campaign + Phase 1-6 FEEL parity work):

| Rule Pack Size | VDICL throughput | Camunda DMN baseline | Speedup |
|---|---:|---:|---:|
| 1 rule | ~7.58M evals/s | 403,821 evals/s | **18.8×** |
| 100 rules | ~236K evals/s | 5,390 evals/s | **43.8×** |
| 1000 rules | ~24.9K evals/s | 515 evals/s | **48.3×** |

Findings-mode throughput (`evaluate_prepared` — full output materialization):

| Pack Size | Throughput | µs/eval |
|---|---:|---:|
| 1 rule | ~1.10M evals/s | 0.91 µs |
| 100 rules | ~15.6K evals/s | 63.9 µs |
| 1000 rules | ~1.67K evals/s | 598.2 µs |

Use VRule for structured decision packs (incl. FEEL-style rules). Use
V-Starlark Compute activity when a workflow needs custom algorithmic
logic that doesn't fit the rule-table shape — V-Starlark can also call
V-Rule as a sub-decision.

## Worked Example

```yaml
version: "3.0"
metadata:
  id: payment-risk-routing
  dialect: vflow

spec:
  activities:
    - id: trigger
      activity_type: Trigger
      trigger_config:
        trigger_type: webhook
        webhook_config: { path: /payments/risk, method: POST }
        end_activity: respond
      output_variable: trigger_payload

    - id: risk
      activity_type: VRule
      rule_config:
        rule_set_id: payment_risk_v2
        rule_pack: "compiled/payment_risk_v2.vdicl"
        eval_mode: bytecode
      input_mappings:
        - target: amount
          source: { language: v-cel, source: "trigger_payload.body.amount" }
        - target: customer_age_days
          source: { language: v-cel, source: "trigger_payload.body.customer_age_days" }
      output_variable: risk_result

    - id: respond
      activity_type: EndTrigger
      end_trigger_config:
        trigger_ref: trigger
        final_response:
          language: v-cel
          source: '{"decision": risk_result.outputs.decision, "findings": risk_result.findings}'

  flows:
    - { id: f1, from: { node: trigger }, to: { node: risk } }
    - { id: f2, from: { node: risk }, to: { node: respond } }
```
