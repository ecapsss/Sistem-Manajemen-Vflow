# VWFD YAML — Curated Example Gallery

under `vflow-cloud/services/*/workflows/`, and legacy VIL-derived examples
under `vflow/examples-vil/`.

## Reading order

1. **`vflow/examples-vflow/` —  runtime reference.** Public vflow
   examples is `examples-vflow/FEATURE_EXAMPLE_ENHANCEMENT_PLAN.md`.
2. **`vflow-cloud/services/*/workflows/` —  runtime reference.**
   These are valuable internal proofs for typed gRPC/proto pipelines, but they
   are vflow-cloud control-plane workflows and are not the final runtime example
   contract.
3. **`vflow/examples-vil/*` — TERTIARY legacy reference.** VIL examples can be
   mined for ideas, but runtime docs should back-port useful patterns into
   `examples-vflow/` before citing them as user-facing proof.

Absolute paths are used throughout. Verify existence before quoting — example names occasionally move during refactors.

---

## examples-vflow runtime contract — full catalog

70 example workflows under `examples-vflow/provision-pattern/` (numbers `000-064`, with paired siblings at 006/048/050/051/052). Grouped by purpose below; companion runtime smokes live under `examples-vflow/runtime-smoke/`.

### Foundation: admin, provisioning, basics (`000-013`)

| Path | Purpose |
|---|---|
| `000-provision-server/` | Server provisioning shape — admin endpoints + workflow upload contract. |
| `001-multi-tenant/` | Multi-tenant boundary + workflow registry per tenant. |
| `002-hot-reload/` | Workflow hot-reload via admin upload (replace-on-upload + immutable versioned). |
| `003-workflow-versioning/` | Immutable versioned uploads, version labels, activate/deactivate. |
| `004-parallel-join/` | Parallel + Join nodes with deterministic merge. |
| `005-vdicl-rules/` | VDICL rule pack basics. Single-decision pack with Action types. |
| `006-full-vcel-lambda/` + `006-full-vcel-lambda-fastpath/` | Full V-CEL surface (lambdas, comprehensions) on standard vs fastpath. |
| `007-3tier-statestore/` | L1 memory + L2 WAL + L3 redb tiered statestore declaration. |
| `008-immediate-durability/` | Immediate durability mode — checkpoint per activity. |
| `009-rate-limit-policy/` | Per-path rate limit + tier-gated thresholds. |
| `010-fixedwidth-parser/` | Fixed-width text parser connector. |
| `011-vil-query-sql/` | `vil_query` SQL DSL on SQLite pack connection. |
| `012-ai-gateway-streaming/` | Streaming AI gateway through `vastar.http` SSE codec. |
| `013-grpc-trigger/` | Basic inbound gRPC trigger contract. |

### Matrix + business workflow (`014-022`)

| Path | Purpose |
|---|---|
| `014-control-flow-node-matrix/` | Compile-time matrix for Branch / Loop / Timer / Expression nodes. |
| `015-trigger-matrix/` | Compile-time matrix covering current trigger schema (webhook / cron / nats / db_poll / fs / grpc / sftp / etc.). |
| `016-connector-matrix/` | Compile-time matrix covering current connector declaration shapes. |
| `017-runtime-console-operator-e2e/` | Runtime console operator fixture: upload/activate, route controls, artifact controls, gRPC controls. |
| `018-ai-gateway-simulator-benchmark/` | Fastpath AI gateway streaming passthrough — proper blackbox benchmark fixture. |
| `019-compute-starlark/` | Compute/Starlark quote calculation. Real-server smoke asserts `final_price=1350`. |
| `020-retail-order-intake/` | Retail order validation, transform, routing, inventory reservation — **business example**. |
| `021-payments-risk-routing/` | VDICL-driven payment risk routing with authorize/step-up/decline branches — **business example**. |
| `022-marketplace-fulfillment-saga/` | Marketplace fulfillment parent/child saga with Parallel/Join/SubWorkflow/ErrorBoundary/Timer + compensation — **business example**. |

### Workflow extensions: HumanTask, artifacts, internal contracts (`023-033`)

