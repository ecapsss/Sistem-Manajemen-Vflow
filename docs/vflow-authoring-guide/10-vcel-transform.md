# VWFD YAML — V-CEL Transform Activity + CEL-Compatible Expressions

V-CEL is VFlow's CEL-compatible expression engine. It is used for Transform activities, input mappings, trigger filters, trigger transforms, and graph-edge conditions.

V-CEL follows cel.dev semantics for the non-proto evaluator surface and adds workflow-oriented helpers for JSON, proto, auth, network, and runtime data shaping.

## 1. Scope

V-CEL is Vastar's **custom CEL implementation** with cel.dev-identical
semantics on the non-proto evaluator surface. It is used as:

1. The default language of edge `condition` guards when `metadata.dialect: vflow`.
2. The language of `filter` / `transform` on Trigger.
3. One of the accepted languages in `input_mappings[*].source` (alongside `literal`, `spv1`, `vil-expr`).


---

## 2. YAML language identifier

- Canonical spelling: `language: v-cel` (hyphen).
- Aliases accepted by the parser (case-insensitive): `v-cel`, `vcel` — prefer `v-cel` in new YAML for consistency.
- On edge conditions + Trigger `filter` / `transform`, bare strings are V-CEL by default under `dialect: vflow` (no language tag needed).

---

## 3. Transform activity — YAML shape

```yaml
- id: extract
  activity_type: Transform
  input_mappings:
    - target: tenant_name
      source:
        language: v-cel
        source: 'trigger_body.tenant_name'
    - target: tier
      source:
        language: v-cel
        source: 'trigger_body.tier'
    - target: now_ts
      source:
        language: v-cel
  output_variable: extracted
```

The Transform activity has no dedicated config struct — it's pure
`input_mappings` + `output_variable`. Each mapping runs through V-CEL
and binds to a named target. The union of all targets becomes the
activity's emitted value (bound to `output_variable`).

three chained Transforms (extract → encode_response → respond) prove
the pattern end-to-end against a live proto-binding gRPC entry point.

---

## 4. Runtime model

V-CEL compiles expressions into a compact bytecode program and executes them inside the runtime with cached programs, fixed-stack evaluation, and arena-backed values for strings, lists, maps, and bytes.

## 5. Literals (cel.dev §3 — Literal Expressions)

| Type | Examples | Status |
|---|---|---|
| int | `123`, `-456`, `0x1F` | ✅ |
| uint | `123u`, `0x1Fu` | ✅ |
| double | `3.14`, `1e-6`, `.99`, `-inf`, `inf`, `nan` | ✅ |
| string | `"hello"`, `'world'`, multi-line concat (`"a" "b"` → `"ab"`) | ✅ — full Unicode + ASCII escapes (`\a \b \f \n \r \t \v \" \' \\ \xNN \NNN \uNNNN \UNNNNNNNN`) |
| bytes | `b"raw"`, `b'\\xff\\x01'` | ✅ |
| bool | `true`, `false` | ✅ |
| null | `null` | ✅ |
| timestamp | `timestamp("T00:00:00Z")` | ✅ — full cel.dev range year **0001..9999**, ns precision via `(i64 secs, u32 nanos)` |
| duration | `duration("1h")`, `duration("1.5s")`, `duration("500ms")`, `duration("999999999ns")` | ✅ |
| list | `[1, 2, 3]` | ✅ |
| map | `{"a": 1, "b": 2}` | ✅ |
| message | `MyMsg{field: value}` | ✅ — proto wrapper auto-unwrap (see §8) |
| type denotation | `int`, `uint`, `double`, `bool`, `string`, `bytes`, `list`, `map`, `null_type`, `timestamp`, `duration`, `type`, `optional_type` | ✅ — used as RHS of `type(x) == int` etc. |

### 5.1 String escape coverage

All cel-spec escapes are supported (the cel-parser-0.10 `\'`-in-double-quoted-string bug is patched by the conformance harness pre-processor; if you ship a workflow containing `"... \\' ..."` it works correctly).

### 5.2 Timestamp range note

`VcelValue::Timestamp` is now `(i64 secs, u32 nanos)` — the full CEL
spec range year 0001 to 9999 is representable losslessly. Earlier
versions stored ns-since-epoch in a single i64 (range ~1678..2262)
and would error on extreme RFC3339 inputs; that is no longer the case.

---

## 6. Operators (cel.dev §3 — Conditional + Equality + Relational + Arithmetic)

| Operator | Applies To | Runtime Lowering | Status |
|---|---|---|---|
| `+` | i64 / u64 / f64 / string / bytes / list / `timestamp + duration` / `duration + duration` | 0x10, 0x16, 0x1C, plus type-dispatch | ✅ |
| `-` | i64 / u64 / f64 / `timestamp - duration` / `timestamp - timestamp` (→ duration) / `duration - duration` | 0x11, 0x17, 0x1D | ✅ |
| `*` | i64 / u64 / f64 | 0x12, 0x18, 0x1E | ✅ |
| `/` | i64 / u64 / f64 | 0x13, 0x19, 0x1F | ✅ |
| `%` | i64 / u64 (**rejected for double per cel.dev**) | 0x14, 0x26 | ✅ |
| unary `-` | i64 / f64 | 0x15, 0x1B | ✅ |
| `<`, `<=`, `>`, `>=` | int / uint / double cross-promote, string lex, bytes lex, timestamp, duration, bool | 0x20-0x23 | ✅ |
| `==`, `!=` | every CEL type with cel.dev-identical cross-type rules (incl. `int ↔ uint`, numeric vs `inf`/`nan`, list deep-eq, map deep-eq, bytes byte-wise, message structural, **`Any` wire-canonical**) | 0x24, 0x25 | ✅ |
| `&&`, `\|\|` | bool with **`@not_strictly_false` short-circuit** (cel.dev semantics: `error && false → false`, `true \|\| error → true`) | 0x31/0x32 + 0x33 SafeAnd / 0x34 SafeOr | ✅ |
| `!` | bool | 0x30 | ✅ |
| `in` | list membership / map key presence | 0x77 ListIn, 0x78 MapIn | ✅ |
| `?:` (ternary `cond ? a : b`) | any | jmp_if_false + jmp branching with constant fold | ✅ |
| `?[ ]` optional index | optional | — | ⚠️ Same as above |

