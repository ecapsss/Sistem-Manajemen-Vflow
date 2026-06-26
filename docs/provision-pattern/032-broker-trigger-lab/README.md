# 032 Broker Trigger Lab

Scenario: an event ingress workflow accepts order events from broker triggers,
normalizes the envelope, and fans the message out to broker families used by
enterprise integrations.

This is a lab/provider example. It is part of the compile regression and is
validated by:

```bash
bash examples-vflow/runtime-smoke/broker-trigger-lab-smoke.sh
```

Current boundary:

- Kafka and MQTT have typed Trigger YAML blocks today.
- RabbitMQ, Pulsar, Pub/Sub, and SQS are represented as Connector activities
  until their runtime trigger adapters are added to the VWFD trigger schema.
- NATS trigger/connector E2E remains covered by `026-nats-event-driven-orders`.

Failure semantics:

- Publish/send connector errors are treated as retryable only when the broker
  failure is connection/timeout/rate-limit class and the workflow preserves the
  `idempotency_key`.
- Side-effecting broker fanout is marked `persistence: ssot`.
- Missing broker endpoints in smoke are `SKIP` by default and fail only under
  strict mode.
