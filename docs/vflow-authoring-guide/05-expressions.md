# VWFD YAML — Expressions & Kernel Variables


Expressions appear in three places:
1. **`input_mappings[*].source`** — wire variables into activity inputs.
2. **Edge `condition`** — guard an outgoing flow.
3. **Activity-level** — `filter`, `transform` on Trigger; `final_response` on EndTrigger; `condition` on LoopWhile; `assignee` / `title` / `due_date` on HumanTask.

---

## Language selector

Every expression site accepts a `{ language, source }` pair (or an equivalent shorthand where the language is fixed). Four languages are recognised:

| `language` | Meaning | When to use |
|---|---|---|
| `literal` | Plain string constant | Static URLs, fixed headers, constant SQL. |
| `spv1` | SPv1 (JSONPath-like select) | Pluck a value from variable scope. |
| `vil-expr` | VIL expression language | JSON-shaped construction with field references. |
| `v-cel` / `vcel` | V-CEL (CEL-based) | Full expression power: filters, maps, lambdas, comparisons. |
| `bytes_ref` | Read raw bytes from a variable's handle slot | Byte-native EndTrigger / Connector input on the gRPC fastpath. Returns `(Null, bytes)` — value is null, bytes are the canonical payload. |

The dialect (`metadata.dialect`) affects which language is the implicit default for bare-string conditions. For `dialect: vflow`, conditions default to V-CEL.

### `bytes_ref` — byte-native variable read

Read raw bytes from a variable's handle slot without JSON re-encoding. Used in two main spots:

- **`EndTrigger.final_response`** to return `examples.RiskResponse` proto bytes that V-Rule wrote via `output_proto_schema`, or pass the upstream Connector response bytes through verbatim.
- **Connector `request` input** when paired with `vastar.grpc`'s `raw_request: true` mode — the trigger body bytes (a `ProtoHandle`) flow into the connector skipping `json_to_dynamic_message` + `encode_to_vec` entirely.

```yaml
# EndTrigger reads pre-encoded bytes
- id: respond
  activity_type: EndTrigger
  end_trigger_config:
    trigger_ref: trigger
    final_response:
      language: bytes_ref
      source: "encoded_response"

# Connector consumes trigger body bytes verbatim
- target: request
  source: { language: bytes_ref, source: "trigger_body" }
```

The optional `$.` prefix is accepted (`source: "$.trigger_body"` ≡ `"trigger_body"`).

### Proto-field tier (V-CEL on `trigger_body.X`)

When a gRPC trigger has `body_schema` set, the body is exposed as a typed `ProtoHandle` named `trigger_body`. V-CEL expressions like `trigger_body.amount` or `trigger_body.country` resolve through the **proto-field tier** (Tier 0.5 in `eval_mapping`) — descriptor-walk on the `DynamicMessage`, no JSON intermediate, no v-cel VM dispatch.

```yaml
input_mappings:
  - target: amount
    source: { language: v-cel, source: 'trigger_body.amount' }
  - target: country
    source: { language: v-cel, source: 'trigger_body.country' }
```

This is the proto-native counterpart of webhook's spv1 `$.trigger_payload.body.amount`. Same compiled V-Rule pack drives both webhook (JSON) and gRPC (proto) consumers.

---

## `literal` — plain string

```yaml
input_mappings:
  - target: url
    source:
      language: literal
      source: "https://api.example.com/v1/users"
```

Value is passed through unchanged. Use for URLs, static SQL, fixed header values, constant JSON fragments.

---

## `spv1` — Select Path v1

JSONPath-like path selector.

| Syntax | Meaning |
|---|---|
| `$` | Root of variable scope. |
| `$.foo` | Field `foo`. |
| `$.foo.bar` | Nested field. |
| `$.items[0]` | Array index. |
| `$.items[*]` | All elements. |
| `$.items[*].name` | Project field across elements. |
| `$.items[?(@.price > 100)]` | Filter (limited). |

