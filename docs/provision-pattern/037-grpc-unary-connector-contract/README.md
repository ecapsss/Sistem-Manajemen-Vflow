# 037 gRPC Unary Connector Contract

Business story: a runtime workflow checks an internal service capability before
accepting a command. The connector call uses a descriptor-backed unary gRPC
request, not generated client code.

Covered surface:

- Webhook trigger.
- `activity_type: Connector` with `connector_ref: vastar.grpc`.
- Descriptor-backed `operation: call`.
- JSON request encoding to protobuf and protobuf response decoding to JSON.
- Real local tonic health server smoke.

Run:

```bash
bash examples-vflow/runtime-smoke/grpc-unary-connector-contract-smoke.sh
```

Expected response:

```json
{
  "status": "grpc_unary_ok",
  "health_status": "SERVING",
  "service": "pricing-control"
}
```
