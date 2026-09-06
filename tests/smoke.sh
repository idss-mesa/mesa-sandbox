#!/usr/bin/env bash
# tests/smoke.sh — run an app image the way VICE would and check the contract
# from docs/plan.md "Verification": non-root, no sudo, health endpoint, tools
# answer --version, no credentials in env, configs installed, agent user exists.
#   tests/smoke.sh harbor.cyverse.org/vice/mesa-cli:dev [port] [health-path]
set -euo pipefail
img=${1:?image}; port=${2:-7681}; path=${3:-/}; home=${4:-/home/jovyan}; uid=${5:-1000}; gid=${6:-100}
name=smoke-$$; fail=0
ok(){ printf '  ok   %s\n' "$1"; }; bad(){ printf '  FAIL %s\n' "$1"; fail=1; }
echo "== $img"
# read-only rootfs: only /tmp, /run and a fresh tmpfs home are writable (Apptainer-like)
docker run -d --rm --name "$name" --read-only --tmpfs /tmp --tmpfs /run --tmpfs "$home:uid=$uid,gid=$gid,mode=0750" -e IPLANT_USER=smoketest -p "127.0.0.1:${port}:${port}" "$img" >/dev/null
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT
x(){ docker exec "$name" sh -c "$1"; }
# 1. identity and privilege
uid=$(x 'id -u'); [ "$uid" != 0 ] && ok "runs as uid $uid (non-root)" || bad "runs as root"
x 'command -v sudo' >/dev/null 2>&1 && bad "sudo binary present" || ok "no sudo binary"
x 'test ! -e /etc/sudoers -a ! -d /etc/sudoers.d' && ok "no sudoers" || bad "sudoers present"
x 'id agent' >/dev/null 2>&1 && ok "agent user exists (uid $(x 'id -u agent'))" || bad "agent user missing"
# 2. health
for i in $(seq 1 30); do code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}${path}" || true); case "$code" in 2*|3*|401|403) break;; esac; sleep 1; done
case "$code" in 2*|3*|401|403) ok "health $path -> $code";; *) bad "health $path -> ${code:-none}";; esac
# 3. tools
for t in "tini --version" "ttyd --version" "gocmd --version" "gh --version" "git-credential-manager --version" "aws --version" "duckdb --version" "ant --version" "opencode --version" "goose --version" "agent --version" "agy --version" "claude --version" "codex --version" "ccr -h" "gemini --version" "mesa-mcp --help" "irods-mcp-server --help"; do
  if x "$t >/dev/null 2>&1"; then ok "$t"; else bad "$t"; fi; done
# 4. no secrets in the environment, credential dirs locked
if x 'env | grep -qiE "(API_KEY|SECRET|TOKEN|PASSWORD)="'; then bad "secret-looking variables in env"; else ok "no secret-looking variables in env"; fi
x 'test -f ~/.claude/settings.json -a -f ~/.claude.json -a -f ~/.codex/config.toml -a -f ~/.config/opencode/opencode.json -a -f ~/.cursor/cli-config.json' && ok "harness configs installed" || bad "harness configs missing"
x 'stat -c %a ~/.irods' | grep -q '^700$' && ok "~/.irods is 0700" || bad "~/.irods not 0700"
x 'grep -q anonymous ~/.irods/irods_environment.json || grep -q smoketest ~/.irods/irods_environment.json' && ok "iRODS env written" || bad "iRODS env missing"
# 5. optional: in-harness sandbox prerequisite (needs userns; informative only)
if x 'bwrap --ro-bind / / --unshare-all --proc /proc true' >/dev/null 2>&1; then ok "bubblewrap works (unprivileged userns available)"; else printf '  info bubblewrap unavailable here (expected under default seccomp; see ADR-0002 R1)\n'; fi
[ "$fail" = 0 ] && echo "== PASS" || { echo "== FAIL"; exit 1; }