```yaml
input_mappings:
  - target: transaction
    source:
      language: spv1
      source: "$.trigger_payload.body.txn"
  - target: item_names
    source:
      language: spv1
      source: "$.items[*].name"
```

Used heavily in `quick_transform.select` and simple variable wiring.

**Performance note:** SPv1 on every SSE chunk is ~50× slower than HTTP `json_tap` (a leaf-scanner). Prefer `json_tap` for per-chunk extraction on hot streams; use SPv1 for one-off or dynamic paths.

---

## `vil-expr` — VIL expression

Small expression language for JSON construction with variable references. No lambdas, limited operators, but compact for building request bodies and final responses.

```yaml
input_mappings:
  - target: body
    source:
      language: vil-expr
      source: '{ "id": trigger_payload.body.id, "ts": now(), "count": counter + 1 }'
  - target: message
    source:
      language: vil-expr
      source: 'trigger_payload.body.limit != null ? trigger_payload.body.limit : 10'
```

Supported features:
- Field access: `trigger_payload.body.x`
- JSON object / array literals
- Arithmetic: `+`, `-`, `*`, `/`
- Comparisons: `==`, `!=`, `<`, `<=`, `>`, `>=`
- Ternary: `cond ? a : b`
- Null test: `x != null`
- Built-ins: `now()`, `now_ts`, string concat, `size(x)`

---

## `v-cel` — V-CEL (CEL-based)

Full expression language for conditions, filters, lambdas, maps, built-ins.

### Operators + basic forms

```yaml
condition: "amount > 1000 && user.tier == 'premium'"
condition: "mode == 'ok' || mode == 'accept'"
condition: "items.size() > 0 && !request.cancelled"
```

### Lambdas — filter + map

```yaml
source:
  language: v-cel
  source: "items.filter(i, i.price > 100000).map(i, {name: i.name, price: i.price})"
```

Lambdas use `.<method>(<binder>, <body>)`:
- `.filter(x, <bool_expr>)`
- `.map(x, <expr>)`
- `.exists_one(x, <bool_expr>)` — exactly one element matches

Plus the 3- / 4- / 5-arg comprehension macros (used as free function calls, not method form):
- `transformList(coll, x, body_expr)` — 3-arg sugar over `.map`
- `transformList(coll, x, filter_expr, body_expr)` — fused filter+map
- `transformMap(map, k, v, body_expr)` — projection over (key, value) pairs
- `transformMap(map, k, v, filter_expr, body_expr)` — fused filter+projection

### Built-in functions

For the full surface (every opcode + builtin + cel.dev parity row) see
[`10-vcel-transform.md`](./10-vcel-transform.md) §5–§9. Quick table of
the high-frequency builtins:

| Function | Returns | Example |
|---|---|---|
| `timestamp(s)` | timestamp | `timestamp(user.joined_at)` — full year 0001..9999 range |
| `duration(s)` | duration | `duration('24h')`, `duration('500ms')`, `duration('999999999ns')` |
| `getYear` / `getMonth` / `getDayOfMonth` / `getDate` / `getDayOfWeek` / `getDayOfYear` / `getHours` / `getMinutes` / `getSeconds` / `getMilliseconds` | int | `getHours(ts, "Asia/Jakarta")` — IANA tz supported |
| `size(c)` | int | `size(items) > 0` — works on str/list/map/bytes |
| `string(x)` / `int(x)` / `uint(x)` / `double(x)` / `bool(x)` / `bytes(x)` / `dyn(x)` / `type(x)` | cast | — |
| `matches(s, regex)` | bool | `matches(email, '^[^@]+@[^@]+$')` — Rust regex syntax |
| `startsWith(s, p)` / `endsWith(s, p)` / `contains(s, sub)` / `replace(s, old, new)` / `split(s, sep)` / `substring(s, a, b)` / `to_lower(s)` / `to_upper(s)` / `trim(s)` | str/bool | — |
| `max(a, b, …)` / `min(a, b, …)` / `greatest(...)` / `least(...)` | any | variadic |
| `base64_encode(x)` / `base64_decode(s)` | bytes/str | — |
| `json_parse(s)` / `ndjson_parse(s)` | any | — |
| `ip_in_cidr(ip, cidr)` / `ip_in_cidr_list(ip, [cidrs])` / `country_in(ip, [codes])` / `time_in_window(ts, win, tz)` | bool | authz/network subset (G3) |
| `optional(x)` / `opt.hasValue()` / `opt.value()` / `opt.or(default)` | optional/any | optional types |
| `has(obj.field)` | bool | presence check (cel.dev macro) |
| `transformList(coll, x, expr)` / `transformList(coll, x, filter, expr)` | list | 3-arg + 4-arg comprehensions |
| `transformMap(map, k, v, expr)` / `transformMap(map, k, v, filter, expr)` | map | 4-arg + 5-arg comprehensions |
| `proto_encode_typed(fqn, obj)` | bytes | Encode `obj` as the proto message `fqn` registered via `POST /api/admin/proto/upload`. Accepts enum names as strings, WKT `Timestamp` as RFC3339. See gRPC gallery entries. |
| `proto_decode_typed(fqn, bytes)` | object | Inverse of `proto_encode_typed`. |

