# Current state: idss-mesa/cli (MESA CLI VICE image) and cross-repo grep

Audit date: 2026-09-06. Read-only exploration of `/Users/tswetnam/github/vice/cli` (`main` at `5dae052`) and the worktree checkout of branch `update-agent-clis-ant-duckdb` (`f513817`, pushed to `origin`, not merged). Line numbers are per checkout: `MAIN/` = `main`, `WT/` = the branch (its 22-line `ARG` block shifts everything below it).

## Branch delta (`main` vs `update-agent-clis-ant-duckdb`)

- Byte-identical: `bash/entry.sh`, `bash/configs/aiverde-setup.sh`, `bash/configs/cyverse-login.sh`, `bash/configs/mesa-mcp-shim.sh`, `bash/osn-mount.sh`, `bash/Makefile`, `bash/environment.yml`, `bash/mesa-prompt.sh`, `bash/.dockerignore`.
- Changed: `bash/Dockerfile` (new `ARG` block `WT:24-35` pinning Go 1.27.1, tini v0.19.0, ttyd 1.7.7, GCM 2.9.1, DuckDB 1.5.5, `ant` 1.31.0, Claude Code 2.1.263, Codex 0.153.4, ccr 3.0.22, `mcp-server-filesystem` 2026.8.31, OpenCode 1.18.29, Goose 1.49.0; DuckDB CLI `WT:128-131` without checksum; `ant` `WT:137-144` is the only checksum-verified download; Goose installer moved to the pinned release URL `WT:201`, still `curl | bash`); all five agent configs replace `npx -y @modelcontextprotocol/server-filesystem` with the preinstalled binary; `README.md`, new `CLAUDE.md`, new `docs/credential-security-assessment.md`.
- **Security posture delta at runtime: zero.** Unchanged: sudoers (`MAIN:24` / `WT:46` `jovyan ALL=(ALL) NOPASSWD: ALL`), `user_allow_other` (`MAIN:113` / `WT:157`), `GCM_CREDENTIAL_STORE=cache` (`MAIN:120` / `WT:164`), `sudo gocmd upgrade` in `~/.bashrc` (`MAIN:152` / `WT:213`), s3fs `allow_other` via `sudo` (`entry.sh:100,105`; `osn-mount.sh:51,58`), dotfile copy from `/data-store` (`entry.sh:12-23`). `osn-helper`, `apiKeyHelper`, `{file:...}` references, `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`, `sandbox.credentials`, `cyverse-logout` exist only as proposals in the assessment doc.
- Genuine improvements: no runtime `npx -y`; CLIs pinned by `ARG` (Antigravity excepted); `ant` checksum-verified; Goose installer pinned.

## Agent CLI configuration (`bash/configs/`)

- AI Verde: `aiverde-setup.sh` writes `~/.config/aiverde/env` (0600) and appends a `source` line to `~/.bashrc`, exporting `LLM_URL`, `LLM_API_KEY`, `OPENAI_BASE_URL`, `OPENAI_API_KEY`, `GOOSE_PROVIDER`, `GOOSE_MODEL`, `OPENAI_HOST`, `OPENAI_BASE_PATH`, `GOOSE_DISABLE_KEYRING=1`, `AIVERDE_DEFAULT_MODEL`, and conditionally `ANTHROPIC_BASE_URL`/`ANTHROPIC_API_KEY`/`ANTHROPIC_MODEL` when the course exposes `anthropic/*` models; otherwise it points users at `ccr code`.
- Per agent: OpenCode uses provider `aiverde` (`@ai-sdk/openai-compatible`, `baseURL https://llm-api.cyverse.ai/v1`, `apiKey {env:LLM_API_KEY}`, default `aiverde/js2/gpt-oss-120b`); Goose via env only; Claude Code native env or `ccr`; Codex not wired (no Responses API on AI Verde); Antigravity MCP-only; `ant` uses its own Anthropic credentials.
- MCP matrix: Claude Code registers `irods` (`https://mcp-public.cyverse.ai/mcp`) **and** `irods-auth` (`https://mcp.cyverse.ai/mcp`, OAuth `clientId mcp-client`, `callbackPort 8990`), `mesa` (stdio `/usr/local/bin/mesa-mcp`), `formation` (`https://de.cyverse.org/formation/mcp`), `filesystem` (stdio). Codex and Antigravity use the local `irods-mcp-server` Go binary instead of the hosted endpoint. OpenCode and Goose use the anonymous public endpoint only. Filesystem MCP scope is `/home/jovyan/work` and `/home/jovyan/data-store` (the whole Data Store mount).
- Sandbox/permission settings: only `GOOSE_MODE: smart_approve` (`goose-config.yaml:20`). No Claude `sandbox`/`permissions`/`apiKeyHelper`; no Codex `sandbox_mode`/`approval_policy`; no OpenCode `permission`. `bubblewrap` and `socat` are installed (`WT:89`) but unused.
- `osn-mount.sh`: `sudo mkdir -p`, `sudo chown`, `sudo s3fs ... -o passwd_file=$HOME/.aws/credentials,...,allow_other`, `sudo umount`, `sudo rmdir` with caller-controlled arguments; duplicated in `entry.sh`.