| Path | Purpose |
|---|---|
| `023-human-approval-event-gateway/` | HumanTask + EventGateway approval workflow with live fire/resume smoke. |
| `024-runtime-artifacts-wasm-native-sidecar/` | Runtime artifact invocation: WASM + NativeCode + sidecar pricing handler. |
| `025-internal-grpc-proto-contract/` | Internal gRPC workflow with descriptor-backed `proto_encode_typed` response (`bytes_ref` byte-native). |
| `026-nats-event-driven-orders/` | NATS event trigger + status publish workflow. |
| `027-local-infra-connector-business-pack/` | Business workflow exercising Redis/Etcd/Cassandra/ClickHouse/S3/SFTP/SQLite pack connections. |
| `028-storage-and-cloud-messaging-adapters/` | Storage + cloud messaging declaration coverage. |
| `029-industrial-and-financial-protocol-codecs/` | ISO8583, Modbus, OPC-UA codec declarations + smoke. |
| `030-audit-observability-timeline/` | Audit envelope + observability timeline business example. |
| `031-versioning-canary-shadow-rollback/` | Versioning canary/shadow/rollback live smoke. |
| `032-broker-trigger-lab/` | MQTT/Kafka/Redpanda broker-trigger lab fixture. |
| `033-cloud-db-and-search-lab/` | Cloud-db + search lab (lab-backed live smoke + real-server workflow E2E). |

### Triggers, artifacts, blackbox suites (`034-046`)

| Path | Purpose |
|---|---|
| `034-email-approval-notification/` | Email receive/send approval path with mock SMTP smoke. |
| `035-cdc-postgres-runtime-e2e/` | CDC PostgreSQL runtime workflow dispatch E2E. |
| `036-timer-expression-runtime-contract/` | Timer + Transform live runtime contract. |
| `037-grpc-unary-connector-contract/` | Descriptor-backed gRPC unary connector contract; `connector_ref: vastar.grpc`, `operation: call`. |
| `038-blackbox-local-trigger-suite/` | Local trigger blackbox suite — verifies trigger dispatch through the stable trigger surface. |
| `039-runtime-operator-blackbox-suite/` | Runtime operator blackbox suite — runtime-console operations through stable REST. |
| `040-wasm-portable-pricing/` | Portable WASM executable workflow fixture. |
| `041-nativecode-portable-handler/` | Portable NativeCode executable workflow fixture. |
| `042-trigger-dispatch-p1/` | P1 trigger dispatch smoke (db_poll/fs/nats_js/nats_kv when broker available). |
| `043-broker-storage-trigger-dispatch/` | Broker + storage trigger dispatch (MQTT, Kafka/Redpanda, S3 event via LocalStack SQS). |
| `044-trigger-blackbox-e2e-suite/` | E2E blackbox suite for trigger surface. |
| `045-cron-live-scheduler/` | Cron live scheduler tick-to-workflow dispatch. |
| `046-runtime-console-action-blackbox/` | Runtime console action blackbox — Retry/Replay/Cancel through runtime-local REST. |

### Bench fixtures: V-Rule + V-Starlark + audit + streaming (`047-059`)

These are matched pairs designed to isolate single axes (fastpath vs standard, detached vs blocking, audit overhead).

