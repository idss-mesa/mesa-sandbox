#!/usr/bin/env bash
# Runs inside Kasm's vnc_startup.sh after the desktop starts (KASM custom startup hook).
set -uo pipefail
. /opt/vice/bin/vice-entry
vice::boot || true
# keep the hook alive as Kasm expects a long-running custom_startup
while true; do sleep 3600; done
