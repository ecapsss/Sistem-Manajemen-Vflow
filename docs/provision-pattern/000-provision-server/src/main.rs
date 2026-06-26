// 000-provision-server — "how to run the provision server", zero handlers.
//
// This is the reference entry point for vflow's provisionable deploy mode.
// Unlike the vwfd-compile-time examples (which pre-register handlers and
// pre-load yamls via `vflow_server::app(...).native(...).wasm(...)`), this
// binary boots a stock vflow-server: ports open, admin API live, NO
// workflows or handlers registered at startup. Everything is pushed in at
// runtime over HTTP:
//
//   POST /api/admin/workflow/upload   — upload VWFD YAML (or VWFC binary)
//   POST /api/admin/wasm/upload       — upload .wasm module
//   POST /api/admin/plugin/upload     — upload .so NativeCode plugin
//   POST /api/admin/sidecar/register  — register a stdin/stdout sidecar
//   POST /api/admin/vrule/compile     — compile + store a VRule pack
//
// The bootstrap below is literally what `vflow-server`'s main.rs does —
// copy this file into your own crate and you have a fully-featured
// provisionable server ready to receive uploads.
//
// See README.md alongside this file for the curl commands to drive it.

use vflow_server::{
    bootstrap::{self, BootstrapConfig},
    init_logger_from_env,
};
// Re-exported to keep `_log` typed — holds the vil_log drain task
// alive for the lifetime of main (or None when VIL_LOG_OFF=1).
#[allow(unused_imports)]
use vil_log::VilLogGuard;

#[tokio::main]
async fn main() {
    // Delegate log init to the library helper so all consumers share
    // the same env-var surface (VFLOW_DEV / VFLOW_DEBUG / VIL_LOG_OFF).
    // The returned guard keeps the vil_log SPSC task alive when it's
    // running; `None` when VIL_LOG_OFF=1 (tracing-subscriber fallback).
    let _log = vflow_server::init_logger_from_env();

    // `BootstrapConfig::from_env()` reads VFLOW_PORT / VFLOW_PIPELINE_PORT /
    // VFLOW_HTTP_ENABLED / VFLOW_HTTP_PORT / VFLOW_STATE_DIR / VFLOW_ADMIN_KEY
    // / VFLOW_WEBHOOK_KEY. Defaults: admin=7799, pipeline=7800, http disabled.
    //
    // For a hands-on walk-through with port 47799/47800/47801 and state
    // durability enabled, run:
    //
    //   VFLOW_PORT=47799 VFLOW_PIPELINE_PORT=47800 \
    //   VFLOW_HTTP_ENABLED=1 VFLOW_HTTP_PORT=47801 \
    //   VFLOW_STATE_DIR=/tmp/vflow-provision \
    //   cargo run --release
    let cfg = BootstrapConfig::from_env();
    bootstrap::run_server(cfg).await;
}
