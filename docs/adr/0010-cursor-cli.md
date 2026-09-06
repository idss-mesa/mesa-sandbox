# ADR-0010: Ship Cursor's `agent` CLI as a bring-your-own-subscription harness

Status: accepted (user decision 2026-09-06). Sources: `docs/research/kasm-cursor-ironbank-notes.md`.

## Context
Cursor's CLI (`agent`, legacy symlink `cursor-agent`) has headless mode (`-p`, `--force`, `--trust`, `--approve-mcps`), a permissions file (`~/.cursor/cli-config.json` with `Shell()/Read()/Write()/WebFetch()/Mcp()` allow/deny), a Landlock+seccomp user-namespace sandbox, MCP via `~/.cursor/mcp.json`, ACP server mode and a self-hosted worker mode. It cannot target a custom OpenAI-compatible endpoint, so it cannot use AI Verde or local vLLM.

## Decision
Add Cursor `agent` to the `tools` image, pinned by version from `downloads.cursor.com/lab/<version>/linux/{x64,arm64}/agent-cli-package.tar.gz` (no `curl | bash`). Ship `cli-config.json` (`approvalMode: allowlist`, deny reads of `~/.irods/**`, `~/.aws/**`, `~/.ssh/**`, `sandbox.mode` enabled where the profile permits) and `mcp.json` with the same MCP servers as the other harnesses. Document it as bring-your-own subscription (`CURSOR_API_KEY` or `agent login`), like `ant` and Codex. Cursor IDE (desktop) comes with the Kasm base (ADR-0009).

## Consequences
Cursor sessions send prompts to Cursor's backend; profile P2+ N2 egress must include Cursor's API hosts only if the app allows it. `agent acp` is a candidate adapter for the approval inbox (ADR-0014).
