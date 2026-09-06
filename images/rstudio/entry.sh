#!/usr/bin/env bash
# RStudio Server as the unprivileged user (no /init, no root, no PAM):
# https://osc.github.io/ood-documentation (interactive apps) pattern.
set -euo pipefail
. /opt/vice/bin/vice-entry
vice::boot
run=/tmp/rstudio-run; mkdir -p "$run" "$HOME/.local/share/rstudio"
cat > "$run/db.conf" <<CONF
provider=sqlite
directory=$run/db
CONF
cat > "$run/rsession.conf" <<CONF
session-default-working-dir=$HOME/data-store
session-default-new-project-dir=$HOME/work
CONF
exec rserver --server-daemonize=0 --server-user="$(id -un)" --auth-none=1 \
  --www-address=0.0.0.0 --www-port=8787 --www-frame-origin=any \
  --server-data-dir="$run" --database-config-file="$run/db.conf" --rsession-config-file="$run/rsession.conf" \
  --server-pid-file="$run/rserver.pid" --server-set-umask=0
