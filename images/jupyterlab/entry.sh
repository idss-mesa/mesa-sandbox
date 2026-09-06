#!/usr/bin/env bash
set -euo pipefail
. /opt/vice/bin/vice-entry
vice::boot
exec jupyter lab --no-browser --ip=0.0.0.0 --port=8888 --config=/etc/jupyter/jupyter_server_config.json