**proto_encode_typed example** (from `vflow-cloud/services/tenant-lifecycle-svc/workflows/grpc_provision.yaml:59-75`):

```yaml
source: >
  proto_encode_typed(
    "cloud.lifecycle.TenantStatus",
    {
      "tenant_id": "tenant-" + string(tenant_name),
      "state": "PROVISIONING",
      "updated_at": now_ts,
      "note": "tier=" + string(tier)
    }
  )
```

### Ternary

```yaml
source:
  language: v-cel
  source: "target_vmid > 0 ? target_vmid : 203"
```

### Building JSON shapes

```yaml
source:
  language: v-cel
  source: '{"status": "ok", "count": size(items), "top": items[0].name}'
```

Reference: `examples-vflow/provision-pattern/006-full-vcel-lambda/workflow.yaml` showcases the full V-CEL feature set.

---

## Kernel-set special variables

The engine injects these into expression scope automatically:

| Variable | Set by | Scope | Contents |
|---|---|---|---|
| `_last_output` | Kernel, after each activity | All subsequent activities | Output of previous activity. |
| `_loop_index` | Loop activity | Loop body | 0-based iteration number. |
| `_loop_done` | Loop activity | Loop exit edge | `true` when loop finishes (use on exit edge condition). |
| `_loop_results` | Loop activity | After loop | Array of body outputs (if aggregated). |
| `_signal` | Signal handler | Signal-reached activities | Signal name (e.g. `cancel`). |
| `_trigger` | Cron trigger | Cron-fired workflow | Fires `"cron"`. |
| `_schedule` / `_fired_at` | Cron trigger | Cron-fired workflow | Schedule definition + ISO8601 fire time. |

---

## Variables: declaration + reference

Declared in `spec.variables`:

```yaml
spec:
  variables:
    - { name: user_data, type: object, scope: workflow }
    - { name: items, type: array }
    - { name: counter, type: integer }
```

Referenced in expressions by bare name (no `$` prefix in V-CEL/vil-expr):

```yaml
condition: "counter > 10"
source: "items.filter(i, i.price > 100000)"
source: "user_data.email"
```

In SPv1 expressions, prefix with `$.`:

```yaml
source:
  language: spv1
  source: "$.user_data.email"
```

Activities bind their output via `output_variable`:

```yaml
- id: fetch
  activity_type: Connector
  connector_config: { ... }
  output_variable: fetch_result

# now reference `fetch_result.body.foo` in downstream expressions
```

Trigger activities typically bind to `trigger_payload` (convention), giving access to:
- `trigger_payload.body` — request body
- `trigger_payload.headers` — request headers
- `trigger_payload.query` — query parameters
- `trigger_payload.path` — URL path

---

## Input-mapping patterns (`input_mappings`)

A mapping wires one target input from one source. The full shape:

```yaml
input_mappings:
  - target: <input_name>
    source:
      language: literal|spv1|vil-expr|v-cel
      source: "<expression string>"
```