### 6.1 `_%_` overload reject

`47.5 % 5.5` is a **compile error** with the cel.dev message
`found no matching overload for '_%_' applied to '(double, double)'`.
This matches cel-spec test `fp_math/mod_not_support` exactly.

### 6.2 `int64::MIN / -1` semantics

Returns `IntegerOverflow` per cel.dev — not silent wrap.

### 6.3 Division-by-zero

Returns `DivisionByZero` for both integer and floating-point divisions.

---

## 7. Variable / field / index access + macros

| Feature | Runtime Lowering | Example | Status |
|---|---|---|---|
| Identifier lookup (`x`) | 0x01 LdField | `tenant_id` | ✅ |
| Field access (`obj.key`) | 0x73 MapAccess | `trigger_body.tenant_name` | ✅ |
| Index (`list[0]`, `map["key"]`) | 0x72 ListIndex / 0x73 MapAccess | `items[0].name` | ✅ |
| Presence check (`has(obj.key)`) | 0x76 HasField (via cel-parser `Select{test:true}`) | `has(req.body.tenant_id)` | ✅ |
| `key in map` / `el in list` | 0x78 MapIn / 0x77 ListIn | `"prod" in tags` | ✅ |
| Runtime undefined-attr error | 0x05 NoSuchAttr | unbound ident raises rather than returning Null | ✅ |
| 3-arg macro iter var (`val`) | 0x04 LdIter2 | inside transformList(k, v, ...) | ✅ |

### 7.1 CEL comprehension macros (cel.dev §6 — Macros)

| Macro | Runtime Lowering | Example | Status |
|---|---|---|---|
| `.map(x, expr)` | 0x90 ListMap | `items.map(i, i.name)` | ✅ |
| `.filter(x, expr)` | 0x91 ListFilter | `items.filter(i, i.price > 100)` | ✅ |
| `.exists_one(x, expr)` | 0x94 ListExistsOne | `items.exists_one(i, i.flag)` | ✅ |
| `transformList(coll, x, expr)` (3-arg) | 0x90 ListMap (3-arg dispatch) | `transformList(xs, x, x*2)` | ✅ |
| `transformList(coll, x, filter, expr)` (4-arg) | 0x96 ListMapFilter | `transformList(xs, x, x>0, x*2)` | ✅ |
| `transformMap(map, k, v, expr)` (4-arg) | 0x95 MapTransform | `transformMap(m, k, v, k+":"+v)` | ✅ |
| `transformMap(map, k, v, filter, expr)` (5-arg) | 0x97 MapMapFilter | `transformMap(m, k, v, v>0, k)` | ✅ |
| `has(msg.field)` | 0x76 HasField (via Select.test desugar) | `has(req.body.tenant_id)` | ✅ |

---

## 8. Built-in functions (cel.dev §6 — Standard Function Library)

### 8.1 Strings

| Function | Builtin ID | Signature | Forms | Status |
|---|---|---|---|---|
| `contains(s, sub)` | 0x00 | (str, str) → bool | both `contains(s, sub)` and `s.contains(sub)` | ✅ |
| `startsWith(s, p)` / `starts_with` | 0x01 | (str, str) → bool | both forms | ✅ |
| `endsWith(s, p)` / `ends_with` | 0x02 | (str, str) → bool | both forms | ✅ |
| `matches(s, regex)` | 0x03 | (str, str) → bool — LRU-cached compiled regex | both forms | ✅ |
| `trim(s)` | 0x04 | (str) → str | both forms | ✅ |
| `to_lower(s)` | 0x05 | (str) → str | both forms | ✅ |
| `to_upper(s)` | 0x06 | (str) → str | both forms | ✅ |
| `replace(s, old, new)` | 0x44 | (str, str, str) → str | both forms | ✅ |
| `split(s, sep)` | 0x45 | (str, str) → [str] | call form | ✅ |
| `substring(s, start, end)` | 0x46 | (str, i64, i64) → str | call form | ✅ |
| `size(s)` / `s.size()` | 0x61 / 0x75 | (str \| list \| map \| bytes) → i64 | both forms | ✅ |
| `string(x)` | 0x13 | any → str | call only (cast) | ✅ |

### 8.2 Type conversions

| Function | Builtin ID | Input / Behavior | Status |
|---|---|---|---|
| `int(x)` | 0x10 ToInt | from int/uint/f64/bool/str/timestamp (timestamp returns Unix seconds) | ✅ |
| `uint(x)` | 0x11 ToUint | from int/uint/f64/str | ✅ |
| `double(x)` | 0x12 ToDouble | from int/uint/f64/str | ✅ |
| `string(x)` | 0x13 ToString | any → RFC3339 for timestamp, e.g. for duration | ✅ |
| `bytes(x)` | 0x14 ToBytes | pass-through for str/bytes | ✅ |
| `bool(x)` | 0x15 ToBool | accepts `"1" / "t" / "T" / "true" / "TRUE" / "True"` and false-twin | ✅ |
| `dyn(x)` | (transparent) | Dynamic type-wrap for mixed-type lists; compiler treats as identity | ✅ |
| `type(x)` | 0x81 TypeOf | returns `int`/`uint`/`double`/`bool`/`string`/`bytes`/`list`/`map`/`null_type`/`timestamp`/`duration`/`type`/`optional_type` (or `<class>` FQN if known) | ✅ |

