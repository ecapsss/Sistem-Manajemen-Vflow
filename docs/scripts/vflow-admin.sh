#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v node >/dev/null 2>&1; then
  echo "error: node is required for scripts/vflow-admin.sh" >&2
  exit 1
fi

exec node "$SCRIPT_DIR/vflow-admin.js" "$@"