| Path | Purpose |
|---|---|
| `047-fastpath-vrule-risk-scoring/` | Fastpath payment risk scoring with V-Rule / VDICL. **Pair**: 049 standard. |
| `048-fastpath-vstarlark-pricing/` | Fastpath V-Starlark Compute pricing. |
| `048-fastpath-vstarlark-risk-scoring/` | Fastpath V-Starlark Compute risk scoring (same business rules as 047). |
| `049-standard-vrule-risk-scoring/` | Standard-mode V-Rule risk scoring (same pack as 047). **Bench**: fastpath-vs-standard mode cost. |
| `050-fastpath-detached-payment-audit/` | Fastpath payment audit with detached side-work — alternate framing of detached benefit. |
| `050-fastpath-vrule-risk-scoring-detached/` | Fastpath V-Rule scoring + detached audit-record construction. **Pair**: 051 blocking. |
| `051-fastpath-vrule-risk-scoring-blocking/` | Fastpath V-Rule scoring + audit work on response path. **Bench**: detach-vs-blocking on fastpath. |
| `051-standard-detached-payment-audit/` | Standard-runtime variant of 050. |
| `052-standard-blocking-payment-audit/` | Standard-runtime blocking audit. **Pair**: 051 detached. |
| `052-standard-vrule-risk-scoring-detached/` | Standard-mode V-Rule + detached audit. **Pair**: 053 blocking. |
| `053-standard-vrule-risk-scoring-blocking/` | Standard-mode V-Rule + blocking audit. **Bench**: detach-vs-blocking on standard. |
| `054-standard-vrule-risk-scoring-audit-log/` | Standard-mode V-Rule + workflow-level `metadata.audit_log`. **Bench**: runtime audit emitter overhead. |
| `055-standard-vrule-risk-scoring-detached-nats-publish/` | Standard-mode V-Rule + detached materialized NATS publish. **Bench**: direct business-event publish. |
| `056-fastpath-vrule-risk-scoring-audit-log/` | Fastpath V-Rule + request-level `metadata.audit_log`. **Bench**: audit on optimized response path. |
| `057-fastpath-ai-gateway-stream-audit-summary/` | Fastpath AI gateway stream + per-request audit summary (no per-chunk buffering). |
| `058-fastpath-vrule-risk-scoring-detached-nats-publish/` | Fastpath V-Rule + detached materialized NATS publish. |
| `059-fastpath-ai-gateway-stream-detached-nats-publish/` | Fastpath AI gateway stream + detached NATS publish. |

### gRPC native + gateway (`060-064`) — added 2026-05-03

These are the gRPC native data path Phase 1-5 + gateway optimization round examples. See `benchmark-vflow/2026-05-03-grpc-gateway-vflow-vs-envoy.md` for the head-to-head against Envoy 1.31.5.

| Path | Purpose |
|---|---|
| `060-standard-vrule-risk-scoring-grpc/` | Standard-runtime V-Rule risk scoring over gRPC trigger (apple-to-apple with 049 webhook). **Bench**: protocol cost on standard runtime. |
| `061-fastpath-vrule-risk-scoring-grpc/` | Fastpath V-Rule over gRPC (apple-to-apple with 047 webhook fastpath). Uses `schema.bind_proto` + `schema.output_proto_schema` in the V-Rule pack for proto-native input + output. **Bench**: protocol cost on fastpath. |
| `062-fastpath-grpc-passthrough/` | Pure passthrough gRPC: `Trigger → EndTrigger bytes_ref`, no business logic. **Ceiling test** for vflow gRPC fastpath; subtract from 061 to isolate V-Rule cost. |
| `063-vflow-gateway-vstarlark/` | vflow gateway with V-Starlark scripted gateway logic (api-key auth, tenant validation, trace-id normalization, response shaping) + gRPC connector forward to 062. **Head-to-head** with Envoy + Lua filter. |
| `064-vflow-gateway-plain/` | Plain forwarder gateway, **zero proto/JSON roundtrip** on the data path: `bytes_ref` source `trigger_body` → `vastar.grpc` connector with `raw_request: true` + `raw_response: true` → EndTrigger `bytes_ref`. **Head-to-head** with Envoy plain proxy. |

### Runtime smokes (`runtime-smoke/`)

52 smoke scripts. Highest-value ones for documentation:

| Path | Purpose |
|---|---|
| `runtime-console-operator-e2e.sh` | Upload/activate/delete, route controls, artifact controls, gRPC controls. Real-server smoke. |
| `runtime-console-browser-e2e.sh` | Browser render smoke for runtime console (skip-aware for browser deps). |
| `connector-trigger-matrix-live-safe-smoke.sh` | HTTP mock, gRPC health mock, SQLite pack, Protobuf, MessagePack, optional NATS. |
| `connector-local-infra-smoke.sh` | Etcd, Redis, S3/SeaweedFS, SFTP, ClickHouse, Cassandra/Scylla (skip-aware local-infra smoke). |
| `pack-trigger-registration-live-smoke.sh` | Boot-time pack trigger load/registration. |
| `compute-starlark-live-smoke.sh` | Real-server Compute/V-Starlark execution. |
| `humantask-eventgateway-resume-after-crash-smoke.sh` | True hard-kill resume of HumanTask + EventGateway live tokens. |
| `cdc-postgres-runtime-e2e.sh` | CDC runtime workflow dispatch live smoke. |
| `cron-live-scheduler-smoke.sh` | Cron tick-to-workflow live smoke. |
| `email-approval-notification-smoke.sh` | Email receive/send live mock smoke. |