### 8.3 Temporal

| Function | Builtin ID | Behavior | Status |
|---|---|---|---|
| `timestamp(rfc3339)` | 0x20 MkTimestamp | parses RFC3339 incl. fractional seconds and `Z` / `±HH:MM` offsets; `9999-12-31T23:59:59.999999999Z` round-trips | ✅ |
| `duration("1h")` / `("500ms")` / `("999999999ns")` | 0x21 MkDuration | accepts `h/m/s/ms/us/ns` units, signed | ✅ |
| `getYear(ts [, tz])` | 0x22 | optional tz arg accepts `±HH:MM`, IANA names (`"Asia/Jakarta"`) via chrono-tz | ✅ |
| `getMonth(ts [, tz])` | 0x23 | 0-indexed per cel.dev | ✅ |
| `getDayOfMonth(ts [, tz])` | 0x24 | 0-indexed per cel.dev | ✅ |
| `getDate(ts [, tz])` | 0x2B | **1-indexed** (cel.dev ad-hoc) | ✅ |
| `getDayOfWeek(ts [, tz])` | 0x25 | 0=Sun..6=Sat | ✅ |
| `getDayOfYear(ts [, tz])` | 0x26 | 0-indexed | ✅ |
| `getHours(ts [, tz])` | 0x27 | for duration: total hours | ✅ |
| `getMinutes(ts [, tz])` | 0x28 | for duration: total minutes | ✅ |
| `getSeconds(ts [, tz])` | 0x29 | for duration: total seconds | ✅ |
| `getMilliseconds(ts [, tz])` | 0x2A | ms-of-second | ✅ |

### 8.4 Math

| Function | Builtin ID | Status |
|---|---|---|
| `max(a, b, …)` | 0x30 | ✅ variadic |
| `min(a, b, …)` | 0x31 | ✅ variadic |
| `greatest(a, b, …)` | 0x48 | ✅ alias for max |
| `least(a, b, …)` | 0x47 | ✅ alias for min |

### 8.5 Encoding

| Function | Builtin ID | Status |
|---|---|---|
| `base64_encode(str/bytes)` | 0x4A | ✅ |
| `base64_decode(str)` | 0x4B | ✅ |

### 8.6 JSON helpers (compiler-surfaced)

| Function | Builtin ID | Status |
|---|---|---|
| `json_parse(str)` | 0x50 | ✅ wired in |
| `ndjson_parse(str)` | 0x51 | ✅ wired in |

### 8.7 Authz / network (G3 subset)

| Function | Builtin ID | Signature | Status |
|---|---|---|---|
| `ip_in_cidr(ip, cidr)` | 0x60 | (str, str) → bool | ✅ |
| `ip_in_cidr_list(ip, cidrs)` | 0x61 | (str, [str]) → bool | ✅ |
| `country_in(ip, codes)` | 0x62 | (str, [str]) → bool | ✅ |
| `time_in_window(ts, window, tz)` | 0x63 | (timestamp, str, str) → bool | ✅ |

### 8.8 Crypto helpers

These helpers are bytecode builtins in `vcel_runtime`. They are intended
for webhook signature verification and signed outbound connector calls
from workflow YAML.

| Function | Builtin ID | Signature | Status |
|---|---|---|---|
| `hmac_sha256(data, key)` | 0x80 | (str, str) → lowercase hex str | ✅ |
| `hmac_sha256_sign(data, key)` | 0x80 | alias of `hmac_sha256` | ✅ |
| `hmac_sha256_verify(data, signature, key)` | 0x81 | (str, str, str) → bool | ✅ |

`hmac_sha256_verify` accepts plain lowercase/uppercase hex and the common
`sha256=<hex>` header prefix. Equal-length hex inputs are compared in
constant time. Malformed or wrong-length signatures return `false` rather
than panicking.

Webhook HMAC rules:

- Verify the exact request bytes. Use `trigger_payload.raw_body`; do not
  rebuild JSON from `trigger_payload.body`, because key order and whitespace
  can change the digest.
- `trigger_payload.raw_body` is a UTF-8 string of the request body before JSON
  parsing. On fastpath it is materialized only when the workflow references it.
- Header names are available as original, lowercase, and snake_case aliases.
  For headers containing `-`, prefer the snake_case alias in V-CEL:
  `X-Callback-Signature` -> `trigger_payload.headers.x_callback_signature`.
- Put `${secret.NAME}` placeholders inside quoted string literals. VFlow
  resolves them from the runtime environment before evaluating fastpath V-CEL.
  A missing environment variable leaves the placeholder unresolved, so smoke
  tests should cover signed webhook paths.

Webhook example:

```yaml
- id: verify_signature
  activity_type: Transform
  input_mappings:
    - target: signature_ok
      source:
        language: v-cel
        source: >
          has(trigger_payload.headers.x_callback_signature)
            ? hmac_sha256_verify(
                trigger_payload.raw_body,
                trigger_payload.headers.x_callback_signature,
                "${secret.TRIPAY_PRIVATE_KEY}"
              )
            : false
  output_variable: signature_result
```

### 8.9 JWT helpers (`vil_jwt` bridge)

These bytecode builtins call the existing `vil_jwt` crate from
`vcel_runtime`, converting V-CEL values to/from JSON-shaped values at the
boundary. Claims and generated keypairs return as V-CEL maps, so workflow
expressions can read fields directly (`claims.sub`, `claims.email`, etc.).

