# 063 vflow Gateway with V-Starlark + gRPC Connector (FASTPATH)

Apple-to-apple comparator for **Envoy + Lua filter** as gRPC gateway.
This workflow plays the role of a light gRPC API-gateway with full
**V-Starlark business logic** mirroring what an Envoy Lua filter
would do — same auth check, same tenant validation, same trace-id
normalization, same response shaping.

## Architecture

```
                ┌────────────────────────────┐
client ───────► │ 063 GatewayProxy           │ ──┐
   gRPC         │  - V-Starlark gateway_logic│   │ vastar.grpc
                │    (auth, tenant, trace)   │   │ connector
                │  - vastar.grpc forward     │   │ (await response)
                │  - V-Starlark shape_resp   │   │
                │  - v-cel proto_encode      │   │
                │  FASTPATH RUNTIME          │   │
                └────────────────────────────┘   │
                          ▲                       ▼
                          │              ┌─────────────────┐
                          │              │ 062 Gateway     │
                          └──────────────│  fastpath       │
                                         │  passthrough    │
                                         └─────────────────┘
```

Both 062 (upstream) and 063 (gateway) live on the same vflow process,
exposed on `examples.Gateway/Passthrough` and
`examples.GatewayProxy/Passthrough` respectively (port 50071).

## Activities (V-Starlark dominant)

| # | Type | Logic |
|---|---|---|
| 1 | Trigger (gRPC, fastpath) | `examples.GatewayProxy/Passthrough`, body=`GatewayMessage` |
| 2 | **Compute (V-Starlark)** | `gateway_logic`: auth check (api-key), tenant validation, trace-id normalization |
| 3 | Connector (gRPC unary) | `vastar.grpc` → `examples.Gateway/Passthrough` on 127.0.0.1:50071 |
| 4 | **Compute (V-Starlark)** | `shape_response`: gateway-side response shaping (mirror of `envoy_on_response`) |
| 5 | Transform (v-cel) | `proto_encode(...)` JSON → `GatewayMessage` proto bytes |
| 6 | EndTrigger | `bytes_ref` to encoded bytes |
| 7 | End | |

## Why fastpath needs the Connector restriction lifted

Pre-2026-05-03, fastpath plan-builder rejected `Connector` activities
on the response path with the error:

> "fastpath response path does not support Connector activity (...);
> Connector is allowed only on detached branches for per-full-payload
> side effects"

That was a vflow runtime defect — fastpath should never silently
disable functionality the user can author. The restriction was
lifted in `crates/vflow_server/src/vflow_http_exec.rs`:

- `dispatch_fastpath_connector_node` now async with two modes:
  - **await-response** (response path): inline await; decode upstream
    response into `output_var`; downstream nodes consume the real bytes.
  - **fire-and-forget** (detached side branches): existing tokio::spawn,
    placeholder `{"status":"queued"}` to output_var.
- `run_fastpath_transform_graph` made async; cascade through call sites.
- Plan-builder annotates each Connector node with `await_response`
  based on whether it's reachable from Trigger without crossing a
  detached edge.

**Performance impact**: 5.5× speedup for this workflow:
- Standard runtime (pre-fix forced): 1,943 RPS
- Fastpath (post-fix): **10,601 RPS** (peak at c=512)

## Bench results

See `benchmark-vflow/2026-05-03-grpc-gateway-vflow-vs-envoy.md` for
full 4-cell head-to-head with shared upstream.

| Cell | Setup | Peak RPS | µs/req | Overhead vs A |
|---|---|---:|---:|---:|
| A | Direct 062 (no gateway) | 42,939 | 23.3 | baseline |
| B | Envoy plain proxy → 062 | 28,054 | 35.6 | +12 µs |
| **C** | **vflow 063 fastpath gateway** | **10,601** | **94.3** | **+71 µs** |
| D | Envoy + Lua filter → 062 | 28,812 | 34.7 | +11 µs |

**Honest assessment**: for thin gRPC gateways (validate header,
forward, shape response), Envoy still wins by ~3×. vflow gateway
makes sense when the gateway is doing real workflow work — multi-
upstream enrichment, durable state lookups, conditional routing
with V-Rule, audit emission to NATS/ClickHouse, retries, etc.

## Reproduction

Server start (build vflow-server with `--features v-starlark`):
```bash
mkdir -p $STATE_DIR
echo '{"enabled":true,"port":50071}' > $STATE_DIR/grpc_server.json
VFLOW_PORT=18193 VFLOW_PIPELINE_PORT=18194 \
VFLOW_STATE_DIR=$STATE_DIR \
VFLOW_AUDIT_EMITTER=none VIL_LOG_OFF=1 \
vflow-server &
```

Workflow setup:
```bash
# Upload combined proto FIRST (both Gateway + GatewayProxy services)
curl -sS -X POST http://127.0.0.1:18193/api/admin/proto/upload \
  -H 'X-VFlow-Proto-File: gateway.proto' \
  --data-binary @./proto/gateway.proto

# Upload upstream 062
curl -sS -X POST http://127.0.0.1:18193/api/admin/workflow/upload \
  -H 'Content-Type: application/yaml' \
  --data-binary @../062-fastpath-grpc-passthrough/workflow.yaml

# Upload 063 (this workflow)
curl -sS -X POST http://127.0.0.1:18193/api/admin/workflow/upload \
  -H 'Content-Type: application/yaml' \
  --data-binary @./workflow.yaml

# Re-upload proto to refresh route registration
curl -sS -X POST http://127.0.0.1:18193/api/admin/proto/upload \
  -H 'X-VFlow-Proto-File: gateway.proto' \
  --data-binary @./proto/gateway.proto

# Smoke
grpcurl -plaintext \
  -import-path ./proto -proto gateway.proto \
  -d '{"tenant_id":"acme","trace_id":"t-001","payload":"hello"}' \
  127.0.0.1:50071 examples.GatewayProxy/Passthrough

# Bench at saturation point
ghz --insecure --proto ./proto/gateway.proto --import-paths ./proto \
    --call examples.GatewayProxy/Passthrough \
    --total 30000 --concurrency 512 --connections 32 \
    -d '{"tenant_id":"acme","trace_id":"t-001","payload":"hello"}' \
    127.0.0.1:50071
```

## Files

- `proto/gateway.proto` — combined proto with both `Gateway` (062) and `GatewayProxy` (063) services
- `gateway.desc.b64` — pre-computed FileDescriptorSet (base64) for the gRPC connector
- `workflow.yaml` — the gateway workflow (fastpath, V-Starlark business logic)
