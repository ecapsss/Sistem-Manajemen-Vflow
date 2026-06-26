# 060 Standard V-Rule Risk Scoring (gRPC)

Apple-to-apple comparator for `049-standard-vrule-risk-scoring`, with
the trigger swapped from HTTP webhook to inbound gRPC server.

| Aspect           | 049 (HTTP webhook)              | 060 (gRPC server, this example) |
|------------------|---------------------------------|---------------------------------|
| Trigger          | webhook `POST /bench/standard/vrule-risk` | grpc `examples.RiskScoring/ScoreRisk` |
| Wire format      | JSON over HTTP/1.1              | protobuf over HTTP/2            |
| V-Rule pack      | `fastpath_risk_v1`              | `fastpath_risk_v1` (same)       |
| Input fields     | 6 (amount, country, card_bin, merchant_category, customer_tier, velocity_1h) | same 6 (typed via proto descriptor) |
| Decision shape   | full `risk_result` JSON         | `RiskResponse` proto (decision + total_score + findings_count) |
| Runtime          | standard                        | standard                        |

## Why `runtime_mode: standard`?

The fastpath plan-builder rejects non-webhook trigger types at
provisioning time
(`fastpath_stream_plan` / `fastpath_transform_plan` in
`crates/vflow_server/src/vflow_http_exec.rs` enforce
`trigger_type != "webhook" → reject`). Until F2 (the fastpath gRPC
dispatcher) is implemented, the only way to run a gRPC trigger is on
the standard runtime.

When F2 lands, this example becomes the natural baseline for a future
`061-fastpath-vrule-risk-scoring-grpc` apple-to-apple mirror of `047`.
F2 scope is tracked in
`benchmark-vflow/2026-05-02-regression-047-057.md` (section "F2 —
Fastpath dispatcher for non-webhook triggers") and in the next-step
guidance from
`benchmark-vflow/2026-05-03-non-http-trigger-baseline.md`.

## Bench

Reuses the 013-grpc-trigger setup pattern (pre-seeded `grpc_server.json`
state, proto upload via `/api/admin/proto/upload`, kernel router warmup
poll).

```bash
# 1. Pre-seed gRPC adapter to bind on boot.
mkdir -p $STATE_DIR
echo '{"enabled":true,"port":50051}' > $STATE_DIR/grpc_server.json

# 2. Boot vflow-server with this workflow loaded.
VFLOW_PORT=7799 \
VFLOW_PIPELINE_PORT=7800 \
VFLOW_WORKFLOWS_DIR=./examples-vflow/provision-pattern/060-standard-vrule-risk-scoring-grpc \
VFLOW_STATE_DIR=$STATE_DIR \
VFLOW_AUDIT_EMITTER=none \
VIL_LOG_OFF=1 \
vflow-server &

# 3. Upload proto descriptor (required for typed body_schema +
#    proto_encode_typed lookup).
curl -X POST http://127.0.0.1:7799/api/admin/proto/upload \
     -H 'X-VFlow-Proto-File: risk_scoring.proto' \
     -H 'Content-Type: text/plain' \
     --data-binary @./examples-vflow/provision-pattern/060-standard-vrule-risk-scoring-grpc/proto/risk_scoring.proto

# 4. Wait for the kernel router to pick up the route (poll
#    pipeline:7800 until `no workflow for path` stops appearing).

# 5. Smoke test with grpcurl.
grpcurl -plaintext \
    -import-path ./examples-vflow/provision-pattern/060-standard-vrule-risk-scoring-grpc/proto \
    -proto risk_scoring.proto \
    -d '{"amount":25000000,"country":"SG","card_bin":"411111","merchant_category":"retail","customer_tier":"gold","velocity_1h":2}' \
    127.0.0.1:50051 examples.RiskScoring/ScoreRisk

# 6. Bench with ghz (5000 req, c=256, 16 H/2 connections).
ghz --insecure \
    --proto ./examples-vflow/provision-pattern/060-standard-vrule-risk-scoring-grpc/proto/risk_scoring.proto \
    --import-paths ./examples-vflow/provision-pattern/060-standard-vrule-risk-scoring-grpc/proto \
    --call examples.RiskScoring/ScoreRisk \
    --total 5000 --concurrency 256 --connections 16 \
    -d '{"amount":25000000,"country":"SG","card_bin":"411111","merchant_category":"retail","customer_tier":"gold","velocity_1h":2}' \
    127.0.0.1:50051
```

## Apple-to-apple matrix once benched

| Comparison        | What it isolates                                       |
|-------------------|--------------------------------------------------------|
| 049 vs 060        | Pure protocol overhead (HTTP webhook → gRPC server) on the same V-Rule workload |
| 049 vs 047        | Standard runtime overhead vs fastpath runtime — already in regression report |
| 060 vs (future) 061 | Standard gRPC overhead vs fastpath gRPC — gated on F2 implementation |
