#!/usr/bin/env bash
# =============================================================================
# 013-grpc-trigger — end-to-end smoke test
# =============================================================================
#
# Boots vflow-server with the gRPC adapter enabled, provisions the
# workflow + .proto, invokes it via grpcurl, and compares against a
# fixture. Exits 0 on match.
#
# Prereqs on PATH:  vflow-server, grpcurl, curl, python3

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VFLOW_ADMIN_PORT="${VFLOW_ADMIN_PORT:-7799}"
VFLOW_PIPELINE_PORT="${VFLOW_PIPELINE_PORT:-7800}"
VFLOW_GRPC_PORT="${VFLOW_GRPC_PORT:-50051}"
STATE_DIR="$(mktemp -d)"
trap 'rm -rf "${STATE_DIR}"; [[ -n "${VFLOW_PID:-}" ]] && kill "${VFLOW_PID}" 2>/dev/null || true' EXIT

# Pre-seed grpc adapter state so it binds on boot (skips the
# admin `POST /grpc/start` call).
cat >"${STATE_DIR}/grpc_server.json" <<EOF
{"enabled": true, "port": ${VFLOW_GRPC_PORT}}
EOF

echo "[013] starting vflow-server"
VFLOW_PORT="${VFLOW_ADMIN_PORT}" \
VFLOW_PIPELINE_PORT="${VFLOW_PIPELINE_PORT}" \
VFLOW_WORKFLOWS_DIR="${HERE}" \
VFLOW_STATE_DIR="${STATE_DIR}" \
VIL_LOG_OFF=1 \
  vflow-server >"${STATE_DIR}/vflow.log" 2>&1 &
VFLOW_PID=$!

# Wait for admin port.
for _ in $(seq 1 30); do
    if curl -sf -o /dev/null "http://127.0.0.1:${VFLOW_ADMIN_PORT}/api/admin/health"; then
        break
    fi
    sleep 0.2
done

# Wait for the workflow webhook route to register. The admin port
# opens before the workflow watcher has scanned VFLOW_WORKFLOWS_DIR,
# so `/health` being 200 isn't enough.
registered=0
for _ in $(seq 1 100); do
    body=$(curl -sf "http://127.0.0.1:${VFLOW_ADMIN_PORT}/api/admin/health" || true)
    if printf '%s' "${body}" | grep -q '/grpc/cloud.CloudControl/ProvisionTenant'; then
        registered=1
        break
    fi
    sleep 0.2
done
if [[ "${registered}" != "1" ]]; then
    echo "[013] FAIL: workflow never registered the webhook route"
    echo "--- vflow log tail ---"
    tail -30 "${STATE_DIR}/vflow.log" 2>&1 || true
    exit 1
fi

echo "[013] uploading .proto (both for client AND server-side descriptor binding)"
curl -sf -X POST "http://127.0.0.1:${VFLOW_ADMIN_PORT}/api/admin/proto/upload" \
     -H 'X-VFlow-Proto-File: cloud_control.proto' \
     -H 'Content-Type: text/plain' \
     --data-binary "@${HERE}/proto/cloud_control.proto" >/dev/null

# Phase 1: proto_registry upload must complete BEFORE the workflow's
# first webhook hit, otherwise `body_schema: "cloud.ProvisionRequest"`
# resolves to None → kernel falls back to opaque-bytes binding →
# `trigger_body.tenant_name` returns null. Small pause to let the
# admin endpoint's write settle.
sleep 0.2

# Poll the pipeline port until the kernel's WorkflowRouter has
# picked up the route. `admin.workflows.webhook_routes()` reflects
# the ADMIN registry — the kernel watcher copies that into its own
# router on a 1s poll tick, so the two can be briefly out of sync.
# A probe that triggers "no workflow" vs. any other response tells
# us the kernel side is ready.
for _ in $(seq 1 100); do
    code=$(curl -s -o /dev/null -w '%{http_code}' \
        -H 'Content-Type: application/x-protobuf' \
        --data-binary $'\x0a\x04ping\x12\x03chk' \
        -X POST "http://127.0.0.1:${VFLOW_PIPELINE_PORT}/grpc/cloud.CloudControl/ProvisionTenant" || true)
    body_has_nowf=$(curl -s \
        -H 'Content-Type: application/x-protobuf' \
        --data-binary $'\x0a\x04ping\x12\x03chk' \
        -X POST "http://127.0.0.1:${VFLOW_PIPELINE_PORT}/grpc/cloud.CloudControl/ProvisionTenant" \
        2>/dev/null | grep -c 'no workflow for path' || true)
    if [[ "${code}" == "200" && "${body_has_nowf}" == "0" ]]; then
        break
    fi
    sleep 0.2
done

echo "[013] invoking cloud.CloudControl/ProvisionTenant via grpcurl"
set +e
out=$(grpcurl -plaintext \
    -import-path "${HERE}/proto" -proto cloud_control.proto \
    -d '{"tenant_name":"acme","plan":"pro"}' \
    "127.0.0.1:${VFLOW_GRPC_PORT}" cloud.CloudControl/ProvisionTenant 2>&1)
rc=$?
set -e
if [[ "${rc}" -ne 0 ]]; then
    echo "[013] FAIL: grpcurl rc=${rc}"
    echo "        ${out}"
    echo "--- vflow log tail ---"
    tail -30 "${STATE_DIR}/vflow.log" 2>&1 || true
    exit 1
fi

expected_tenant_id='tenant-acme'
expected_note='Phase 1 CEL typed binding + Transform encode'
got_tenant_id=$(printf '%s' "${out}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tenantId",""))')

if [[ "${got_tenant_id}" != "${expected_tenant_id}" ]]; then
    echo "[013] FAIL: expected tenantId=${expected_tenant_id}, got=${got_tenant_id}"
    echo "        full response: ${out}"
    echo "--- vflow log tail ---"
    tail -30 "${STATE_DIR}/vflow.log" 2>&1 || true
    exit 1
fi

echo "[013] PASS"
echo "${out}"
