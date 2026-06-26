# 043 Broker and Storage Trigger Dispatch

Runtime E2E fixtures for provider-backed event triggers. Each workflow is
single-trigger by design so the blackbox smoke can prove route-to-workflow
dispatch without mixing response-oriented webhook semantics into fire-and-
forget trigger execution.

- `workflow-mqtt.yaml`: MQTT broker publish -> runtime trigger -> HTTP capture.
- `workflow-kafka.yaml`: Kafka topic publish -> runtime trigger -> HTTP capture.
- `workflow-s3-event.yaml`: S3 bucket notification through SQS -> runtime trigger -> HTTP capture.

Run:

```bash
VFLOW_043_BOOTSTRAP=heavy bash examples-vflow/runtime-smoke/broker-storage-trigger-dispatch-smoke.sh
```