| Function | Builtin ID | Signature | Status |
|---|---|---|---|
| `jwt_sign(payload, secret [, algo])` | 0x82 | (map, str, str?) → token str | ✅ |
| `jwt_verify(token, secret)` | 0x83 | (str, str) → claims map | ✅ |
| `jwt_rs256_sign(payload, kid)` | 0x84 | (map, str) → token str | ✅ |
| `jwt_rs256_verify(token, kid)` | 0x85 | (str, str) → claims map | ✅ |
| `rsa_generate_keypair([bits])` | 0x86 | (int?) → `{private_pem, public_pem}` map | ✅ |
| `firebase_id_token_verify(token, project_id)` | 0x87 | (str, str) → Firebase claims map | ✅ |

`jwt_sign` accepts `HS256` (default), `HS384`, and `HS512`. `jwt_verify`
currently verifies the HS256 path. `jwt_rs256_sign` and
`jwt_rs256_verify` use the `vil_jwt` runtime key store keyed by `kid`;
the key store auto-generates an internal keypair when a new kid is first
used. Use that path for workflow-owned service tokens only.

Firebase Auth ID tokens must use `firebase_id_token_verify`. It reads the
JWT header `kid`, fetches and caches Google's documented SecureToken X.509
certificates, verifies
the RS256 signature, enforces `aud == project_id`, enforces
`iss == https://securetoken.google.com/<project_id>`, validates `exp`,
and returns the decoded claims. Do not configure a static
`FIREBASE_JWT_KID`; Google rotates the `kid` values.

Runtime environment:

| Env | Required | Purpose |
|---|---:|---|
| `FIREBASE_PROJECT_ID` | Yes, by the workflow pack | Firebase/GCP project id used as token audience and issuer suffix. |
| `VIL_JWT_FIREBASE_CERTS_URL` | No | Override the Firebase X.509 public-certs endpoint for private mirrors/tests. |
| `VIL_JWT_FIREBASE_CERTS_JSON` | No | Inline `{kid: pem_cert}` JSON for air-gapped deployments; bypasses network fetch. |
| `VIL_JWT_FIREBASE_JWKS_URL` / `VIL_JWT_FIREBASE_JWKS_JSON` | No | Accepted for JWKS mirrors/tests; X.509 remains the default. |

Minimal examples:

```yaml
- target: signed_token
  source:
    language: v-cel
    source: 'jwt_sign({"sub": user_id, "scope": "mobile"}, "${secret.API_JWT_SECRET}")'

- target: claims
  source:
    language: v-cel
    source: 'jwt_verify(trigger_payload.headers.authorization, "${secret.API_JWT_SECRET}")'
```

RS256 example:

```yaml
- target: claims
  source:
    language: v-cel
    source: 'jwt_rs256_verify(trigger_payload.headers.authorization, "iam-primary")'
```

For bearer headers that include the literal prefix, strip it before
verification:

```yaml
source: 'jwt_rs256_verify(replace(trigger_payload.headers.authorization, "Bearer ", ""), "iam-primary")'
```

Firebase bearer-header example:

```yaml
- target: uid
  source:
    language: v-cel
    source: 'firebase_id_token_verify(replace(trigger_payload.headers.authorization, "Bearer ", ""), "${secret.FIREBASE_PROJECT_ID}").sub'
```

### 8.10 Optional types (cel.dev §11 — Optional Types)

| Function | Builtin ID | Status |
|---|---|---|
| `optional(x)` — Some constructor | 0x40 OptionalOf | ✅ |
| `optional.none()` | 0x41 OptionalNone | ✅ |
| `opt.hasValue()` | 0x42 OptionalHasValue | ✅ |
| `opt.value()` / `opt.or(default)` | 0x43 OptionalValue | ✅ |

---

## 9. Proto integration

### 9.1 Well-known type wrappers (auto-unwrap at compile time)

These struct literals fold to a primitive value during compile —
zero VM cost at runtime:

| Struct literal | Folds to |
|---|---|
| `google.protobuf.BoolValue{value: true}` | `true` |
| `google.protobuf.BoolValue{}` | `false` (default) |
| `google.protobuf.Int32Value{value: 42}` / `Int64Value` / `SInt32Value` / `SInt64Value` | `int(42)` |
| `google.protobuf.UInt32Value{value: 7}` / `UInt64Value` / `FixedInt32Value` / `FixedInt64Value` | `uint(7)` |
| `google.protobuf.FloatValue{value: 1.5}` / `DoubleValue` | `double(1.5)` |
| `google.protobuf.StringValue{value: "hi"}` | `"hi"` |
| `google.protobuf.BytesValue{value: b"raw"}` | `b"raw"` |
| `google.protobuf.Value{}` (empty) | `null` (oneof default) |
| `google.protobuf.Value{null_value: NULL_VALUE}` | `null` |
| `google.protobuf.Value{number_value: 3.14}` / `string_value` / `bool_value` / `list_value` / `struct_value` | the underlying primitive |
| `google.protobuf.Struct{}` / `Struct{fields: {...}}` | empty Map / `Map{...}` (cel.dev surfaces Struct as a plain Map for `s.k` access) |
| `google.protobuf.ListValue{}` / `ListValue{values: [...]}` | empty List / `[...]` (surfaces as plain List for indexing/iteration) |
| `google.protobuf.Empty{}` | typed empty Message (DJB type-id matches `google.protobuf.Empty`; equals other Empty literals) |
| `google.protobuf.FieldMask{paths: ["a.b","c"]}` | `Map{"paths": [...]}` (queryable via `.paths`; `field_mask_match`/`field_mask_paths` builtins detail in §9.5) |
| `google.protobuf.Timestamp{seconds: S, nanos: N}` | timestamp via MkTimestamp |
| `google.protobuf.Duration{seconds: S, nanos: N}` | duration via MkDuration |

