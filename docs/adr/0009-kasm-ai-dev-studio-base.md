# ADR-0009: Kasm AI Dev Studio is the desktop base

Status: accepted (user decision 2026-09-06). Sources: `docs/research/kasm-cursor-ironbank-notes.md`, `current-state-kasm-rstudio.md`.

## Context
The current desktop is `kasmweb/ubuntu-noble-desktop:1.17.0-rolling-daily` plus our own npm-installed agents, with sudo appended, GNOME installed but XFCE started, and a GPU variant that never installs VirtualGL. Kasm publishes `kasmweb/ubuntu-jammy-desktop-ai-dev` (source `kasmtech/workspace-ai-images`, MIT): multi-arch amd64+arm64, `USER 1000`, no sudo, Cursor IDE, `cursor-agent`, Claude Code, Gemini CLI and Codex preinstalled, Chrome/Chromium/Firefox, VS Code, Sublime, Ansible, Terraform.

## Decision
Build the `kasm` image `FROM kasmweb/ubuntu-jammy-desktop-ai-dev:<1.19.x>@sha256:...` and add only the VICE layer: `vnc_startup.sh` hooks (iRODS env via `envsubst`, no dotfile copies), `tools` overlay (pinned OpenCode, Goose, `ccr`, `ant`, MESA MCP servers, `gocmd`, `gh`), harness configs, the `agent` user, KasmVNC brute-force protection restored, no sudo. Keep a GPU desktop variant on `kasmweb/ubuntu-noble-nvidia-pytorch` (or `ubuntu-noble-nvidia`) with VirtualGL actually installed and the EGL device check fixed for Kubernetes device plugins. Re-pin Kasm's unpinned installers by replacing them with the `tools` layer where they overlap (Claude Code, Codex, Gemini, `cursor-agent`).

## Consequences
The desktop is Ubuntu 22.04 (Jammy) until Kasm ships a Noble AI-dev image; Cursor's Landlock sandbox depends on the node kernel, not the image. Kasm's Squid SSL-bump cache image is a candidate egress-cache component.
