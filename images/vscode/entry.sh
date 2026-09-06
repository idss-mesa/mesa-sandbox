#!/usr/bin/env bash
set -euo pipefail
. /opt/vice/bin/vice-entry
vice::boot
# extensions the fleet ships today; installed per user home on first boot (idempotent, offline-safe)
for ext in ms-python.python ms-toolsai.jupyter; do code-server --install-extension "$ext" >/dev/null 2>&1 || true; done
exec code-server --bind-addr 0.0.0.0:8080 --auth none --disable-telemetry --disable-update-check "${HOME}/data-store"