### 9.2 `google.protobuf.Any` structural equality

When two `Any` messages have **the same `type_url` and structurally
equal `value`** (after canonical re-ordering of proto wire-format
fields by tag), they compare equal — even if the raw bytes differ
in field-encoding order. This matches cel.dev's "Any unpack and
compare" semantics without requiring a proto descriptor registry.

Implementation: `vcel_runtime::any_message_equal` +
`canonicalize_proto`. Stable u16 type-id matched via `ANY_TYPE_ID`
(const DJB hash equal to `vcel_compiler::type_name_to_id("google.protobuf.Any")`).

Limitations:
- Group wire types (3, 4) and unknown wire types fall back to
  bytewise compare.
- This handles field-reorder differences. Two encodings that differ
  in repeated/packed encoding for the **same** repeated field do not
  yet reduce to equal — out of scope for this version (low ROI; no
  current cel-spec test exercises it).

### 9.3 Generic proto Message identity

Other `MyMsg{...}` literals compile to `MkMessage(type_id, n_fields)`
where `type_id = djb_type_id(qualified_name)`. Two messages with
different type names compare unequal even if all fields match.

### 9.4 FaaS-level proto encode/decode (out-of-VM)

`proto_encode_typed(fqn, obj)` and `proto_decode_typed(fqn, bytes)`
are **FaaS-level functions**, not V-CEL bytecode builtins — they're
dispatched via the compiler's function-call path and resolved against
the `ProtoRegistry` (populated via `POST /api/admin/proto/upload`).
This is why they work in runtime workflows despite not appearing as
bytecode opcodes.

```yaml
- id: encode_response
  activity_type: Transform
  input_mappings:
    - target: encoded
      source:
        language: v-cel
        source: >
          proto_encode_typed(
            "cloud.lifecycle.TenantStatus",
            {
              "tenant_id": "tenant-" + string(tenant_name),
              "state": "PROVISIONING",        # enum name as string
              "updated_at": now_ts,            # WKT Timestamp as RFC3339 string
              "note": "tier=" + string(tier)
            }
          )
  output_variable: resp
```

Semantics:
- **Enum fields** accept either numeric (`0`) or symbolic name (`"PROVISIONING"`).
- **WKT Timestamp** accepts RFC3339 string input.
- **Repeated messages** accept JSON arrays-of-objects.
- **Nested messages** accept nested maps keyed by proto field names.
- `proto_decode_typed`'s output emerges with enums as symbolic names so V-CEL can compare against string literals.



| Function | Builtin ID | Signature | Notes |
|---|---|---|---|
| `field_mask_match(mask, path)` | 0x4D | `(FieldMask\|Map, str) → bool` | Returns true when `path` is exact-equal to a mask entry OR a dot-segment-prefixed by one (e.g. mask `"a.b"` matches `"a.b"` and `"a.b.c"` but NOT `"a.bb"`). Accepts both the compile-time `Map{"paths": [...]}` representation (§9.1) and a descriptor-typed Message form. |
| `field_mask_paths(mask)` | 0x4E | `(FieldMask\|Map) → [str]` | Returns the inner `paths` list as-is (zero-copy slice into the same arena). Empty FieldMask → empty list. |

Worked example:
```yaml
- target: should_update_email
  source:
    language: v-cel
    source: |
      field_mask_match(
        google.protobuf.FieldMask{paths: ["user.email", "user.name"]},
        "user.email"
      )
  # → true
```

### 9.6 `proto_unpack_any(any)` — typed unpack to native

| Function | Builtin ID | Signature | Notes |
|---|---|---|---|
| `proto_unpack_any(any_msg)` | 0x4C | `Message<google.protobuf.Any> → Map` | Reads `type_url` + `value` from the Any value, asks the registered `ProtoDescriptorProvider` (see §9.7) to decode the inner payload, and returns the unpacked message as a JSON-shaped Map with all WKTs auto-unwrapped (Timestamp → RFC3339 string, Duration → `"<n>s"`, primitive Wrappers → underlying scalar, nested Any → recursively unpacked). |

Without a provider installed the builtin returns a deterministic
`TypeMismatch("proto_unpack_any: descriptor not registered or decode
failed")` error so the missing wiring is detectable rather than
producing a silently empty Map.

Worked example:
```yaml
- target: tenant_id
  source:
    language: v-cel
    source: |
      proto_unpack_any(envelope.payload).tenant_id
  # envelope.payload is google.protobuf.Any; we unpack and read tenant_id.
```

### 9.7 Descriptor-aware proto support

When proto descriptors are available, V-CEL can validate message literals and decode `google.protobuf.Any` payloads through the runtime descriptor provider. Without descriptors, V-CEL still supports descriptor-free map-style access and typed helper functions such as `proto_encode_typed` and `proto_unpack_any`.

### 9.8 Proto2 extensions — `msg.[full.qualified.ext]` syntax

The native `vcel_parser` accepts both forms directly:

| Expression | Parsed shape | Lowered form |
|---|---|---|
| `msg.[a.b.c]` | `Expr::Extension { operand: Some(msg), path: ["a","b","c"] }` | `msg.__ext__a_b_c` (MapAccess on mangled key) |
| `MyMsg{[a.b.c]: v}` | `StructExpr.entries[StructField { field: "[a.b.c]", value: v }]` | `MyMsg{__ext__a_b_c: v}` (mangled at MkMessage time) |

