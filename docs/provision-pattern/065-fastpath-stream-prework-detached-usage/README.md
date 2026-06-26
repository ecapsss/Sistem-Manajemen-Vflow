# 065 Fastpath Stream Prework Detached Usage

This example is the documented version of the Acisku `/api/ai/analyze`
dogfooding pattern:

- `runtime_mode: fastpath` is declared on the webhook trigger.
- Auth, quota reads, and quota guard run before the streaming connector.
- The AI call uses `vastar.http` with `streaming: true`, `format: sse`,
  `dialect: openai`, connector-native `json_tap`, and the local
  `ai-endpoint-simulator` at `http://127.0.0.1:4545`.
- The streaming connector intentionally has no `output_variable`; the runtime
  forwards chunks to the client without collecting the full stream body.
- Usage accounting is a detached branch from the streaming connector, so it runs
  after stream acceptance without blocking the client response.
- The sqlite connection resolves through `pack://examples/acisku/primary`,
  provided by `examples-vflow/packs/acisku/pack.yaml`.

This is the local benchmark form of the pattern. Production packs should replace
the local x-user-uid fallback with Firebase/RS256 token verification.

The workflow is heavily commented because it is meant as an authoring guide.
Use it when building business endpoints that need request validation or quota
checks before an SSE/LLM response.

## Runtime shape

```text
Trigger
  -> auth_context
  -> quota_feature_context
  -> load_usage_count
  -> quota_gate
  -> call_ai_stream  --stream bytes--> client
       | detached
       v
     insert_usage_tracking
```

If quota is exceeded, the graph reaches `respond` before the stream connector
and returns the JSON quota error instead of opening the stream.

## Reproduce

```bash
SCENARIOS="065-fastpath-stream-prework-detached-usage" \
TOOLS="wrk" \
MODE=requests \
REQUESTS=100 \
bash benchmark-vflow/run-primary.sh
```
