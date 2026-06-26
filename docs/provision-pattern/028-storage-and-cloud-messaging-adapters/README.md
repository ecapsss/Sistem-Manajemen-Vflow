# 028 Storage And Cloud Messaging Adapters

Scenario: a billing runtime receives a finalized invoice, stores the canonical
archive object, mirrors it to cloud storage providers, drops a partner manifest,
and publishes downstream notifications to messaging adapters.

This example is a workflow-level contract for storage and cloud messaging
adapter shapes. It is part of the default compile regression. Live execution is
split:

```bash
bash examples-vflow/runtime-smoke/storage-cloud-messaging-adapters-smoke.sh
```

Storage behavior:

- S3/SeaweedFS stores the canonical invoice archive.
- GCS and Azure Blob show provider-specific mirror operations.
- SFTP drops a partner manifest for batch integrations.

Messaging behavior:

- NATS publishes the runtime-local event used by VFlow deployments.
- Kafka, MQTT, RabbitMQ, Pulsar, Pub/Sub, and SQS publish declarations are kept
  in one business flow so the public connector surface is visible.

Live smoke is intentionally skip-aware. S3/SeaweedFS, SFTP, and NATS can be
validated locally when endpoints are present. Cloud-provider and heavyweight
broker adapters remain provider/lab optional until credentials and simulators
are configured.
