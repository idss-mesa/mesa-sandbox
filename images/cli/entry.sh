#!/usr/bin/env bash
# mesa-cli entrypoint: shared boot, then ttyd serving a tmux session.
set -euo pipefail
. /opt/vice/bin/vice-entry
vice::boot
# ~/.bashrc: conda + prompt + splash (idempotent)
grep -q 'conda.sh' "$HOME/.bashrc" 2>/dev/null || cat >> "$HOME/.bashrc" <<'RC'
. /opt/conda/etc/profile.d/conda.sh 2>/dev/null || true
. /etc/profile.d/mesa-prompt.sh
[ -n "$TERM" ] && [ -r /etc/motd ] && /etc/motd
RC
cred=()
[ -n "${TTYD_CREDENTIAL:-}" ] && cred=(-c "$TTYD_CREDENTIAL")
exec /opt/vice/bin/ttyd -W -p 7681 -t titleFixed="MESA CLI" "${cred[@]}" tmux new -A -s vice bash -l