For the broader runnable contract (`run-all-local.sh` + `run-local-infra.sh`) see the top-level `examples-vflow/README.md`. For the audit of which feature each example proves, see `examples-vflow/FEATURE_COVERAGE_AUDIT.md`. For proposed business example enhancements, see `examples-vflow/FEATURE_EXAMPLE_ENHANCEMENT_PLAN.md`.

---

## Runtime workflow references

All 17 of these are **real gRPC entry points on the vflow-cloud control plane**.
They are useful internal evidence for typed proto binding, `proto_encode_typed`,
WKT Timestamp, enum symbolic names, and base64 response encoding. They should
not be the only public proof for a vflow runtime feature; back-port useful
patterns into `examples-vflow/`.

Every file follows the same skeleton:

```
Trigger(trigger_type: grpc, grpc.{service, method, body_schema})
  ↓
Transform(extract)            # V-CEL reads trigger_body.<field>
  ↓
Transform(encode_response)    # proto_encode_typed(fqn, {...})
  ↓
EndTrigger(final_response: { language: spv1, source: $.resp, encoding: base64 })
  ↓
End
```

### Tenant lifecycle

| File | Method | LOC | Notes |
|---|---|---|---|
| `vflow-cloud/services/tenant-lifecycle-svc/workflows/grpc_provision.yaml` | `ProvisionTenant` | 93 | **Canonical reference** — enum read as name (`"STARTER"`), string concat, WKT Timestamp via `now_ts`, full proto_encode_typed of `TenantStatus`. |
| `vflow-cloud/services/tenant-lifecycle-svc/workflows/grpc_start.yaml` | `StartTenant` | 71 | Bump tenant to running. |
| `vflow-cloud/services/tenant-lifecycle-svc/workflows/grpc_stop.yaml` | `StopTenant` | 69 | Graceful stop. |

### Tenant artifacts (sidecar / WASM / egress)

| File | Method | LOC | Notes |
|---|---|---|---|
| `vflow-cloud/services/tenant-artifacts-svc/workflows/grpc_preload_wasm.yaml` | `PreloadWasm` | 95 | Pre-warm a WASM module into a tenant's cache. |
| `vflow-cloud/services/tenant-artifacts-svc/workflows/grpc_update_egress_allowlist.yaml` | `UpdateEgressAllowlist` | 88 | Mutate the egress allowlist for a tenant. |
| `vflow-cloud/services/tenant-artifacts-svc/workflows/grpc_install_sidecar_profile.yaml` | `InstallSidecarProfile` | 103 | Attach a sidecar profile to a tenant. |

### Tenant observability

| File | Method | LOC | Notes |
|---|---|---|---|
| `vflow-cloud/services/observability-svc/workflows/grpc_get_kpi.yaml` | `GetKpi` | 82 | KPI snapshot read-out. |
| `vflow-cloud/services/observability-svc/workflows/grpc_get_stats.yaml` | `GetStats` | 78 | Stats snapshot. |

### Fleet catalog (read-only lists)

| File | Method | LOC | Notes |
|---|---|---|---|
| `vflow-cloud/services/fleet-catalog-svc/workflows/grpc_list_cells.yaml` | `ListCells` | 88 | |
| `vflow-cloud/services/fleet-catalog-svc/workflows/grpc_list_pools.yaml` | `ListPools` | 72 | |
| `vflow-cloud/services/fleet-catalog-svc/workflows/grpc_list_tenants.yaml` | `ListTenants` | 80 | |
| `vflow-cloud/services/fleet-catalog-svc/workflows/grpc_list_wasm_modules.yaml` | `ListWasmModules` | 83 | |

