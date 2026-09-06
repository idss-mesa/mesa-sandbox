# Current state: cyverse-vice/jupyterlab-datascience and cyverse-vice/vscode

Audit date: 2026-09-06 (read-only). JLDS = `jupyterlab-datascience`, VSC = `vscode`.

## Base, user, sudo

| | JLDS `latest` | VSC `latest` |
|---|---|---|
| Base | `quay.io/jupyter/datascience-notebook:latest` (Dockerfile:3) | `lscr.io/linuxserver/code-server:latest` (Dockerfile:2); `4.96.4/Dockerfile:1` pinned `4.96.4` |
| Final `USER` | `jovyan` (:83) | `vscode` (:148), UID 1000 / GID 1000 (`useradd -m -u 1000 -g 1000`, :70) |
| sudoers | `ARG PRIV_CMDS='ALL'` (:55) → `jovyan ALL=NOPASSWD: ALL` (:59); the restricted list present in `4.5.0` was deleted | `vscode ALL=(ALL) NOPASSWD: ALL` (:73) |
| sudo at build time | `RUN sudo chmod +x /bin/entry.sh` (:111) | `:151 sudo chown`, `:165 sudo dpkg -i`, `:197 sudo chown` |

JLDS adds group 1000 as a supplementary group only; jovyan's primary GID stays 100. `VSC:136 chown 1000:100 /osn` does not match the vscode user's GID 1000.

## Credential handling

- `VSC/latest/entry.sh:8-33` copies `.gitconfig`, `.aws`, `.ssh`, `.vscode-server` from `/data-store/iplant/home/$IPLANT_USER` into `~`. `JLDS/latest/entry.sh:11-18` copies `.gitconfig` and `.ssh`.
- `JLDS/latest/entry.sh:4-6` writes `irods_environment.json` with single quotes and `>>` and no `envsubst`, so the file literally contains `$IPLANT_USER` and grows on every restart (`4.6.0` and VSC use `envsubst` correctly). `VSC/latest/entry.sh:3` writes `$HOME/.irods/irods_environment.json` without creating the directory.
- `JLDS/latest/entry.sh:22-39` loops over `/home/jovyan/.*env*` and `/home/jovyan/.env*` and `source`s each with `set -a` ("hidden environment files provided by K8s CSI driver"): arbitrary code execution from anything placed in the home that matches those globs.
- `GCM_CREDENTIAL_STORE=cache` at `VSC:146` and again at `:170`.
- `VSC/latest/cline_mcp_settings.json:32` points the Data Store MCP at plaintext `http://mcp.cyverse.ai/mcp`; `:14-27` auto-approves `write_file`, `edit_file`, `create_directory`, `move_file` under `/home/vscode/data-store/` **and** `/config/`.
- `curl | bash` installers: NodeSource (`JLDS:77`, `VSC:44-46`), GoCommands with version fetched from `VERSION.txt` (`JLDS:49-50`, `VSC:51-52`), OpenCode (`JLDS:92`, `VSC:160`), code-server (`JLDS:97`), Ollama (`VSC:99`), Globus, AWS CLI zip, gh keyring. Only `jupyter-rsession-proxy@216d9e5e…` (`JLDS:99`) is pinned by hash.

## Exposure and process model

- JLDS: `EXPOSE 8888`; `ENTRYPOINT ["bash", "/bin/entry.sh"]` → `exec jupyter lab --no-browser --LabApp.token="" --LabApp.password="" --ip=0.0.0.0 --port=8888` (`entry.sh:41`); `jupyter_notebook_config.json` sets empty token/password, `allow_origin: *`, `allow_unauthenticated_access: true`, `disable_check_xsrf: true`. Auth is delegated to the VICE proxy. jupyter-server-proxy provides VS Code, RStudio, Shiny launcher cards. `latest/rserver.conf` is never `COPY`d.
- VSC: `EXPOSE 8443 8080`; `entry.sh:39 exec /app/code-server/bin/code-server --host 0.0.0.0 --disable-telemetry` with `config.yaml` `auth: none`; nothing listens on 8443. The linuxserver base's s6 `/init` is replaced, so no supervisor, no PUID/PGID remap, no cert generation; `HEALTHCHECK` at `:194-195` is ignored by Kubernetes.
- `REDIRECT_URL` appears only in `JLDS/README.md:53`.

## AI agent CLIs

| Tool | JLDS | VSC |
|---|---|---|
| Claude Code, Gemini CLI, Codex | npm global (`JLDS:88`, `VSC:156`) | same |
| OpenCode | `JLDS:92` | `VSC:160` |
| Ollama | — | `VSC:99`, serve line commented out (`:103-104`), never started |
| Cline extension | — | `VSC:177` |
| filesystem MCP | — | `VSC:107` |

JLDS configures nothing for the agents. `VSC/latest/entry.sh:6` writes an MCP JSON literal beginning `{{` to `/home/jovyan/.claude.json` (no `jovyan` user in that image). `cline_mcp_settings.json` is never `COPY`d; it takes effect only if the user keeps a copy under `.vscode-server/` in the Data Store. No sandbox or permission settings exist; JLDS installs `bubblewrap` (`:79`), VSC does not.

## GPU (vscode)

`ARG CUDA_VERSION="12-5"`, `ARG NVIDIA_DRIVER_VERSION="535"` (`:56-57`), installed via `apt-get install cuda-toolkit-12-5 nvidia-driver-535` (`:80-84`) into the single `latest` image; the in-container kernel driver can never load. No `NVIDIA_VISIBLE_DEVICES`/`NVIDIA_DRIVER_CAPABILITIES`; GPU exposure depends on the pod spec. `MINICONDA_VERSION="latest"` unpinned.

## CI

- `harbor.yml`: push to `main`, weekly cron, dispatch (`context` + `tag` inputs in JLDS; `tag` only in VSC); single `:latest`-style tag; no `platforms:`; amd64-only downloads (`gocmd-...-linux-amd64`, `awscli-exe-linux-x86_64`).
- `security.yml`: hadolint on `latest/Dockerfile` only, `no-fail: true`; trivy `0.28.0` against the published Harbor image, `exit-code: '0'`, skipped on PRs. **Neither scan job runs `actions/checkout`, so `.trivyignore` is never applied.** VSC's workflow has no Harbor login step. Base images float on `:latest`. Dependabot (`github-actions`) only in JLDS.

## Dead config and regressions

- `JLDS/latest/rserver.conf`, `VSC/latest/cline_mcp_settings.json` never copied; `VSC/latest/Dockerfile:170` duplicate ENV; `:181` `EXPOSE 8443` with no listener.
- Regressions in `latest`: base image unpinned (`VSC/4.96.4` pinned), tini dropped (`VSC/1.64.0:96-99`, `1.68.0:97-101` had it), iRODS env without `envsubst` (`JLDS/4.6.0/entry.sh:4` correct).
- `VSC/geospatial/latest/Dockerfile:3 USER openvscode-server` cannot build against today's base.

## What breaks without root or under restricted Pod Security

- Builds themselves (sudo at build time in both).
- `bubblewrap` (JLDS) needs unprivileged user namespaces or setuid; blocked by `allowPrivilegeEscalation: false` and default seccomp.
- FUSE/s3fs/OSN (`VSC:125,130,134-136`) needs `/dev/fuse` and `SYS_ADMIN`.
- Globus Connect Server and Ollama's systemd unit expect an init system that never runs.
- `chown -R /opt/conda` and `/config` bake ownership to UID 1000; arbitrary-UID admission fails.
