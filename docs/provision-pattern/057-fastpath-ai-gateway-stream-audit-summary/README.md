# 057 Fastpath AI Gateway Stream Audit Summary

Fastpath AI gateway streaming benchmark with request-level `metadata.audit_log`.
The workflow streams chunks to the client through `vastar.http` and emits one
audit envelope when the request finishes. The audit envelope captures counters
such as `bytes_out` and `chunks_out`; it does not log per chunk and does not
buffer the full stream.

```bash
VFLOW_NATS_URL=nats://127.0.0.1:4222 \
SCENARIOS="018-ai-gateway-simulator 057-fastpath-ai-gateway-stream-audit-summary" \
TOOLS="vastar wrk" \
MODE=requests \
REQUESTS=5000 \
CONCURRENCY=300 \
bash benchmark-vflow/run-primary.sh
```
