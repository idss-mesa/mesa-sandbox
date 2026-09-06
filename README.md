# mesa-sandbox

AI sandboxes for CyVerse VICE, built by the NSF MESA project (Multidisciplinary Environment for Scientific Advancement, University of New Mexico CARC with University of Arizona / CyVerse and UNC / RENCI).

VICE runs interactive research environments (JupyterLab, RStudio Server, VS Code Server, a Kasm Ubuntu desktop, a tmux CLI) as Kubernetes pods in the CyVerse Discovery Environment. Those images now carry AI coding agents (Claude Code, OpenAI Codex, OpenCode, Goose, Google Antigravity, Cursor, Anthropic's `ant`) and MESA MCP servers. This repository is the plan and the implementation for running those agents **with the user's permissions but without the user's secrets**, autonomously and uninterrupted, at explicit sandbox levels.

Status (2026-09-06): **Phase 0 complete; Phase 2 foundation in place.** `resources.yaml` locks 31 artifacts (sha256 per architecture, cross-checked against upstream checksum files), the `tools` image and the `mesa-cli` overlay build natively on arm64 and pass `tests/smoke.sh` (non-root, no sudo, health, every agent CLI answers, no secrets in the environment). The other overlays (`jupyterlab`, `rstudio`, `vscode`, `kasm`, `agent-runner`) are drafted and unbuilt; CI workflows and the R1 seccomp/AppArmor profiles are drafted and untested on a cluster. See `docs/plan.md` for the phases.

## What is here

| Path | Content |
|---|---|
| `docs/plan.md` | the approved plan: context, design D1–D8, layout, phases, verification |
| `docs/profiles.md` | the normative sandbox-profile taxonomy P0–P4 (runtime, egress, credentials, autonomy, data class) |
| `docs/threat-model.md` | assets, adversaries, boundaries, threats → controls |
| `docs/adr/` | fifteen architecture decision records |
| `docs/research/` | nine fact-checked research reports, a completeness critique, the Agent Substrate/kagent brief, Kasm/Cursor/Iron Bank notes, and current-state audits of the five existing image repos |
| `docs/runbooks/` | node-baseline discovery checklist (hand-off to cluster operators) |
| `resources.yaml` / `resources.lock` / `resources.hcl` | every downloaded artifact and base image, pinned and checksummed (`scripts/resources.py`) |
| `docker-bake.hcl`, `Makefile` | the image family: `make build T=<target>`, `make test`, `make push` (multi-arch) |
| `images/tools` | the shared, sha256-verified toolchain layer (agent CLIs, MCP servers, CyVerse tools) |
| `images/common` | boot library, `cyverse-login`/`logout`, `aiverde-setup`, harness configs, `agent` user, sudo removal |
| `images/{cli,jupyterlab,rstudio,vscode,kasm,agent-runner}` | app overlays |
| `k8s/` | R1 seccomp + AppArmor profiles (Phase 3), more to come |
| `tests/smoke.sh` | the runtime contract check |

## Build

```bash
make venv && make check          # PyYAML venv; resources.lock/.hcl in sync
make build T=tools               # local platform, loads harbor.cyverse.org/vice/mesa-tools:dev
make build T=cli && tests/smoke.sh harbor.cyverse.org/vice/mesa-cli:dev
make builder AMD_VM=ssh://user@amd-vm [SPARK=ssh://user@sparky-1]   # native amd64 + arm64 nodes
make push TAG=$(date +%F)        # multi-arch manifest lists + attestations to Harbor
```

## The design in one paragraph

Keep the VICE analysis pod as the human's workbench. Run every autonomous agent job as a separate pod with its own UID, ServiceAccount, lifetime, credentials and egress policy, sharing only the workspace volume (kubernetes-sigs/agent-sandbox `Sandbox`). Agents never hold long-lived user secrets: an OpenBao broker issues short-lived, leased credentials and an egress proxy sidecar injects them only for allow-listed hosts, so the agent sees sentinels; iRODS access uses the CSI mount plus constrained tickets and the hosted OAuth MCP endpoints instead of the user's password. Egress is enforced at the pod boundary. LLM traffic goes through AI Verde/LiteLLM with per-analysis keys; self-hosted vLLM runs as a shared GPU service. One hardened, sudo-free, digest-pinned image family is built from a single Docker Bake matrix for amd64 and arm64 and published to `harbor.cyverse.org/vice/mesa-*`.

## Profiles

| Profile | Agent runs | Runtime | Egress | Credentials | Autonomy |
|---|---|---|---|---|---|
| P0 Legacy | in the workbench, same UID | runc | internet | user's files | prompts |
| P1 Workbench | in the workbench as `agent` UID | hardened runc | trusted | deny/mask | prompts or inbox |
| P2 Background | separate pod | hardened runc | trusted or CyVerse-only | broker + proxy | allowlist + inbox |
| P3 Autonomous | separate pod | gVisor | CyVerse-only | broker + proxy | policy-only |
| P4 Isolated | separate pod, whole GPU | Kata | CyVerse-only or none | broker + proxy | policy-only |

## Related repositories

`idss-mesa/cli`, `cyverse-vice/{jupyterlab-datascience,rstudio-geospatial,vscode,kasm-ubuntu}` (today's images), `cyverse-vice/vice-toolkit` (build/CI/audit skills), `idss-mesa/{mesa-mcp,mesa-ducklake,formation-mcp,irods-mcp-server}` (MCP servers), `cyverse-de/app-exposer` (VICE launcher), `tyson-swetnam/vice-app-integrator` (MCP server and CLI that generates and validates VICE Dockerfiles, builds and pushes to harbor.cyverse.org, and registers tools and apps in the DE through Terrain; maintained separately and used here for Phase 2 registration), `kubernetes-sigs/agent-sandbox`, `openbao/openbao`.

## License

MIT, © 2026 The Regents of the University of New Mexico. Research reports quote and link their sources; upstream projects keep their own licenses.