### Cloud ops (admin actions)

| File | Method | LOC | Notes |
|---|---|---|---|
| `vflow-cloud/services/fleet-ops-svc/workflows/grpc_cluster_health.yaml` | `ClusterHealth` | 82 | **Repeated-message array** — `proto_encode_typed` with list of `ServiceHealth` entries; enum Status (`HEALTHY` / `DEGRADED`). |
| `vflow-cloud/services/fleet-ops-svc/workflows/grpc_spawn_pool.yaml` | `ForceSpawnPool` | 81 | **V-CEL ternary** + string concat for IP construction: `target_vmid > 0 ? target_vmid : 203`. |
| `vflow-cloud/services/fleet-ops-svc/workflows/grpc_rehydrate.yaml` | `Rehydrate` | 78 | |
| `vflow-cloud/services/fleet-ops-svc/workflows/grpc_apply_runtime_catalog.yaml` | `ApplyRuntimeCatalog` | 83 | Rolling runtime-catalog apply. |

### HTTP-triggered meta

(Removed — the legacy `provision_tenant.yaml` HTTP meta-workflow was
superseded by `services/tenant-lifecycle-svc/workflows/grpc_provision.yaml`
during the 2026-04-22 service decomposition. Archived for history at
`vflow-cloud/_archive/2026-04-26-workflows-pre-decomposition/provision_tenant.yaml`.)

### What these 17 runtime workflows collectively prove

- V-CEL reading typed proto fields — enums as symbolic names, WKT `Timestamp` as RFC3339.
- `final_response.encoding: base64` pattern for byte-first gRPC replies (C.4c).
- Pure Transform pipelines (no Connector) when the body is just codec work — aligns with the directive *"pake transform saja kalau isinya transform"*.
- End activity always appears as the flow terminus after `respond`.

---

##  DETAIL: feature-targeted smokes

Purpose-built to exercise one pattern. Each is small (30-90 LOC) and well-commented.

### Triggers & basic patterns

| Pattern | File | LOC | Highlight |
|---|---|---|---|
| Cron hello-world | `vflow/examples-vflow/vwfd-compile-time-pattern/cron-smoke/workflows/cron-tick.yaml` | 40 | Fires every 2s → NativeCode → End. Zero HTTP. |
| HTTP + JSON-schema Validate + error-edge | `vflow/examples-vflow/vwfd-compile-time-pattern/validate-smoke/workflows/signup.yaml` | 89 | Required + regex + enum validation; error-edge routes to reject_handler. |

### Control flow

| Pattern | File | LOC | Highlight |
|---|---|---|---|
| Error-edge routing | `vflow/examples-vflow/vwfd-compile-time-pattern/error-edge-smoke/workflows/error-catch.yaml` | 61 | `flow_type: error` → fallback → separate EndTrigger. |
| Signal + EventGateway routing | `vflow/examples-vflow/vwfd-compile-time-pattern/signal-gateway-smoke/workflows/route.yaml` | 71 | Three-way route via CEL guards + priority; Signal(cancel) vs Signal(terminate). |
| Full V-CEL lambdas | `vflow/examples-vflow/provision-pattern/006-full-vcel-lambda/workflow.yaml` | 55 | `.filter(x, …) / .map(u, …)`, `matches(regex)`, `timestamp()`, `size()`. |

### State & durability

| Pattern | File | LOC | Highlight |
|---|---|---|---|
| EventGateway await-mode | `vflow/examples-vflow/vwfd-compile-time-pattern/event-wait-smoke/workflows/checkout.yaml` | 75 | `await: [pay_ok, pay_failed, cancelled]` + guard conditions on event payload. |

### Composition

| Pattern | File | LOC | Highlight |
|---|---|---|---|
| Streaming SubWorkflow | `vflow/examples-vflow/vwfd-compile-time-pattern/nested-stream-smoke/workflows/parent-stream.yaml` | 50 | Chunked response framing bubbles through nested kernel. |

### Extensions