## Cross-repo grep (all five repos, `.git` and worktrees excluded)

| Pattern | Hits | Notes |
|---|---:|---|
| `IPLANT_USER` / `/data-store` | 143 / 141 | every entry script writes `irods_environment.json` then copies `.gitconfig`/`.ssh`(/`.aws`) from `/data-store/iplant/home/$IPLANT_USER` |
| `REDIRECT_URL` | 54 | rstudio-geospatial only (nginx `proxy_redirect`); vscode/jupyter never read it |
| `NOPASSWD` | 50 | three policies: unrestricted `ALL` (cli, rstudio latest/4.5.0/4.3.1, vscode, jupyterlab 4.6.0, every kasm `sudoers`), `$PRIV_CMDS` allowlist (older jupyterlab/rstudio), global `ALL ALL=(ALL) NOPASSWD:ALL` (jupyterlab 2.x/3.0.15). `kasm-ubuntu/20.04-gpu/Dockerfile:39` and `labelstudio/Dockerfile:39` write to `/etc/sudoersq` (typo) |
| `GCM_CREDENTIAL_STORE` | 9 | always `cache`; duplicated in `vscode/latest/Dockerfile:146,170` |
| `s3fs` / `user_allow_other` | 23 / 2 | cli and vscode enable `allow_other` |
| `NVIDIA_` | ~18 | kasm GPU variants and vscode (`NVIDIA_DRIVER_VERSION="535"`) |
| `ollama` | 10 | vscode only, `curl \| sh`, never started |
| `vice-toolkit`, `trivy`, `hadolint` | 11 / ~30 / 16 | present in jupyterlab, kasm, rstudio, vscode; **absent from cli** |
| `bubblewrap` | 4 | cli, jupyterlab latest/4.5.0, kasm 24.04-gpu |
| `sandbox`, `--dangerously-skip-permissions`, `apiKeyHelper` | 0 | nothing shipped |
| `HEALTHCHECK` | 3 | `vscode/latest/Dockerfile:193-194` only |
| `tini` / `supervisord` / `s6-overlay` | ~45 | tini in cli and old vscode; supervisord in rstudio; no s6 |
| UID strategy | 60+ | cli `1000:100`, vscode/rstudio `1000:1000`, jupyter supplementary group 1000; only `kasm-ubuntu/swcacti/K8s_config.md:18-20` documents a pod `securityContext` |

## `.claude/settings.json` and `security.yml`

- jupyterlab, kasm, rstudio, vscode: `.claude/settings.json` registers the `cyverse-vice/vice-toolkit` marketplace and enables the plugin; no permissions, hooks or sandbox keys. `cli` has only a `settings.local.json` allowlist.
- `security.yml` (four repos): `hadolint/hadolint-action@v3.1.0` with `no-fail: true`; `aquasecurity/trivy-action@0.28.0` on the published Harbor image, `exit-code: '0'`, SARIF upload; weekly cron. `vscode`'s file lacks the Harbor `docker/login-action` step. `cli` has no `security.yml`, `.hadolint.yaml` or `.trivyignore`.
