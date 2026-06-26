# 013 — gRPC inbound trigger (byte-first)

Demonstrates vflow's inbound gRPC trigger landing on a workflow via
the **byte-first** payload pattern. No codegen, no .proto compile
step in vflow; all schema interpretation happens at the activity
layer via `Connector(protobuf)`.

## Files

- `workflow.yaml` — the workflow. Trigger (grpc) → Codec decode →
  Codec encode → EndTrigger.
- `proto/cloud_control.proto` — the gRPC contract (`cloud.CloudControl.ProvisionTenant`).
  Uploaded to vflow for reflection-less clients. Not strictly
  required for the runtime (adapter is schema-less).
- `test.sh` — end-to-end smoke: starts vflow-server, waits for
  both the admin registry and the kernel's WorkflowRouter to
  converge, invokes via `grpcurl`, checks the response.

## Run

Prereqs on `$PATH`: `vflow-server`, `grpcurl`, `curl`, `python3`.

```bash
./test.sh
# → [013] PASS
# → {"tenantId":"tenant-acme","status":"provisioned", ...}
```

Environment variables it honours (defaults shown):

| Var | Default |
|-----|---------|
| `VFLOW_ADMIN_PORT` | `7799` |
| `VFLOW_PIPELINE_PORT` | `7800` |
| `VFLOW_GRPC_PORT` | `50051` |

The test mkdtemps a state dir + pre-seeds
`${STATE_DIR}/grpc_server.json` with `{"enabled":true, "port":…}`
so the adapter binds on boot without an explicit
`POST /api/admin/grpc/start`.

## What the workflow exercises

Shape of `execute_wired_with_handles` in the kernel + the
byte-first path through `kernel_process::run_kernel_worker`:

```
grpcurl
  → gRPC frame over HTTP/2 (hyper h2c)
  → vflow grpc_adapter: unframe → raw protobuf bytes
  → POST /grpc/cloud.CloudControl/ProvisionTenant with
    Content-Type: application/x-protobuf (no JSON envelope)
  → vflow pipeline webhook sink (bytes pass-through)
  → kernel_process: scans graph for `trigger_body` reference,
    materialises bytes as Vec<u8>, passes as DataHandle preset
  → kernel.execute_wired_with_handles stores handle-only var
  → workflow activity `decode_request`:
      v-cel: trigger_body
      → VariableStore::get_with_bytes_fallback returns base64
      → ProtobufCodec decodes with inline schema → typed JSON
  → workflow activity `encode_response`:
      ProtobufCodec encodes typed JSON → base64 string
  → EndTrigger spv1: $.resp.encoded
  → adapter base64-decodes response body
  → adapter frames + HTTP/2 trailers (grpc-status: 0)
  → grpcurl decodes typed protobuf
```

## Business-logic extension point

The `encode_response` activity currently uses a `literal` JSON.
Real workflows would compute response fields from `$.req.*` using
`v-cel` or `vil-expr`, or insert a VRule / Function activity in
between decode and encode.

```yaml
- id: encode_response
  ...
  input_mappings:
    - target: data
      source:
        language: v-cel
        source: >
          {
            "tenant_id": "tenant-" + string(req.tenant_name),
            "status":    "provisioned",
            "note":      "plan=" + string(req.plan)
          }
```

## Related phases

- **C.1** — adapter is pure transport (DynamicMessage removed).
- **C.2** — kernel gains `execute_wired_with_handles`; webhook
  body flows in as a `DataHandle` preset.
- **C.3** (this example) — Tier 0/1 expressions resolve
  DataHandle-backed vars via `get_with_bytes_fallback`; adapter
  drops the base64+JSON envelope.
- **C.4** (future) — EndTrigger emits `DataHandle` output so the
  response side also skips the re-encode round-trip.