| Pattern | File | LOC | Highlight |
|---|---|---|---|
| WASM Function | `vflow/examples-vil/003-basic-hello-server/vwfd/workflows/convert.yaml` | 31 | Legacy reference only. Back-port into `examples-vflow/024-runtime-artifacts-wasm-native-sidecar` before claiming public runtime coverage. |

### Streaming

| Pattern | File | LOC | Highlight |
|---|---|---|---|
| SSE streaming + quick_transform | `vflow/examples-vil/001b-vilapp-ai-gw-benchmark/vwfd/workflows/ai-gateway-filtered.yaml` | 88 | Legacy reference only. Back-port into `examples-vflow/` before public runtime docs claim this as a proper example. |

---

## TERTIARY: data-access patterns (VIL-derived)

Examples from `examples-vil/` that use Connector for SQL/NoSQL.

| Pattern | File | LOC | Highlight |
|---|---|---|---|
| SQL find_one (sqlite) | `vflow/examples-vil/004-basic-rest-crud/vwfd/workflows/get-task.yaml` | 43 | `connector_ref: vastar.db.sqlite` + `operation: find_one`. |
| Full REST CRUD | `vflow/examples-vil/004-basic-rest-crud/vwfd/workflows/` | — | Dir contains POST/GET/PUT/DELETE/stats — browse for full set. |
| NATS worker (HTTP-triggered) | `vflow/examples-vil/013-basic-nats-worker/vwfd/workflows/nats-jetstream.yaml` | 34 | NativeCode interface to NATS client library. |

---

## Pack + Tier references (complementary YAML surfaces)

See 06-pack-tier.md for the schema. Reference files:

| File | Shape | LOC |
|---|---|---|
| `vflow/examples-vflow/packs/hello-db/pack.yaml` | Minimal sqlite pack | 44 |
| `vflow/examples-vflow/packs/multi-conn/pack.yaml` | Two named connections + two workflows | ~45 |
| `vflow/examples-vflow/packs/enterprise-sidecar/pack.yaml` | `sidecar-connector` kind + dual-role | ~50 |
| `vflow/examples-vflow/tiers/standard.yaml` | Full TierSpec shape | 60 |

Workflows *inside* those packs:
- `vflow/examples-vflow/packs/hello-db/{bootstrap,write_hello}.yaml`
- `vflow/examples-vflow/packs/multi-conn/{bootstrap,write_policy}.yaml`
- `vflow/examples-vflow/packs/enterprise-sidecar/score_transaction.yaml`

---

## Coverage checklist (VWFD workflow patterns)