Short form (language-fixed) when the site forces a language:

```yaml
condition: "amount > 1000"                            # defaults to V-CEL in vflow dialect
final_response:
  language: vil-expr
  source: '{ "_status": 200, "body": _last_output }'
```

**Typical per-activity mappings:**

Connector (HTTP POST):
```yaml
input_mappings:
  - { target: url,     source: { language: literal, source: "https://api.example.com/v1" } }
  - { target: method,  source: { language: literal, source: "POST" } }
  - { target: headers, source: { language: vil-expr, source: '{ "Content-Type": "application/json" }' } }
  - { target: body,    source: { language: vil-expr, source: 'trigger_payload.body' } }
```

NativeCode handler:
```yaml
input_mappings:
  - { target: txn, source: { language: spv1, source: "$.trigger_payload.body.txn" } }
```

SubWorkflow input passing:
```yaml
input_mappings:
  - { target: tenant_id, source: { language: spv1, source: "$.trigger_payload.body.tenant_id" } }
  - { target: plan,      source: { language: spv1, source: "$.trigger_payload.body.plan" } }
```

---

## `quick_transform` — universal output shaper

Applied to any activity's output, regardless of type:

```yaml
- id: fetch
  activity_type: Connector
  connector_config: { ... }
  quick_transform:
    select: "$.data.items[*].name"         # SPv1
    filter: "$.status == 'active'"         # SPv1 condition
  output_variable: names
```

Distinct from connector-specific `json_tap` — `quick_transform` runs in the kernel after the activity emits, while `json_tap` runs inside the HTTP/SSE connector per chunk.

---

## Edge conditions (guards)

```yaml
flows:
  - id: f_hi
    from: { node: gate }
    to:   { node: premium }
    condition: "amount > 1000 && user.tier == 'premium'"
    priority: 1

  - id: f_evt
    from: { node: wait_pay }
    to:   { node: fulfil }
    condition: "event.event == 'pay_ok'"
```

Conditions default to V-CEL in `dialect: vflow`. Reference kernel variables (`_last_output`, `event`), workflow variables, and trigger payload directly.

---

## Pre-kernel transforms on Trigger

```yaml
- id: trig
  activity_type: Trigger
  trigger_config:
    trigger_type: webhook
    webhook_config: { path: /api/filter, method: POST }
    filter: "trigger_payload.body.approved == true"    # V-CEL — drop others
    transform: "trigger_payload.body"                   # V-CEL — replace payload
```

`filter` is evaluated before the kernel enters — returning false drops the event. `transform` reshapes the payload before it hits the first activity.

---

## `vil_query` — query DSL (provision-time SQL/CQL builder)

Compiled at workflow upload into pre-built SQL with `$N` (Postgres / ClickHouse) or `?` (Cassandra / SQLite / MySQL) placeholders + an ordered list of param refs the kernel resolves at runtime. Sent to the connector as `{operation: "raw_query", sql, params, _vil_query: true}` (sqlx + cassandra) or via the dialect's native ops (clickhouse).

> **Related**: for audit-log emit declaration (`audit_log:` block at workflow / activity level — kernel-emitted structured audit events to user-owned sinks), see [`13-audit-log.md`](./13-audit-log.md). This `vil_query` section covers query DSL only.

> **Scope: SQL / CQL family only.** vil_query supports the **5 dialects** listed
> below: `postgres`, `mysql`, `sqlite`, `clickhouse`, `cassandra`. Other
> connectors in the registry (`redis`, `mongo`, `dynamodb`, `neo4j`, `elastic`,
> `tikv`, `etcd`, time-series via `timeseries`, etc) do **NOT** participate
> in vil_query — their data models are key-value, document, graph, search,
> or paged-API and don't fit a SQL builder cleanly. For those backends, use
> the Connector activity directly with the operation name from `03-connectors.md`
> (e.g. `operation: get` for Redis, `operation: find_many` for Mongo,
> `operation: query` for DynamoDB).
>
> need surfaces. Redis is deliberately scoped OUT of vil_query (KV is not
> query-able and forcing it would balloon the DSL surface).

