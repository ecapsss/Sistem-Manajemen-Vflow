# 034 Email Approval Notification

This example demonstrates the runtime-local email path:

- `email` trigger declaration for inbound IMAP-style mail events.
- V-CEL FaaS dispatch to `send_email(...)` for outbound SMTP notification.
- Local smoke mode with `VFLOW_EMAIL_TRIGGER_MOCK=1`, so the example can run
  without an external IMAP account.

Run:

```bash
bash examples-vflow/runtime-smoke/email-approval-notification-smoke.sh
```

The smoke starts a local SMTP mock, starts a real `vflow-server`, injects a
mock email trigger event, and asserts the outbound email was delivered to the
mock SMTP server.
