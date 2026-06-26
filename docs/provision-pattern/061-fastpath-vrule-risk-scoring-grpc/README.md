# 061 Fastpath V-Rule Risk Scoring (gRPC)

Apple-to-apple comparator for `047-fastpath-vrule-risk-scoring`, with
the trigger swapped from HTTP webhook to inbound gRPC server. Both
workflows run on the **fastpath runtime** — the kernel-state-machine-
bypassed inline executor — so this isolates pure protocol overhead
(gRPC vs HTTP) on the fastest path vflow offers.

| Aspect           | 047 (HTTP webhook fastpath)             | 061 (gRPC server fastpath, this example) |
|------------------|-----------------------------------------|------------------------------------------|
| Trigger          | webhook `POST /bench/fastpath/vrule-risk` | grpc `examples.RiskScoring/ScoreRisk` |
| Wire format      | JSON over HTTP/1.1                      | protobuf over HTTP/2                     |
| V-Rule pack      | `fastpath_risk_v1`                      | `fastpath_risk_v1` (same)                |
| Input fields     | 6 (amount, country, card_bin, merchant_category, customer_tier, velocity_1h) | same 6 (typed via proto descriptor) |
| Decision shape   | full `risk_result` JSON                 | `RiskResponse` proto (decision + total_score + findings_count) |
| Runtime          | fastpath                                | fastpath                                 |
| Activities       | Trigger → VRule → EndTrigger → End (4)  | same 4 (no Transform encode)             |

## Why a separate workflow vs 060?

`060-standard-vrule-risk-scoring-grpc` is the **standard runtime**
variant, mirroring `049` webhook standard. `061` is the **fastpath**
variant, mirroring `047` webhook fastpath. Two workflows because the
two webhook anchors run on different runtimes and the apple-to-apple
matrix needs both:

| | webhook | gRPC |
|---|---|---|
| **standard** | 049 | 060 |
| **fastpath** | 047 | **061 (this)** |

## Bench

Use the same harness pattern as 047 (pre-load proto, upload V-Rule
pack, then upload workflow via admin so fastpath plan-builder sees
the pack):

```bash
mkdir -p $STATE_DIR
echo '{"enabled":true,"port":50071}' > $STATE_DIR/grpc_server.json

VFLOW_PORT=18193 VFLOW_PIPELINE_PORT=18194 \
VFLOW_STATE_DIR=$STATE_DIR \
VFLOW_AUDIT_EMITTER=none VIL_LOG_OFF=1 \
vflow-server &

# 1. Upload proto descriptor (REQUIRED before pack so descriptor
#    is in pool when V-Rule pack-load tries to resolve
#    bind_proto / output_proto_schema).
curl -X POST http://127.0.0.1:18193/api/admin/proto/upload \
     -H 'X-VFlow-Proto-File: risk_scoring.proto' \
     -H 'Content-Type: text/plain' \
     --data-binary @./proto/risk_scoring.proto

# 2. Upload V-Rule pack.
curl -X POST http://127.0.0.1:18193/api/admin/vrule/compile \
     -H 'Content-Type: application/json' \
     -d "$(jq -n \
            --rawfile r ../047-fastpath-vrule-risk-scoring/rules/fastpath_risk_v1.vdicl \
            --rawfile s ../047-fastpath-vrule-risk-scoring/schemas/fastpath_risk_fact_v1.yaml \
            '{rule_set_id: "fastpath_risk_v1", rules_yaml: $r, schema_yaml: $s}')"

# 3. Upload workflow (after pack so fastpath plan-build sees the pack).
curl -X POST http://127.0.0.1:18193/api/admin/workflow/upload \
     -H 'Content-Type: application/yaml' \
     --data-binary @./workflow.yaml

# 4. Smoke.
grpcurl -plaintext \
    -import-path ./proto -proto risk_scoring.proto \
    -d '{"amount":25000000,"country":"SG","card_bin":"411111","merchant_category":"retail","customer_tier":"gold","velocity_1h":2}' \
    127.0.0.1:50071 examples.RiskScoring/ScoreRisk

# Expected:
# {
#   "decision": "CHALLENGE_MFA",
#   "totalScore": 45,
#   "findingsCount": 1
# }

# 5. Bench.
ghz --insecure \
    --proto ./proto/risk_scoring.proto \
    --import-paths ./proto \
    --call examples.RiskScoring/ScoreRisk \
    --total 5000 --concurrency 256 --connections 16 \
    -d '{"amount":25000000,"country":"SG","card_bin":"411111","merchant_category":"retail","customer_tier":"gold","velocity_1h":2}' \
    127.0.0.1:50071
```

## Apple-to-apple matrix

| | 049 webhook standard | 060 gRPC standard | 047 webhook fastpath | **061 gRPC fastpath** |
|---|---|---|---|---|
| Runtime | standard | standard | fastpath | fastpath |
| Wire | HTTP/1.1 + JSON | HTTP/2 + proto | HTTP/1.1 + JSON | HTTP/2 + proto |
| Comparison | baseline | 049 vs 060 → protocol cost on standard | 049 vs 047 → fastpath gain on webhook | 060 vs 061 → fastpath gain on gRPC; 047 vs 061 → protocol cost on fastpath |

The 4-cell matrix isolates the two orthogonal axes:
- **Protocol** (HTTP vs gRPC, holding runtime fixed) — same-row pairs
- **Runtime** (standard vs fastpath, holding protocol fixed) — same-column pairs
