# 062 Fastpath gRPC Passthrough Gateway

Pure gRPC passthrough — request bytes returned as response, no
transformation. **Baseline ceiling test** for vflow gRPC fastpath.

## What this isolates

Activities are reduced to the bare minimum: `Trigger → EndTrigger → End`.
No V-Rule, no Transform, no Compute, no Connector — zero business
work. The cost-per-request you measure here is the floor that vflow
imposes for *any* gRPC fastpath workflow. Everything above this floor
in 061 (and any future gRPC workflow) is the cost of the actual
business logic.

| Aspect | Value |
|---|---|
| Trigger | `examples.Gateway/Passthrough` (gRPC) |
| Wire format | protobuf over HTTP/2 |
| Request msg | `GatewayMessage { tenant_id, trace_id, payload }` |
| Response msg | `GatewayMessage` (same type — bytes pass through verbatim) |
| Activities | Trigger → EndTrigger → End (3) |
| Compute | none |
| Runtime | fastpath |

## How the passthrough works

The fastpath plan-builder resolves `body_schema: examples.GatewayMessage`
and promotes the unframed gRPC body bytes to a `ProtoHandle` named
`trigger_body`. `set_proto` mirrors those bytes into the variable's
DataHandle slot. EndTrigger's `bytes_ref` source reads from that slot,
returning the raw bytes to the gRPC adapter, which re-frames them as
the response.

Because request and response share the same message type, the bytes
are valid on the wire both directions — no DynamicMessage decode, no
JSON conversion, no re-encode. **Pure copy.**

## Bench

Pre-load the proto, then upload the workflow:

```bash
mkdir -p $STATE_DIR
echo '{"enabled":true,"port":50071}' > $STATE_DIR/grpc_server.json

VFLOW_PORT=18193 VFLOW_PIPELINE_PORT=18194 \
VFLOW_AUDIT_EMITTER=none VIL_LOG_OFF=1 \
vflow-server &

# 1. Upload proto descriptor.
curl -X POST http://127.0.0.1:18193/api/admin/proto/upload \
     -H 'X-VFlow-Proto-File: gateway.proto' \
     -H 'Content-Type: text/plain' \
     --data-binary @./proto/gateway.proto

# 2. Upload workflow.
curl -X POST http://127.0.0.1:18193/api/admin/workflow/upload \
     -H 'Content-Type: application/yaml' \
     --data-binary @./workflow.yaml

# 3. Smoke (request payload echoed verbatim).
grpcurl -plaintext \
    -import-path ./proto -proto gateway.proto \
    -d '{"tenant_id":"acme","trace_id":"t-001","payload":"hello"}' \
    127.0.0.1:50071 examples.Gateway/Passthrough

# Expected: same JSON shape echoed back.
# {
#   "tenantId": "acme",
#   "traceId": "t-001",
#   "payload": "hello"
# }

# 4. Bench.
ghz --insecure \
    --proto ./proto/gateway.proto \
    --import-paths ./proto \
    --call examples.Gateway/Passthrough \
    --total 5000 --concurrency 256 --connections 16 \
    -d '{"tenant_id":"acme","trace_id":"t-001","payload":"hello"}' \
    127.0.0.1:50071
```

## Decomposing 061 vs 062

Run both, then subtract:

| Workload | RPS | µs/req | Cost source |
|---|---:|---:|---|
| **062 passthrough (this)** | _ceiling_ | _floor_ | gRPC adapter + HTTP/2 + workflow plumbing |
| **061 V-Rule fastpath** | lower | + V-Rule eval | + 6-mapping decision + proto encode `RiskResponse` |
| **Δ (062 − 061)** | | ≈ V-Rule cost | per-request V-Rule + proto encode |

Microbench from `2026-05-03-fastpath-grpc-vs-webhook-gap-analysis.md`
predicts the V-Rule + proto encode delta to be ~3.5 µs/req. So
expected ratio is roughly:

- 062 ≈ 30,000–35,000 RPS (pure transport + plumbing floor)
- 061 ≈ 28,945 RPS (measured)
- Δ ≈ 3-6 µs/req of V-Rule + encode

If 062 measures **much** higher than that delta predicts, it indicates
extra plumbing cost in V-Rule dispatch worth investigating. If it
measures close to 061, the V-Rule path is well-optimized and remaining
gap is structurally in the transport layer.

## Use cases for this pattern in production

Beyond benchmarking, a "transformation-free passthrough" workflow is
useful for:

- **API gateway shim** — accept a gRPC call, route to detached
  side-effects (audit log, metrics), respond fast. Add a Connector
  on a detached branch (no impact on response latency).
- **Health probe** — RPC-style liveness/readiness with the same wire
  contract as the rest of the service.
- **Load test fixture** — to measure the full HTTP/2-over-TCP +
  vflow plumbing cost without compute noise. Critical for capacity
  planning.