Round-trip example: `MyMsg{[ext.field]: 42}.[ext.field]` evaluates to `42`.

Runtime descriptor resolution (mapping the mangled key back to a proto field number) is performed by the `ProtoDescriptorProvider` (§9.7b) when one is registered. Workflows that don't actually use extensions continue to work — the mangled key behaves like an ordinary map field.

### 9.9 Proto enum first-class type

`VcelValue::Enum(enum_id: u16, value: i32)` carries proto enum values with their type identity. `enum_id` is the DJB hash of the enum's fully-qualified name (matches `vcel_compiler::type_name_to_id` and `vcel_runtime::enum_fqn_to_id`). Equality / comparison rules:

- `Enum(t, v) == Enum(t, v)` → true (same type + same value).
- `Enum(t1, v) == Enum(t2, v)` where `t1 != t2` → **false** (cel.dev's strict cross-enum-type rule).
- `Enum(_, v) == I64(i)` → `v == i` (cel.dev allows enum vs wire-int compare).
- `Enum(t1, _).cmp(Enum(t2, _))` → **TypeMismatch error** when `t1 != t2`.
- `Enum(_, _).is_truthy()` → always true (a zero-valued enum is still a "set" enum, distinct from absence).


---

## 10. CEL conformance

V-CEL is compatible with the cel.dev non-proto evaluator surface and supports workflow-oriented proto helpers.

### 10.1 What this guarantees

- Any cel-spec assertion in the 13 suites above evaluates the same
  way under V-CEL as under cel.dev. No "the docs say cel.dev — but
  V-CEL does X differently" surprise in this surface.
- Timestamps cover the full cel.dev range (year 0001..9999) — workflow
  authors can use `timestamp("9999-12-31T23:59:59.999999999Z")` and
  the VM holds the value losslessly.
- `google.protobuf.Any` values compare structurally — two Any payloads
  carrying the same logical message but different field-order
  serializations compare equal as cel.dev requires.
- `google.protobuf.Value{}` empty literal evaluates to `null` per
  proto oneof default semantics.
- `47.5 % 5.5` is a compile error (cel.dev: no overload for double
  modulo).
- `±inf == ±inf` is true; `nan == nan` is false; `-inf < +inf` is true.
- Cross-type numeric equality (`1 == 1u`, `1 == 1.0`, `-1 == 1u → false`) all match cel.dev rules.
- `@not_strictly_false` short-circuit works: `error && false → false`, `true || error → true`.


## 12. Variables in scope at eval time

| Variable | Set by | Scope |
|---|---|---|
| `trigger_payload` | Trigger activity | After the trigger fires; all downstream activities. |
| `trigger_body` | Trigger with typed proto binding (gRPC + `body_schema`) | gRPC entry points — reads typed fields (enum → string name, WKT Timestamp → RFC3339). |
| `_last_output` | Kernel, after each activity | All subsequent activities. |
| `_loop_index` / `_loop_done` / `_loop_results` | Loop activity | Inside / after loop body. |
| `_signal` | Signal handler | Activity receiving the signal. |
| `event` | EventGateway | After event fired. |
| `_trigger` / `_schedule` / `_fired_at` | Cron trigger | Cron-fired workflow. |
| Any var declared in `spec.variables` | — | Workflow-wide. |
| Any activity's `output_variable` | Kernel bind post-activity | All subsequent activities. |

---

## 13. Type-coercion rules

### 13.1 Comparison coercion

- `int ↔ uint`: negative int < any uint always; otherwise cast to same signedness.
- `int / uint ↔ double`: cast to double.
- `string ↔ string`: byte-wise compare.
- `bytes ↔ bytes`: byte-wise compare.
- `Timestamp ↔ Timestamp`: (secs, nanos) lexicographic compare.
- `Duration ↔ Duration`: i64 nanosecond compare.
- **Cross-type Timestamp/Duration / Timestamp/Int**: rejected (no cel.dev semantics).

### 13.2 Arithmetic coercion

- `timestamp + duration` → timestamp (in (secs, nanos) space; year-range checked).
- `timestamp - duration` → timestamp (year-range checked).
- `timestamp - timestamp` → duration (i128 intermediate to detect i64-ns overflow).
- `duration + duration` / `duration - duration` → duration.
- `int / uint / double` follow standard numeric promotion.
- `str + str` → concat.
- `bytes + bytes` → concat.
- `list + list` → concat.

### 13.3 Equality coercion

- `1 == 1u` → true (cross-numeric equality).
- `1 == 1.0` → true.
- `-1 == 1u` → false (negative int vs uint guard).
- `nan == nan` → false (IEEE).
- `inf == inf` → true; `inf == -inf` → false.
- `null == null` → true; `null == anything_else` → false.
- list/map/bytes use deep equality.
- `Message(a, T) == Message(b, T)` → field-wise deep equality.
- `Message(a, T1) == Message(b, T2)` → false (type-id mismatch).
- `Message(a, Any) == Message(b, Any)` → wire-canonical structural equality (see §9.2).

---

## 14. Worked examples

### 14.1 Ternary + string concat

```yaml
- id: derive
  activity_type: Transform
  input_mappings:
    - target: vmid
      source:
        language: v-cel
        source: 'trigger_body.target_vmid > 0 ? trigger_body.target_vmid : 203'
    - target: ip
      source:
        language: v-cel
        source: '"10.42.2." + string(trigger_body.target_vmid > 0 ? trigger_body.target_vmid : 203)'
```

### 14.2 Lambda filter + map + regex

```yaml
- target: valid_names
  source:
    language: v-cel
    source: >
      users
        .filter(u, matches(u.email, '^[a-z0-9._+-]+@[a-z0-9.-]+\\.[a-z]{2,}$'))
        .map(u, u.name)
```

### 14.3 4-arg `transformList` (filter + map fused)

```yaml
- target: high_value_titles
  source:
    language: v-cel
    source: 'transformList(items, i, i.price > 100, i.title)'
```

### 14.4 5-arg `transformMap` (filter + transform on map)

```yaml
- target: prod_only
  source:
    language: v-cel
    source: 'transformMap(envs, k, v, v == "prod", k)'
```

### 14.5 Proto response construction

```yaml
- target: encoded
  source:
    language: v-cel
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

### 14.6 Aggregate comprehension

```yaml
- target: high_score_count
  source:
    language: v-cel
    source: 'size(scores.filter(s, s.value > 0.8))'
```

### 14.7 Edge condition guard

```yaml
flows:
  - id: f_premium
    from: { node: gate }
    to:   { node: premium_path }
    condition: 'user.tier == "premium" && user.credit_score > 700'
  - id: f_standard
    from: { node: gate }
    to:   { node: standard_path }
```

(No `language:` tag — edge `condition` is V-CEL by default for `dialect: vflow`.)

### 14.8 Optional + presence check

```yaml
- target: requested_tier
  source:
    language: v-cel
    source: 'has(req.body.tier) ? req.body.tier : "starter"'
```

### 14.9 IANA timezone temporal accessor

```yaml
- target: jakarta_hour
  source:
    language: v-cel
    source: 'getHours(timestamp(req.body.event_time), "Asia/Jakarta")'
```

### 14.10 `type()` introspection

```yaml
- target: kind
  source:
    language: v-cel
    source: 'type(value) == int ? "i" : type(value) == string ? "s" : "?"'
```

---

## 15. When to use what in YAML

| Need | Language | Why |
|---|---|---|
| Static constant (URL, literal JSON) | `literal` | Fastest; no parse. |
| Pluck one field from a path | `spv1` | Compact; no CEL compile. |
| Build JSON shape with a few variables (no lambdas) | `vil-expr` | Short syntax; no bytecode. |
| Conditional guard, filter array, regex, ternary, lambdas, comprehensions | `v-cel` | Full cel.dev expression power. |
| Build proto response | `v-cel` with `proto_encode_typed(fqn, {...})` | Only V-CEL has the FaaS dispatch path. |
| Per-SSE-chunk field extract (hot) | connector-native `json_tap` | Sub-µs; runs inside connector. |
| Universal output shaper (select + filter) on any activity | `quick_transform` (SPv1) | See [`09-quick-transform.md`](./09-quick-transform.md). |

---

## 16. Authoring notes from fastpath stream dogfooding

These rules came from the Acisku fastpath stream workflow and should be
treated as authoring guidance, not runtime internals.

### 16.1 Choose the cheapest mapping language that says the truth

Use `literal` when the value is constant:

```yaml
- target: feature
  source: { language: literal, source: "financial_analysis" }
```

Use `spv1` / `quick_transform` for simple path extraction or per-chunk
stream shaping. It is intentionally small and avoids the full V-CEL
compile/eval path:

```yaml
quick_transform:
  select: "$.choices[0].delta.content"
```

Use `v-cel` when the mapping needs runtime logic: ternary, arithmetic,
`size(...)`, `has(...)`, JWT/HMAC helpers, JSON construction, lambdas, or
business guards:

```yaml
- target: remaining
  source:
    language: v-cel
    source: "(quota.limit - quota.used) < 0 ? 0 : quota.limit - quota.used"
```

Use `vil_query` for DB query construction. Do not hand-write SQL in YAML
input mappings when `vil_query` can express the query; the compiler emits
parameterized SQL and ordered params for the connector.

### 16.2 Webhook fastpath guardrails

These rules are intended for authors and AI assistants generating workflow
YAML:

1. Put `runtime_mode` on the Trigger, not as a top-level workflow hint:

   ```yaml
   - id: trigger
     activity_type: Trigger
     trigger_config:
       trigger_type: webhook
       runtime_mode: fastpath
       webhook_config: { path: /api/tripay-callback, method: POST }
       end_activity: respond
     output_variable: trigger_payload
   ```

2. For a fastpath request/response webhook, converge response branches into one
   `EndTrigger` named by `trigger_config.end_activity`. Write the chosen
   response into a shared variable before `EndTrigger`:

   ```yaml
   - id: invalid_signature_response
     activity_type: Transform
     input_mappings:
       - target: response
         source: { language: literal, source: '{"_status":401,"ok":false}' }
     output_variable: api_response

   - id: success_response
     activity_type: Transform
     input_mappings:
       - target: response
         source: { language: literal, source: '{"ok":true}' }
     output_variable: api_response

   - id: respond
     activity_type: EndTrigger
     end_trigger_config:
       trigger_ref: trigger
       final_response: { language: v-cel, source: "api_response.response" }

   flows:
     - { id: bad, from: { node: invalid_signature_response }, to: { node: respond } }
     - { id: ok, from: { node: success_response }, to: { node: respond } }
   ```

   `EndTrigger` emits the client response. It does not mean every lifecycle
   path must stop there; attach non-response work with `detached: true`.

3. For GET webhooks, read query parameters from `trigger_payload.query`, not
   from the route path. Runtime route matching strips the query string before
   lookup, then exposes decoded query params as a JSON object:

   ```yaml
   trigger_config:
     trigger_type: webhook
     runtime_mode: fastpath
     webhook_config: { path: /api/check-user, method: GET }
     end_activity: respond
   ```

   ```yaml
   - target: body
     source:
       language: v-cel
       source: '{"q": has(trigger_payload.query.q) ? trigger_payload.query.q : ""}'
   ```

   Query values are percent-decoded; `+` becomes a space. Repeated keys are
   preserved as arrays (`?tag=a&tag=b` => `trigger_payload.query.tag == ["a",
   "b"]`). Single keys remain strings. This applies to webhook fastpath and
   standard runtime; do not write routes like `/api/check-user?q=...`.

4. For signed webhooks, use raw body + header alias + secret placeholder:

   ```yaml
   source: >
     has(trigger_payload.headers.x_callback_signature)
       ? hmac_sha256_verify(
           trigger_payload.raw_body,
           trigger_payload.headers.x_callback_signature,
           "${secret.TRIPAY_PRIVATE_KEY}"
         )
       : false
   ```

   Do not sign `trigger_payload.body` after JSON parsing. Header aliases are
   case-insensitive/snake_case conveniences; `X-Callback-Signature` is safest
   to read as `trigger_payload.headers.x_callback_signature`.

5. For `vastar.http` on webhook fastpath, `connector_config.bearer_token`
   works for both non-stream and stream calls:

   ```yaml
   connector_config:
     connector_ref: vastar.http
     operation: post
     bearer_token: "${secret.GROQ_API_KEY}"
   ```

   If `headers.Authorization` is explicitly mapped, it wins. In standard
   kernel execution, map `headers.Authorization` explicitly unless the
   connector path you use documents `bearer_token` expansion.

   For JSON upstream responses, read the parsed response shape directly from
   the output variable, for example `tripay_order.data`, not a guessed
   `tripay_order.body`.

6. For DB access from YAML, use `vil_query` rather than string-built SQL:

   ```yaml
   source:
     language: vil_query
     dialect: sqlite
     source: |
       update("quota_orders")
         .set("status", trigger_payload.body.status)
         .where_eq("merchant_ref", trigger_payload.body.merchant_ref)
   ```

   Aggregate queries are supported on the same path. Alias the aggregate in
   `vil_query`, then read that alias from the connector output as a number:

   ```yaml
   source:
     language: vil_query
     dialect: sqlite
     source: |
       select("usage_tracking")
         .count_as("used")
         .where_eq("uid", auth.uid)
         .where_eq("feature", quota_context.feature)
   ```

   ```yaml
   source: { language: v-cel, source: "int(usage_count.rows[0].used)" }
   ```

   This is safe on webhook fastpath as well as standard runtime. SQLite
   aggregate/expression columns may have unknown driver metadata, so the sqlx
   connector decodes those cells by value before exposing JSON to V-CEL.

### 16.3 Fastpath stream response shape

For webhook streaming fastpath:

```yaml
trigger_config:
  trigger_type: webhook
  runtime_mode: fastpath
  response_framing: chunked
```

The runtime supports a response path with prework before the streaming
connector:

```text
Trigger -> auth/quota/db Transform/Connector nodes -> vastar.http(streaming)
```

The stream connector forwards chunks to the client as they arrive. Any
post-stream side-effect should be modeled as a `detached: true` branch from
the streaming connector or from a post-stream lifecycle node.

### 16.4 Keep stream hot path zero-copy by authoring shape

If the workflow does **not** need the full streamed content after the
connector closes, omit `output_variable` on the streaming connector:

```yaml
- id: call_ai_stream
  activity_type: Connector
  connector_config:
    connector_ref: vastar.http
    operation: post
    streaming: true
    format: sse
    dialect: openai
    json_tap: "choices[0].delta.content"
  input_mappings:
    - target: url
      source: { language: literal, source: "https://api.example/v1/chat/completions" }
    - target: body
      source: { language: v-cel, source: '{"stream": true, "messages": messages}' }
```

This lets fastpath forward connector-emitted `Bytes` to the client without
copying them into a post-stream variable. Attach background accounting via a
detached edge:

```yaml
flows:
  - { id: ok, from: { node: call_ai_stream }, to: { node: respond } }
  - { id: usage, from: { node: call_ai_stream }, to: { node: insert_usage }, detached: true }
```

Only add `output_variable` when a later activity truly needs the full stream
body, for example `llm_result.content`. That forces the runtime to collect
the emitted chunks into memory so V-CEL can read the content after stream
completion. This is correct but no longer zero-copy.

### 16.5 EndTrigger vs detached lifecycle

`EndTrigger` is the node that can produce a client response for paths that
reach it before the stream starts, such as quota rejection:

```yaml
- id: quota_exceeded_response
  activity_type: Transform
  input_mappings:
    - target: response
      source:
        language: v-cel
        source: '{"_status": 403, "error": "quota_exceeded"}'
  output_variable: api_response

- id: respond
  activity_type: EndTrigger
  end_trigger_config:
    trigger_ref: trigger
    final_response: { language: v-cel, source: "api_response.response" }
```

After a stream has started, the client bytes already came from the streaming
connector. The remaining graph is lifecycle/background work. Use detached
branches for work that should not hold the client connection open.

### 16.6 Compile-time V-CEL validation expectations

Workflow compile should validate as much of V-CEL as can be known from YAML:

- expression syntax parses
- known builtins are spelled correctly
- bytecode can be produced for `v-cel` mappings, edge conditions, filters,
  and trigger transforms
- obvious language/source shape errors are rejected

Compile cannot fully validate runtime data shape unless the workflow supplies
strong schemas for every variable. For example, this can still fail at
runtime when `rows` is empty or `llm_result` is a string:

```yaml
source: "rows[0].amount"
source: "llm_result.content"
```

Author defensively where the shape can be empty or optional:

```yaml
source: 'size(rows) > 0 ? int(rows[0].amount) : 0'
source: 'type(llm_result) == map && has(llm_result.content) ? llm_result.content : ""'
```
