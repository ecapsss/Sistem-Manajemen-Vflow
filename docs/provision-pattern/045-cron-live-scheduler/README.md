# 045 Cron Live Scheduler

Local-safe runtime smoke for the `cron` trigger. The workflow uses a short
`100ms` schedule, posts the fired trigger payload into a local HTTP capture
server, and ends without a client response path.

Run:

```bash
bash examples-vflow/runtime-smoke/cron-live-scheduler-smoke.sh
```

Expected signal:

```text
CRON_LIVE_SCHEDULER_SMOKE_OK
```
