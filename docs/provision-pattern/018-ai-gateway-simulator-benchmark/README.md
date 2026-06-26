# 018 - AI Gateway Simulator Benchmark

This example is the VFlow blackbox benchmark counterpart of the older
`examples-vil/001b-vilapp-ai-gw-benchmark` scenario.

It is intentionally shaped as a workflow-product benchmark:

```text
wrk -> VFlow webhook -> HTTP streaming connector -> local AI simulator -> JSON response
```

The benchmark does not call VFlow admin, provision, runtime-console, or
operator endpoints during the measured path. Workflow upload and activation are
setup steps only.

## Runtime Contract

| Item | Value |
|---|---|
| Webhook route | `POST /api/gw/stream` |
| Upstream simulator | `http://127.0.0.1:4545/v1/chat/completions` |
| Connector | `vastar.http` |
| Streaming dialect | `openai` |
| Response shape | `{ "content": "..." }` |

## Request

```bash
curl -sS \
  -H 'Content-Type: application/json' \
  -d @payloads/trigger.json \
  http://127.0.0.1:18080/api/gw/stream
```

Expected response:

```json
{
  "content": "..."
}
```

## Benchmark Tools

Use the benchmark script from the VFlow benchmark folder:

```bash
wrk -t4 -c64 -d30s \
  -s ../../../benchmark-vflow/wrk-scripts/018-ai-gateway-simulator.lua \
  http://127.0.0.1:18080/api/gw/stream
```

Run the same scenario with Vastar Bench:

```bash
vastar -c 300 -n 5000 -m POST -T application/json \
  -D ../../../benchmark-vflow/requests/018-ai-gateway-simulator.json \
  http://127.0.0.1:18080/api/gw/stream
```

The provisionable benchmark harness runs both tools against this route and uses
`c=300` for this scenario by default:

```bash
SCENARIOS="018-ai-gateway-simulator" \
MODE=requests \
REQUESTS=5000 \
TOOLS="wrk vastar" \
bash ../../../benchmark-vflow/run-primary.sh
```

Record the simulator version, VFlow build profile, CPU governor, CPU model,
logical CPUs, RAM, swap, kernel version, concurrency, duration, latency
percentiles, request rate, error rate, and runtime RSS with every report.