### Author surface

```yaml
input_mappings:
  - source:
      language: vil_query
      dialect: postgres        # postgres (default) | cassandra | sqlite | mysql | clickhouse
      source: |
        select("orders")
          .where_eq("status", trigger.status)
          .order_by_desc("created_at")
          .limit(100)
```

### Cross-dialect generic methods (work on any dialect)

| Method | Emits |
|---|---|
| `select(table)` / `insert(table)` / `update(table)` / `delete(table)` | Operation kind + table |
| `columns("a, b, c")` / `select_expr("...")` | SELECT list (last call wins) |
| `count()` / `count_as("alias")` / `sum/avg/min/max(col)` / `*_as(col, alias)` | Aggregate column |
| `alias("o")` | FROM table AS alias |
| `join(table, on)` / `inner_join` / `left_join` / `right_join` | JOIN clauses |
| `where_eq/ne/gt/gte/lt/lte/like/in(col, val)` | WHERE col OP placeholder |
| `where_null(col)` / `where_not_null(col)` | WHERE col IS [NOT] NULL |
| `where_raw("sql")` / `where_raw_bind("sql with ?", ref)` | Raw fragment, optional bind |
| `where_eq_if(col, ref)` | Conditional WHERE (one per query) — runtime kernel switches between SQL with/without clause based on `ref` resolving to null/empty-string |
| `order_by/asc/desc/raw(col)` | ORDER BY |
| `group_by(col)` / `having("expr")` | GROUP BY / HAVING |
| `limit(N)` / `offset(N)` | Literal bound |
| `limit_var(ref)` / `offset_var(ref)` | Variable-bound (placeholder) |
| `insert_columns("a,b,c")` / `value(ref)` | INSERT VALUES |
| `set(col, ref)` / `set_raw(col, "expr")` | UPDATE SET |

Aggregate result note:
- Always alias aggregate columns you will read later, for example
  `.count_as("used")` or `.sum_as("amount", "total_amount")`.
- SQLx-backed connectors decode aggregate/expression columns by value when the
  driver reports unknown column metadata. This matters for SQLite through
  `sqlx::Any`: `COUNT(*) AS used`, `COALESCE(SUM(amount), 0) AS total`, and
  `AVG(score) AS avg_score` are returned as JSON numbers, not `null`.
- Read the alias from the connector output, for example
  `usage_count.rows[0].used`. Aggregate queries return one row even when the
  matched set is empty; still use defensive V-CEL if the query is not an
  aggregate.

### Cassandra-only methods (`dialect: cassandra`)

CQL semantics are different from SQL. Each method below rejects on non-Cassandra dialects with a "Cassandra-only" compile error.

| Method | Emits | Notes |
|---|---|---|
| `clustering_eq/gt/gte/lt/lte(col, ref)` | `WHERE col OP ?` | Clustering-column predicate (range-friendly within partition) |
| `order_clustering_asc/desc(col)` | `ORDER BY col ASC/DESC` | CQL only allows ORDER BY on clustering columns |
| `allow_filtering_in_partition()` | `ALLOW FILTERING` | Honest naming: only safe within a single partition (with all `partition_eq` present). Plain `.allow_filtering()` is a deprecated alias (stderr warning, removed v0.3) |

### ClickHouse-only methods (`dialect: clickhouse`)

ClickHouse is SQL-like but extends with several OLAP-specific clauses. Each rejects on non-ClickHouse dialects with a "ClickHouse-only" compile error.

| Method | Emits | Use case |
|---|---|---|
| `final_clause()` | `FROM <t> FINAL` | Force merge-on-read for ReplacingMergeTree / SummingMergeTree (slow but exact) |
| `sample("0.1")` / `sample("1000000")` | `FROM <t> SAMPLE 0.1` | 10% sample (fraction) or absolute row count — analytic estimation |
| `array_join("col AS alias")` | `ARRAY JOIN col AS alias` | Unnest array column (between FROM/JOIN and WHERE) |
| `limit_by(N, "tenant_id, kind")` | `LIMIT N BY tenant_id, kind` | Per-group limit (different from regular LIMIT — keeps top N per group) |

