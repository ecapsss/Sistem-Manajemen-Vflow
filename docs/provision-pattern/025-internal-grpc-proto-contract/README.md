# 025 Internal gRPC Proto Contract

Runtime-local gRPC contract example for internal service traffic.

It demonstrates:

- inbound gRPC trigger registration
- typed protobuf field binding via `trigger_body.*`
- protobuf response encoding with `final_response.encoding: base64`
- runtime-local gRPC server start through `VFLOW_STATE_DIR/grpc_server.json`

```bash
VFLOW_EXAMPLES_WITH_GRPC_LIVE=1 \
  bash examples-vflow/run-all-local.sh
```

This is intended for vflow-cloud, Firecracker, and internal services. The user
workflow console should expose REST for normal workflow provisioning and
operations.
