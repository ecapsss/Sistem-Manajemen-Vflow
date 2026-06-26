# 042 Trigger Dispatch P1

Business-oriented runtime smoke for trigger sources that are not direct webhook calls.
The workflows forward each fired trigger to a local capture endpoint so the smoke
can assert that the TriggerRegistry dispatch path entered the kernel and executed
a connector side effect.

Covered locally:
- `db_poll` against SQLite.
- `fs` directory watcher.

Covered when NATS is available:
- `nats_js` JetStream durable consumer.
- `nats_kv` JetStream KV watcher.

SFTP is kept as a skip-aware external-infra declaration until a local SFTP lab is
provided to the smoke runner.
