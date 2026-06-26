# 064 vflow Plain Gateway (no scripting)

Apple-to-apple comparator for **Envoy plain proxy** (no Lua filter).
This workflow is the *minimal* vflow gRPC gateway: just Connector
forward + proto_encode response. **No V-Starlark, no validation,
no scripting** — pure proxy plumbing.

## Why this exists

063 (V-Starlark) vs Envoy + Lua isn't quite apple-to-apple because
the comparison conflates two costs:
- **Structural proxy cost** (Connector framework, proto codec, runtime dispatch)
- **Scripting language cost** (V-Starlark interpreter vs Lua interpreter)

064 isolates the structural cost. Compare:
- 064 vs Envoy plain (B) → vflow proxy plumbing vs Envoy proxy plumbing
- 063 vs 064 → V-Starlark cost (in vflow context)
- D vs B → Lua cost (in Envoy context)

## Activities

| # | Type | Logic |
|---|---|---|
| 1 | Trigger (gRPC, fastpath) | `examples.GatewayPlain/Passthrough`, body=`GatewayMessage` |
| 2 | Transform (v-cel) | `build_request`: extract trigger fields into JSON object |
| 3 | Connector (gRPC unary) | `vastar.grpc` forward to `examples.Gateway/Passthrough` |
| 4 | Transform (v-cel) | `proto_encode(...)` JSON → `GatewayMessage` proto bytes |
| 5 | EndTrigger | `bytes_ref` to encoded bytes |
| 6 | End | |

No Compute / V-Starlark anywhere. Each step is irreducible plumbing
required for vflow to act as a gRPC gateway.

## Bench results (5-cell head-to-head)

c=512 conn=32, total=30k, peak of 3 runs:

| Cell | Setup | Peak RPS | µs/req | Overhead vs A |
|---|---|---:|---:|---:|
| A | Direct 062 (no gateway) | 45,649 | 21.9 | baseline |
| B | Envoy plain proxy → 062 | 31,492 | 31.8 | +9.9 µs |
| **E (this)** | **vflow 064 plain → 062** | **11,291** | 88.6 | **+66.7 µs** |
| C | vflow 063 + V-Starlark → 062 | 10,963 | 91.2 | +69.3 µs |
| D | Envoy + Lua → 062 | 27,550 | 36.3 | +14.4 µs |

## Key finding: scripting language is NOT the bottleneck

| Comparison | Cost added by scripting |
|---|---:|
| **D − B** = Envoy + Lua − Envoy plain | **+4.5 µs** (Lua filter cost) |
| **C − E** = vflow + V-Starlark − vflow plain | **+2.6 µs** (V-Starlark cost) |

**V-Starlark is roughly tied with Lua, possibly slightly faster.**

The 3× gap between vflow gateway and Envoy gateway (66.7 µs vs 9.9 µs
plain-proxy overhead) is **structural to vflow's proxy plumbing**, NOT
the scripting language:

- gRPC connector framework: input encode (JSON → DynamicMessage → bytes)
  + outbound TCP/HTTP-2 + receive + response decode (bytes →
  DynamicMessage → JSON). ~30-40 µs.
- proto_encode FaaS for response: ~5-8 µs.
- Standard fastpath plan dispatch + variable store ops: ~10-20 µs.
- Workflow node-graph traversal: ~10 µs.

Envoy gets away with much less because:
- Tower stack routes without re-encoding the body
- Connection pool to upstream is hot
- No DynamicMessage roundtrip (just byte-pass)

## Reproduction

Same harness as 063 (see `063-vflow-gateway-vstarlark/README.md`)
with port 50071 and method `examples.GatewayPlain/Passthrough`.

```bash
ghz --insecure --proto ./proto/gateway.proto --import-paths ./proto \
    --call examples.GatewayPlain/Passthrough \
    --total 30000 --concurrency 512 --connections 32 \
    -d '{"tenant_id":"acme","trace_id":"t-001","payload":"hello"}' \
    127.0.0.1:50071
```

## Files

- `proto/gateway.proto` — combined proto with 3 services (062 Gateway, 063 GatewayProxy, 064 GatewayPlain)
- `gateway.desc.b64` — pre-computed FileDescriptorSet
- `workflow.yaml` — plain gateway (4 nodes, no scripting)
- Sister: `063-vflow-gateway-vstarlark/` — same workflow + V-Starlark scripting
- Sister: `062-fastpath-grpc-passthrough/` — shared upstream
