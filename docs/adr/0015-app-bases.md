# ADR-0015: App bases

Status: accepted. Sources: `docs/research/image-build-technique.md`, `kasm-cursor-ironbank-notes.md`, user statements (rocker, Jupyter, Kasm).

## Decision
- CLI: `quay.io/jupyter/minimal-notebook:<date>@sha256` (keeps `jovyan` 1000:100 and mamba), ttyd + tmux, plus Cursor.
- JupyterLab: `quay.io/jupyter/datascience-notebook:<date>@sha256` (Jupyter Docker Stacks are only published to quay.io since 2023-10-20, date-tagged, aarch64 built); RStudio Server and code-server through jupyter-server-proxy; remove the `~/.*env*` sourcing.
- RStudio: `ghcr.io/rocker-org/geospatial:<R>@sha256` for the R stack and rocker install scripts, but **not** rocker's `/init`: launch `rserver --server-user=$(whoami) --auth-none 1 --www-port 8787 --server-data-dir=/tmp/run --database-config-file=<user-writable>` as UID 1000 behind the DE proxy; no `ROOT=true`, no nginx on :80, no `chmod 777`.
- VS Code: `ghcr.io/coder/code-server:<ver>@sha256` (non-root `coder` UID 1000) instead of linuxserver's s6/root base; CUDA only in a `-cuda` variant; Ollama only there and started by the entrypoint when a whole GPU is allocated.
- Kasm desktop: ADR-0009. GPU desktop: `kasmweb/ubuntu-noble-nvidia-pytorch`/`ubuntu-noble-nvidia`.
- agent-runner: `ubuntu:24.04@sha256` + `tools`, headless.

## Consequences
Base digests are updated by Renovate; every base is multi-arch except the CUDA variants where upstream is amd64-only (recorded per target in `docker-bake.hcl`).
