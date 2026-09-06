#!/usr/bin/env bash
# agent-runner entrypoint: shared boot (anonymous iRODS env, configs, no
# dotfile import), then exec the harness command passed by the launcher, e.g.
#   claude -p --bare --permission-mode dontAsk --max-budget-usd 2 "..."
#   codex exec -s workspace-write -a never "..."
#   agent -p --force --trust "..."
set -euo pipefail
. /opt/vice/bin/vice-entry
export VICE_IMPORT_DOTFILES=0
vice::boot
exec "$@"