| Target pattern | Best reference |
|---|---|
| HTTP webhook (minimal) | `vflow/examples-vflow/vwfd-compile-time-pattern/validate-smoke/workflows/signup.yaml` |
| Cron / scheduled | `vflow/examples-vflow/vwfd-compile-time-pattern/cron-smoke/workflows/cron-tick.yaml` |
| NATS worker | `vflow/examples-vil/013-basic-nats-worker/vwfd/workflows/nats-jetstream.yaml` (legacy; target `026-nats-event-driven-orders`) |
| Database find_one | `vflow/examples-vil/004-basic-rest-crud/vwfd/workflows/get-task.yaml` (legacy; target `027-local-infra-connector-business-pack`) |
| Parallel / fork-join | `vflow/examples-vflow/provision-pattern/004-parallel-join/workflow.yaml` |
| Conditional branching / guards | `vflow/examples-vflow/vwfd-compile-time-pattern/signal-gateway-smoke/workflows/route.yaml` |
| Error-edge routing | `vflow/examples-vflow/vwfd-compile-time-pattern/error-edge-smoke/workflows/error-catch.yaml` |
| Saga + compensation | `vflow/examples-vflow/vwfd-compile-time-pattern/saga-smoke/workflows/checkout.yaml` |
| EventGateway await | `vflow/examples-vflow/vwfd-compile-time-pattern/event-wait-smoke/workflows/checkout.yaml` |
| V-CEL lambdas | `vflow/examples-vflow/provision-pattern/006-full-vcel-lambda/workflow.yaml` |
| Fastpath V-CEL response path | `vflow/examples-vflow/provision-pattern/006-full-vcel-lambda-fastpath/workflow.yaml` |
| Fastpath streaming gateway | `vflow/examples-vflow/provision-pattern/018-ai-gateway-simulator-benchmark/workflow.yaml` |
| Fastpath V-Rule scoring | `vflow/examples-vflow/provision-pattern/047-fastpath-vrule-risk-scoring/workflow.yaml` |
| Fastpath V-Starlark scoring | `vflow/examples-vflow/provision-pattern/048-fastpath-vstarlark-risk-scoring/workflow.yaml` |
| Standard-mode V-Rule scoring | `vflow/examples-vflow/provision-pattern/049-standard-vrule-risk-scoring/workflow.yaml` |
| Fastpath detached audit branch | `vflow/examples-vflow/provision-pattern/050-fastpath-vrule-risk-scoring-detached/workflow.yaml` |
| Fastpath blocking audit branch | `vflow/examples-vflow/provision-pattern/051-fastpath-vrule-risk-scoring-blocking/workflow.yaml` |
| Standard-mode detached audit branch | `vflow/examples-vflow/provision-pattern/052-standard-vrule-risk-scoring-detached/workflow.yaml` |
| Standard-mode blocking audit branch | `vflow/examples-vflow/provision-pattern/053-standard-vrule-risk-scoring-blocking/workflow.yaml` |
| Standard-mode workflow audit_log | `vflow/examples-vflow/provision-pattern/054-standard-vrule-risk-scoring-audit-log/workflow.yaml` |
| Standard-mode detached NATS publish | `vflow/examples-vflow/provision-pattern/055-standard-vrule-risk-scoring-detached-nats-publish/workflow.yaml` |
| Fastpath request audit_log | `vflow/examples-vflow/provision-pattern/056-fastpath-vrule-risk-scoring-audit-log/workflow.yaml` |
| Fastpath stream audit summary | `vflow/examples-vflow/provision-pattern/057-fastpath-ai-gateway-stream-audit-summary/workflow.yaml` |
| SubWorkflow | `vflow/examples-vflow/vwfd-compile-time-pattern/subworkflow-smoke/workflows/parent-square.yaml` |
| Streaming SubWorkflow | `vflow/examples-vflow/vwfd-compile-time-pattern/nested-stream-smoke/workflows/parent-stream.yaml` |
| Sidecar dispatch | `vflow/examples-vflow/vwfd-compile-time-pattern/sidecar-smoke/workflows/fraud-check.yaml` |
| WASM Function dispatch | Legacy `examples-vil` reference exists; proper target is `024-runtime-artifacts-wasm-native-sidecar`. |
| Pack manifest | `vflow/examples-vflow/packs/enterprise-sidecar/pack.yaml` |
| TierSpec | `vflow/examples-vflow/tiers/standard.yaml` |

---

## Notes for AI authors

When generating a workflow YAML from a prompt:

1. **Start from the nearest `examples-vflow` reference.** Don't author from scratch. For webhooks, clone `vwfd-compile-time-pattern/validate-smoke/workflows/signup.yaml` or the nearest `provision-pattern/*`. For gRPC/proto internals, runtime workflows can show the typed pattern, but public examples should be back-ported into `examples-vflow/`.
2. **Verify the example exists.** Paths above are absolute; filesystem may have evolved. Grep by directory name if a specific file moved.
3. **Pair every Trigger with an EndTrigger** (or explicit End). Webhook without EndTrigger = HTTP request that never gets a response.
5. **For gRPC responses**, remember `final_response.encoding: base64` when the payload is proto-encoded bytes. See any `grpc_*.yaml` file in vflow-cloud for the canonical pattern.
6. **For IaC manifests** (Tenant / FleetHost / Tier / Pack / Snapshot), see 08-iac-resources.md — that's a separate YAML surface consumed by `vflowctl apply -f`, NOT a workflow.
7. **When unsure which language**, see 05-expressions.md §"Rule of thumb" — `literal` for static, `spv1` for paths, `vil-expr` for JSON-shape, `v-cel` for logic (including `proto_encode_typed`).
