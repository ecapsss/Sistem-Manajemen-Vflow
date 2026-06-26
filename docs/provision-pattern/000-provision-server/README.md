# 000-provision-server — reference entry point for provisionable mode

A minimal Rust binary showing how to boot vflow's **provisionable** server
— no compile-time handlers, no pre-loaded workflows, **no yaml bundled**.
Everything (yaml / wasm / sidecar / native plugin / vrule pack) is pushed
in at runtime via the admin API.

This is the provision-pattern starter. Copy `src/main.rs` into your own
crate and you have a full vflow-server ready to receive uploads.

## Layout

```
000-provision-server/
├── Cargo.toml          # deps: vflow_server, tokio, vil_log
├── src/main.rs         # calls bootstrap::run_server(BootstrapConfig::from_env())
└── README.md
```

The directory is intentionally empty of workflow yamls — this example
exists only to show the server bootstrap. For a workflow to upload
against it, look at the sibling patterns (`001-multi-tenant`,
`002-hot-reload`, … each has its own `workflow.yaml`).

## Run

```bash
# 1. Build + start the server. BootstrapConfig::from_env() reads env vars.
cd 000-provision-server
VFLOW_PORT=47799 \
VFLOW_PIPELINE_PORT=47800 \
VFLOW_HTTP_ENABLED=1 \
VFLOW_HTTP_PORT=47801 \
cargo run --release &

# Equivalent to running the stock `./vflow-server` binary — just wrapped
# as an example crate you can edit freely.

# 2. Confirm the admin API is live
curl "http://localhost:47799/api/admin/health"
# → {"status":"healthy","engine":"vwfc-zero-copy","workflows_loaded":0,...}

# 3. Upload any sibling pattern's workflow via admin API, e.g.
curl -X POST \
    -H "Content-Type: application/yaml" \
    -H "X-Tenant-Id: _default" \
    --data-binary @../001-multi-tenant/workflow.yaml \
    "http://localhost:47799/api/admin/workflow/upload"
```

## What this proves

- `vflow_server::bootstrap::run_server` is the single source of truth —
  both this example and the production `vflow-server` binary funnel
  through it.
- Server starts with zero workflows and zero handlers loaded; `health`
  reports `workflows_loaded: 0`.
- Once a yaml is uploaded the background watcher (~1s poll) picks it up
  and registers the webhook route against the raw-TCP ingress.

## Where to go next

- Want programmatic handlers baked into the binary? See
  `../../vwfd-compile-time/*` — each smoke calls
  `vflow_server::app(...).native(...).wasm(...).sidecar(...)`.
- Want tenant-scoped routing / hot-reload / blue-green versioning / saga
  rollback? Walk through the numbered siblings (`001-multi-tenant`,
  `002-hot-reload`, `003-workflow-versioning`, …) — each yaml highlights
  one provision-pattern feature.