### Postgres-only / TimescaleDB extension methods

| Method | Emits | Notes |
|---|---|---|
| `bucket_by_time("1 hour", "ts")` | Single column `time_bucket('1 hour', ts) AS bucket` | TimescaleDB hyper-table aggregate. Combine with `.select_expr` + `.group_by("bucket")`. Rejects on non-Postgres dialects |


### Compile-time validation rules (capability-driven)

Per-dialect rules are encoded in `Dialect::capabilities() -> &DriverCapabilities`. Adding a new dialect = one new capability struct + the validation logic stays generic.

| Rule | Triggers when | Error |
|---|---|---|
| `requires_partition_key_on_select` | Cassandra SELECT without `.partition_eq()` | "Cassandra/ScyllaDB SELECT requires at least one .partition_eq(...) call" |
| Cassandra-only method on other dialect | `.partition_eq` / `.clustering_*` / `.order_clustering_*` / `.allow_filtering_in_partition` on non-Cassandra | "vil_query method '.X()' is Cassandra-only" |
| ClickHouse-only method on other dialect | `.final_clause` / `.sample` / `.array_join` / `.limit_by` on non-ClickHouse | "vil_query method '.X()' is ClickHouse-only" |
| Postgres-only method on other dialect | `.bucket_by_time` on non-Postgres | ".bucket_by_time() requires dialect=postgres (TimescaleDB extension)" |
| Multiple `.where_eq_if()` per query | Second `.where_eq_if` call | "only one .where_eq_if(...) allowed per query (multiple optionals would need 2^N pre-built variants)" |

### Conditional WHERE switching (runtime)

When `.where_eq_if(col, ref)` is used, the compiler emits TWO SQL variants in the compiled JSON:
- `_compiled_sql` + `_param_refs`: with the optional clause + param
- `_optional.alt_compiled_sql` + `_optional.alt_param_refs`: without (Postgres `$N` renumbered)

The kernel detects `_optional`, resolves `_optional.skip_when_empty_ref`, and at runtime switches to the alt SQL when the ref resolves to null/empty-string.

### Param ref classification

Each value argument is classified at compile time:
- Quoted string `"foo"` → `_literal_str:foo` (kernel resolves to JSON string)
- Numeric literal `42` / `3.14` → `_literal_num:42` (kernel resolves to JSON number)
- Boolean `true` / `false` → `_literal_bool:true` (kernel resolves to JSON bool)
- Bare identifier like `trigger.tenant_id` → variable ref (kernel resolves via VariableStore)

### Author responsibility — dialect ↔ connector_ref must match

vil_query emits dialect-correct SQL/CQL. Sending Postgres-dialect SQL to a Cassandra `pack://` connector (or vice versa) surfaces as a runtime SQL/CQL parse error. The runtime does not auto-route between incompatible database dialects. Per-dialect connector wiring lives in `pack.yaml` (`kind: postgres` / `kind: scylla` / `kind: clickhouse` / etc).

### Performance

Compile cost: ~6 µs per query (audit-svc-shape, release mode; ~167K compiles/sec). Compile happens **once per workflow upload**; the hand-crafted V-CEL ternary-string-concat pattern that vil_query replaces ran **per workflow execution**. Net: zero runtime overhead, plus per-request V-CEL evaluation cost saved.



---

## Rule of thumb: which language when?

| Need | Use |
|---|---|
| Static constant | `literal` |
| Pluck one value from a path | `spv1` |
| Build JSON shape with a few variables, no lambdas | `vil-expr` |
| Conditional guard, filter array, map+transform, regex | `v-cel` |
| Build typed SQL/CQL queries with parametrized binds at provision time | `vil_query` |
| Per-SSE-chunk extraction (hot path) | Connector-native `json_tap` (not expression language) |
