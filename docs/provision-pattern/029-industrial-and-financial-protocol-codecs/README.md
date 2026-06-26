# 029 Industrial And Financial Protocol Codecs

Scenario: an edge payment and telemetry gateway receives a card-present
transaction, builds an ISO8583 authorization payload, emits canonical
Protobuf/MessagePack envelopes, notifies local WebSocket operators, and declares
industrial SOAP/Modbus/OPC-UA integration points.

This example is part of the default compile regression. The live-safe smoke
executes only stateless or loopback-safe paths:

```bash
bash examples-vflow/runtime-smoke/protocol-codecs-live-safe-smoke.sh
```

Coverage:

- ISO8583 encode/decode for payment rails.
- Protobuf and MessagePack encode/decode for internal event contracts.
- WebSocket broadcast on an empty local server as a no-client safe operation.
- SOAP, Modbus, and OPC-UA connector declarations for lab-backed industrial
  integration. These need real simulators/endpoints before docs can claim live
  E2E behavior.
