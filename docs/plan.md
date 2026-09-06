# Plan: MESA AI Sandboxes for CyVerse VICE

A new `idss-mesa` repository that (1) records the research and decisions, (2) defines one hardened image family (CLI, JupyterLab, RStudio, VS Code, Kasm desktop, plus a headless agent-runner) built from a single Docker Bake matrix, (3) ships the credential-broker, egress-proxy, sandbox-profile and approval-inbox machinery as Kubernetes manifests and scripts, and (4) grows by commits as each piece is validated on a real VICE analysis.

## Context

Five image repos under `/Users/tswetnam/github/vice/` (`cli` at idss-mesa; `jupyterlab-datascience`, `kasm-ubuntu`, `rstudio-geospatial`, `vscode` at cyverse-vice) build the interactive VICE apps. All now bundle AI coding agents (Claude Code, Codex, OpenCode, Goose, Antigravity, `ccr`, `ant`) and MCP servers (iRODS, mesa-mcp, formation). The CLI repo's own assessment (`cli/.claude/worktrees/init-9383c1/docs/credential-security-assessment.md`, branch `update-agent-clis-ant-duckdb`, pushed, unmerged) names the structural problem: one Unix user, one home, one environment, passwordless `sudo`, shared by the human and every agent. Every credential the user brings in is readable by every agent, and root via `sudo` defeats any in-container sandbox.

Verified current state (explorers, file:line):
- `cli/bash/Dockerfile:24` `jovyan ALL=(ALL) NOPASSWD: ALL`; `:152` `sudo gocmd upgrade` in `~/.bashrc`; `:67` installs bubblewrap/socat but ships no sandbox policy. `cli/bash/entry.sh:12-24` copies `.gitconfig`, `.aws`, `.ssh` from `/data-store/iplant/home/$IPLANT_USER` unconditionally; `:88-105` `sudo mkdir/chown/s3fs` with user-controlled options; `:153` unauthenticated `ttyd -W` behind the DE proxy. `cyverse-login.sh:53-59` stores the reversible iRODS password; the decoder ships in `/opt/mesa`. AI Verde key exported into every shell. Only Claude Code registers the OAuth `irods-auth` endpoint.
- `jupyterlab-datascience/latest`: `entry.sh:22-39` sources every `~/.*env*` file with `set -a` (arbitrary code from the Data Store home at boot); `entry.sh:4-6` writes `irods_environment.json` without `envsubst`; sudo needed at build time (`Dockerfile:111`); `rserver.conf` never copied.
- `vscode/latest`: linuxserver s6 `/init` replaced by `entry.sh` (no supervisor, no PUID/PGID); `entry.sh:6` writes invalid MCP JSON to `/home/jovyan/.claude.json` (no such user); `cline_mcp_settings.json` never copied and auto-approves writes under `/config/`; CUDA 12.5 toolkit plus an inert `nvidia-driver-535` in the single `latest` image; Ollama installed but never started; sudo needed at build time (`:151,165,197`).
- `kasm-ubuntu/24.04{,-gpu}`: live sudo grant is `PRIV_CMDS='ALL'` (`24.04/Dockerfile:34-39`); the checked-in `sudoers` files are dead; `-disableBasicAuth -BlacklistThreshold=0`; GNOME installed, XFCE started; GPU variant sets `VGL_DISPLAY=egl` but never installs VirtualGL and needs `/dev/dri/*` owned by `kasm-user` (silent software fallback under a device plugin); `24.04-gpu` is outside CI. KasmVNC itself needs only a writable `$HOME`/`/tmp` and port 6901.
- `rstudio-geospatial/latest`: ends `USER root`; `run.sh` runs as root so dotfile copies land in `/root`; `auth-none=1` behind nginx :80 (`CAP_NET_BIND_SERVICE`); `ENV PASSWORD` inert (rocker `userconf` never runs); `chmod -R 777` on the R site-library.
- Fleet-wide: `NOPASSWD: ALL` in every current image; zero `sandbox`/`apiKeyHelper` settings; only `GOOSE_MODE: smart_approve` ships; two kasm Dockerfiles write to `/etc/sudoersq`; base images float on `:latest`/`rolling-daily`; `cli` has no `security.yml`; `vscode`'s `security.yml` lacks the Harbor login; neither `security.yml` scan job checks out the repo, so `.trivyignore` never applies.

Platform facts (research, primary sources, fact-checked):
- `cyverse-de/app-exposer` `vicebuild/deployments.go`: a VICE analysis is a single-replica Deployment in `vice-apps`; pod `securityContext` pins RunAsUser/RunAsGroup/FSGroup to the tool UID and disables the SA token; the `analysis` container drops **no** capabilities, sets no seccomp/AppArmor, and leaves `allowPrivilegeEscalation` default (why `sudo` works). Containers: init `working-dir-init` (porklock), `vice-proxy` (Keycloak OIDC), optional `input-files`, `analysis`. Env injected: `REDIRECT_URL`, `IPLANT_USER`, `IPLANT_EXECUTION_ID`. Data Store is a per-analysis CSI PV (`irods.csi.cyverse.org`, `irodsfuse`, `clientUser` proxy auth); the FUSE privilege lives in the node DaemonSet, not the pod. GPUs: `nvidia.com/gpu` requests==limits, affinity on `gpu=true`/`nvidia.com/gpu.product`, toleration `gpu=true:NoSchedule`. `vice-operator` already emits namespace default-deny plus a per-analysis egress NetworkPolicy with internet-off and CIDR/pod exceptions. Routing is Gateway API HTTPRoutes via Traefik. "AI Sandboxes" already exists as `cyverse-de/ai-sandboxes-ui` (launcher front-end, de-releases v2026.05.05), not a new runtime. The launcher does **not** drop `.irodsA` into pods; it appears only after `iinit`/`cyverse-login`.
- kubernetes-sigs/agent-sandbox v1.0.1 (2026-09-03): `Sandbox` (agents.x-k8s.io/v1beta1) + `SandboxTemplate/SandboxClaim/SandboxWarmPool`; isolation via `runtimeClassName` (gvisor, kata); `shutdownTime` + `shutdownPolicy` (default Retain); `volumeClaimTemplates`; Go sandbox-router (optional). Consensus pod primitive.
- Agent Substrate: upstream v0.0.0 only ("not ready for production"); "0.0.8" is the `kagent-dev/substrate` fork (now v0.0.26); HTTP-only ingress, no exec, GPUs currently unsupported, worker pods need 13 caps + seccomp/AppArmor Unconfined; credentials via egress header injection. kagent v0.10.0 (2026-09-04) `AgentHarness` is being replaced on `main` by v1alpha3 `Harness` (kagent|codex|claude|byo, `credentialRef`, approvals/resume/checkpoint). Both are watch items; the js2-substrate design's own top unknown (kagent overwrites `openclaw.json`) is confirmed as the bad case on v0.10.0.
- Runtime isolation: user namespaces GA in K8s 1.36 (kernel ≥ 6.3, containerd ≥ 2.0). Bubblewrap (Claude Code, Codex, `srt`) and Cursor's Landlock sandbox cannot run under containerd's `RuntimeDefault` seccomp (`clone(CLONE_NEWUSER)`, `pivot_root` blocked) or its default AppArmor (`deny mount`); a `Localhost` seccomp + AppArmor profile is required and is Restricted-PSS compatible. gVisor cannot combine with `hostUsers: false`, ignores pod seccomp/AppArmor, has open bugs running bubblewrap inside it, supports CUDA via `--nvproxy` only for exact driver versions (no MIG, no time-slicing, no DRM). Kata gives VM isolation and single-GPU VFIO passthrough only.
- Credentials: OpenBao v2.6.2 (MPL-2.0): Kubernetes auth (TokenReview, bound SA), JWT/OIDC to Keycloak with CEL, response wrapping, SSH CA, Kubernetes secrets engine, Transit, namespaces, audit devices; AWS engine exists as an official external plugin (`openbao-plugin-secrets-aws` v0.3.1) but Ceph-RGW STS is still open. iRODS tickets default to anyone/any host/forever and must always be constrained (`uses`, `expire`, `add host`, `write-byte`); PAM `.irodsA` is TTL-limited (14 d default) but reversible. OSN offers only static per-bucket keys via CILogon, no STS, no self-service rotation. AI Verde is LiteLLM over vLLM; LiteLLM `/key/generate` supports `duration`, `max_budget`, `models`, `tpm/rpm`. Anthropic's Claude Code on the web and `@anthropic-ai/sandbox-runtime` (Apache-2.0, v0.0.75) implement the sentinel-plus-proxy pattern (`sandbox.credentials` mask, `injectHosts`, SigV4 re-sign) that VICE will copy.
- Harness autonomy: Claude Code `-p --bare --permission-mode dontAsk|auto --permission-prompts none --allowedTools --max-turns --max-budget-usd`, `PermissionRequest`/`PreToolUse` `http` hooks (`allowedHttpHookUrls`), `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`, refuses bypass mode as root; Codex `codex exec -s workspace-write -a never` with `[features.network_proxy]`; OpenCode `opencode serve` + `POST /session/:id/permissions/:id` (headless `ask` hangs, issue #16367); Goose `GOOSE_MODE`; Cursor `agent -p --force --trust --approve-mcps --sandbox`, `~/.cursor/cli-config.json` permissions, `agent acp`. Approval "block indefinitely" is not guaranteed by any harness (hook timeout 600 s), so the inbox must implement deny-queue-resume.
- GPUs: CyVerse VICE offers NVIDIA A16 (no MIG); CARC Easley 36 L40S + 8 H100, Hopper 37 A100 (Slurm/Apptainer, no Kubernetes); DRA GA in 1.34, ImageVolume stable in 1.36; NVIDIA DRA driver v0.5.0 needs 1.34.2+; time-slicing has no isolation. vLLM and Ollama both serve Anthropic `/v1/messages` for Claude Code.
- Images: Jupyter Docker Stacks are canonical on `quay.io/jupyter/*` with date tags (Docker Hub `jupyter/*` froze 2023-10-20); rocker `/init` requires root for `userconf` but `rserver --server-user=$(whoami)` runs non-root (Open OnDemand pattern); Kasm core images run `USER 1000` with no sudo. Native sidecars (`initContainers` + `restartPolicy: Always`) are GA since 1.33. Iron Bank (registry1.dso.mil): no anonymous pulls (free Repo1 account), images built there must use UBI bases, all downloads declared with checksums in `hardening_manifest.yaml`, no network in builds, numeric non-root `USER`; it hosts hardened OpenBao, vLLM, Ollama, GPU Operator, External Secrets, Falco, Envoy, JupyterLab(-gpu, -codeserver-proxy), and Kasm platform components (not the AI desktop images).

User inputs during planning: switch the Kasm desktop to `kasmweb/ubuntu-jammy-desktop-ai-dev` (Kasm AI Dev Studio; verified multi-arch amd64+arm64, `USER 1000`, no sudo, Cursor IDE + `cursor-agent` + Claude Code + Gemini + Codex preinstalled from `kasmtech/workspace-ai-images`, MIT); add Cursor's CLI to the CLI image (`agent`, version-stamped tarball at `downloads.cursor.com/lab/<ver>/linux/{x64,arm64}/agent-cli-package.tar.gz`, no custom endpoint so it cannot use AI Verde); consider the rest of `kasmweb/*` (e.g. `core-ubuntu-noble`, `ubuntu-noble-nvidia`, `vs-code`, `terminal`, `ubuntu-jammy-dind-rootless`, standalone `cursor`/`claude-code`/`codex-cli`/`gemini-cli`) and Iron Bank as sources; RStudio stays rocker-based; Jupyter stays docker-stacks (quay.io).

## Design

### D1. Brain/hands split: interactive workbench pod + separate agent pod

Keep the VICE analysis pod as the human's **workbench** (JupyterLab, RStudio, VS Code, Kasm desktop, ttyd). Every autonomous run is a **separate pod** with its own UID, ServiceAccount, lifetime, credentials and egress policy, sharing only the workspace volume. Primitive: kubernetes-sigs/agent-sandbox `Sandbox` (first step: a plain Job or a second VICE analysis launched through Formation `launch_app_and_wait`, labelled with the parent analysis id). The human pod can restart; the agent pod keeps running, and `claude -p --resume`, `codex exec resume`, `goose run --resume` state lives on the workspace PVC.

### D2. Unified sandbox profiles (one taxonomy, four axes)

| Profile | Runtime (R) | Egress (N) | Credentials (C) | Autonomy (A) | Data class |
|---|---|---|---|---|---|
| **P0 Legacy** | runc, today's pod | internet | user's files in `$HOME` | interactive prompts | P (public) only |
| **P1 Workbench** | runc + `hostUsers: false` + VICE `Localhost` seccomp/AppArmor, `allowPrivilegeEscalation: false`, drop ALL, no sudo | N1 trusted (CyVerse, LLM gateway, MCP, GitHub, package registries) or N0 per app | agents run as `agent` UID; human dotfiles 0700; in-harness sandbox (bwrap/Landlock) + managed settings deny/mask | A0 prompts, A1 async inbox | P, C with N2 |
| **P2 Background** | separate runc pod, P1 hardening | N1 or N2 (CyVerse + gateway only) | C1: sentinels only, broker + egress proxy inject | A1 allowlist + inbox | P, C |
| **P3 Autonomous** | separate pod, `runtimeClassName: gvisor` (`--nvproxy` on GPU nodes) | N2 | C1 | A2 policy-only (`dontAsk`/`auto`, `codex -a never`, `agent --force`) | P, C |
| **P4 Isolated** | Kata (`kata-qemu-nvidia-gpu`), whole GPU | N2 or N3 none | C1 | A2 | C; E never (CARC Good Neighbor) |

The DE records the profile on the analysis; apps declare a default and a maximum; raising a level is a user action with consent text; audit carries the profile.

### D3. Credentials: agents never hold the user's long-lived secret

| Credential | Human workbench | Agent pods (P2+) |
|---|---|---|
| iRODS Data Store | CSI mount (no credential); `cyverse-login` writes `.irodsA` only into the human's 0700 home, with `--ttl` = analysis length | CSI mount with narrower `path_mapping_json`; DE-minted **iRODS tickets** (constrained `uses`/`expire`/`add host`/`write-byte`) for writes; hosted OAuth MCP (`mcp.cyverse.ai/mcp`, `de.cyverse.org/formation/mcp`) for API access |
| AI Verde / LLM | LiteLLM **virtual key per analysis** (`duration`, `max_budget`, `models`) via `apiKeyHelper`/`ANTHROPIC_BASE_URL`, never in `~/.bashrc` | sentinel in env; egress proxy swaps for the per-analysis key |
| Anthropic/OpenAI/Gemini/Cursor subscriptions | user's own OAuth caches, 0700, human only | not mounted; per-job keys in OpenBao KV, proxy-injected (`injectHosts`) |
| GitHub | `gh auth`/GCM in human home | GitHub App installation token (1 h) through a git credential helper socket or proxy |
| OSN S3 | keys in OpenBao Transit-encrypted KV; s3fs via CSI/sidecar (node-side FUSE), never in `~/.aws` | SigV4 re-signing proxy (`awsPairs` pattern); request RGW STS from OSN |
| SSH | OpenBao SSH CA 30-min certs; `ssh-agent` socket, never key files | same socket, or none |
| Agents' own tokens | per-agent dirs 0700 under the human home | per-job `emptyDir` |

Broker: OpenBao 2.6.x with `auth/kubernetes` (one ServiceAccount per analysis, bound role), `auth/jwt` (Keycloak, CEL bound claims), response wrapping for the launcher, SSH CA, Transit, KV, audit device streamed into the DE analysis record. Egress proxy: a native sidecar built from `@anthropic-ai/sandbox-runtime`'s proxy (or agentgateway) that terminates TLS, enforces domain/method/path allowlists and injects secrets only for allow-listed hosts; NetworkPolicy makes it the only egress. Non-HTTP protocols (iRODS native, SSH) are never proxied: they are replaced (tickets, CSI, SSH CA, OAuth MCP).

### D4. Egress at the pod boundary

Per-analysis NetworkPolicy (extend `vice-operator`'s `DisableInternet`/`AllowedCIDRs`/`PodExceptions` into per-profile N0–N3) plus the proxy sidecar (SNI/FQDN allowlist). In-harness proxies (`sandbox.network.allowedDomains`, Codex `network_proxy`, Cursor `sandbox.json`) are defense in depth only, because they exclude MCP servers and hooks.

### D5. LLMs and GPUs

Default topology: shared, GPU-scheduled vLLM tier fronted by AI Verde/LiteLLM; agents reach it only through the gateway with per-analysis keys. In-pod Ollama sidecar only for whole-GPU allocations (one A16 sub-GPU or one L40S), `OLLAMA_MODELS` on a read-only model volume (OCI ImageVolume on K8s ≥ 1.36, or PVC). No time-slicing for multi-user agent pods; MIG only on CARC A100/H100. gVisor GPU pods pin node drivers to `runsc nvproxy list-supported-drivers`. Codex needs the Responses API (verify against vLLM/LiteLLM); Cursor cannot use local models.

### D6. Image family (one Bake matrix, digest-pinned, no sudo)

- `tools` image: every agent CLI and MCP server as version-`ARG`-pinned, checksum-verified tarballs/binaries under `/opt/vice` (Claude Code, Codex, OpenCode, Goose, Antigravity, `ccr`, `ant`, **Cursor `agent`**, `mcp-server-filesystem`, `irods-mcp-server`, `mesa-mcp` venv, `gocmd`, `gh`, GCM, `aws`, `ttyd`, `tini`); each app image does `COPY --from=tools`. No `curl | bash` in app images; a `resources.yaml` (Iron Bank `hardening_manifest` style: url, filename, sha256) is the single source of download truth, consumed by the Dockerfiles and by Renovate.
- `common/` scripts: `vice-entry` (writes `irods_environment.json` with `envsubst`, never copies dotfiles, opt-in `VICE_IMPORT_DOTFILES=1` copies only `.gitconfig`), `cyverse-login`/`cyverse-logout` (with `--ttl`, warning text), `aiverde-setup` (file-based key, no `~/.bashrc` export), agent configs (Claude managed `settings.json` with `sandbox`, `permissions.deny`, credential deny/mask; Codex `sandbox_mode`/`approval_policy`; OpenCode `permission`; Goose mode; Cursor `cli-config.json` + `mcp.json`), MCP registrations pointing at OAuth endpoints for all five/six agents, an `agent` user (UID 1001) with its own home and no sudoers entry, `osn-helper` (root-owned, validated args) only where a FUSE sidecar is not yet available.
- App overlays (each `FROM` a digest-pinned upstream):
  - `cli`: `quay.io/jupyter/minimal-notebook:<date>` (or `ubuntu:24.04` + micromamba), ttyd/tmux, adds Cursor.
  - `jupyterlab`: `quay.io/jupyter/datascience-notebook:<date>`; drop the `~/.*env*` sourcing; RStudio/code-server via jupyter-server-proxy.
  - `rstudio`: `ghcr.io/rocker-org/geospatial:<R version>` but launched as UID 1000 with `rserver --server-user=$(whoami) --auth-none 1 --www-port 8787 --server-data-dir=/tmp/run`; nginx replaced by `REDIRECT_URL`-aware rserver settings or an unprivileged reverse proxy on 8787; no `/init`, no `ROOT=true`, no `chmod 777`.
  - `vscode`: `ghcr.io/coder/code-server:<ver>` (non-root `coder` UID 1000) instead of linuxserver; CUDA moved to a `-cuda` variant; Ollama only in the GPU variant and started by the entrypoint.
  - `kasm`: `kasmweb/ubuntu-jammy-desktop-ai-dev:<1.19.x>@sha256` as the AI desktop (adds VICE `vnc_startup.sh` hooks, `gocmd`, MESA MCP configs, OpenCode/Goose, `agent` user); `kasmweb/ubuntu-noble-nvidia-pytorch` (or `ubuntu-noble-nvidia`) for the GPU desktop with VirtualGL actually installed; KasmVNC brute-force protection restored.
  - `agent-runner`: headless image for P2–P4 pods (no desktop, no ttyd server by default; `tools` + workspace conventions + hook client for the approval inbox).
- Build: `docker-bake.hcl` targets `tools`, `base-*`, matrix `app × accel(cpu,cuda)`, `attest = [provenance mode=max, sbom]`, registry cache, `RUN --mount=type=cache`; CI on native amd64 + arm64 runners; cosign keyless signing; hadolint DL3002 + dockle CIS-DI-0001/0008 + Trivy/Grype gates (report-only first); Renovate `docker:pinDigests` + regex managers on `resources.yaml`; weekly rebuild kept. Smoke tests: `docker run --read-only -u 1000`, health probes per app (vice-toolkit contract), `bwrap --unshare-all true` inside the pod profile, agent CLIs `--version`, MCP handshake.
- Apptainer-clean (no runtime writes to the image, `ldconfig` at build) so MESA users can run the same images on CARC Easley/Hopper under Open OnDemand.

### D7. Kubernetes manifests shipped by the repo

`k8s/`: VICE `Localhost` seccomp profile + AppArmor profile (allow `mount`, `userns`, `clone(CLONE_NEW*)`, `pivot_root`); Kyverno policies (no `NOPASSWD` images via signed-image + label verification, drop ALL, seccomp Localhost, `runtimeClassName` by profile, cosign verify for `harbor.cyverse.org/vice/*`); PSA labels for `vice-apps` (warn/audit → enforce baseline, then restricted); NetworkPolicy templates N0–N3; RuntimeClasses `gvisor`/`kata`; agent-sandbox `SandboxTemplate` per profile and a `SandboxWarmPool`; OpenBao Helm values + policies + roles; egress-proxy sidecar spec; approval-inbox service (receives Claude `PermissionRequest`/`PreToolUse` http hooks and OpenCode permission events; deny-queue-resume; DE UI + notifications); Kueue `ClusterQueue` for agent Sandboxes; Falco rules and the kill-switch runbook (OpenBao lease revoke, LiteLLM `/key/block`, iRODS ticket delete, stop analyses). Proposed `app-exposer` changes (container securityContext, optional `agent` container, per-profile NetworkPolicy fields, SA per analysis, OpenBao wrapping token) are written as a design note plus a Go patch sketch for a PR to `cyverse-de/app-exposer`.

### D8. Where Agent Substrate / kagent / Iron Bank fit

- Agent Substrate + kagent: tracked in `docs/adr/` with the verified blockers (GPU disabled, HTTP-only ingress, no exec, privileged workers, CRD churn). Revisit when Substrate publishes a versioned API; the js2-substrate experiment (`kagent/OPEN-QUESTION-mcp-in-harness.md`) is already answered: v0.10.0 overwrites `openclaw.json`, so MCP servers must come through kagent's own resources, not the image.
- Iron Bank: adopt the *methodology* (`resources.yaml` with checksums, no network at build beyond declared resources, numeric non-root `USER`, `scripts/` dir, no `ADD`, no labels in Dockerfile); optionally consume hardened platform components (`dsop/afdco/openbao`, `opensource/aiml/vllm`, `opensource/aiml/ollama`, GPU Operator, Falco, Envoy) if CyVerse ops accept Registry1 accounts in CI; contributing our images back would require UBI bases, so that is out of scope.

## Repository layout (`idss-mesa/<name>`)

```
README.md                 what this is, profiles table, quick start
docs/
  research/               nine dimension reports + verdicts + critique (from this session), Agent Substrate brief, Kasm/Cursor/Iron Bank notes
  adr/                    ADR-0001 brain/hands split … ADR-0012 Iron Bank methodology
  threat-model.md         adapted from mesa-nmdid + Substrate + OWASP Agentic Top 10
  profiles.md             P0–P4 definitions, UNM data-class mapping, DE UI contract
  runbooks/               kill switch, approval inbox, node baseline audit
resources.yaml            every downloaded artifact: url, sha256, version (Renovate-managed)
docker-bake.hcl
images/
  tools/  common/  cli/  jupyterlab/  rstudio/  vscode/  kasm/  agent-runner/
k8s/
  profiles/ seccomp/ apparmor/ kyverno/ networkpolicy/ agent-sandbox/ openbao/ egress-proxy/ approval-inbox/ kueue/ falco/
  app-exposer/            design note + patch sketch
.github/workflows/        bake (amd64+arm64), security (hadolint/dockle/trivy/grype, SARIF), sign (cosign), renovate.json
tests/                    bats/pytest smoke tests: read-only run, no sudo, bwrap-in-profile, health, agent CLIs, MCP handshake
```

## Delivery phases (each ends in a commit; PRs to cyverse-vice for anything that changes today's images)

**Phase 0 — Bootstrap (day 1).** Create the repo (MIT, UNM Regents), commit `docs/research`, ADRs, this plan as `docs/plan.md`, `profiles.md`, and the node-baseline discovery checklist for CyVerse ops (K8s/containerd/kernel versions, CNI, PSA labels, `vice.use_csi_driver`, `/dev/fuse` in pods, GPU driver versions, A16 inventory).

**Phase 1 — Quick wins as upstream PRs (week 1–2), substrate-independent.** Remove `NOPASSWD: ALL`, `sudo gocmd upgrade`, and unconditional dotfile copies; add `osn-helper`; file-based AI Verde key + `apiKeyHelper`; ship Claude managed settings (sandbox, credential deny, `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`), Codex `sandbox_mode`/`approval_policy`, OpenCode `permission`, Cursor `cli-config.json`; `cyverse-logout` + login warning + `--ttl`; fix jupyterlab env sourcing and `envsubst`; fix vscode MCP path/JSON and `security.yml` login; fix kasm `sudoersq`, restore brute-force threshold; add `checkout` to scan jobs; pin bases by digest; add `security.yml` to `cli`. Update vice-toolkit's audit checklist so all seven images converge.

**Phase 2 — Image family (week 2–5).** `resources.yaml`, `tools` image, `common/`, Bake matrix, the five overlays (Kasm on `ubuntu-jammy-desktop-ai-dev`, VS Code on `coder/code-server`, RStudio non-root), `agent-runner`, CI with attestations/signing/scans, smoke tests, arm64. Publish to `harbor.cyverse.org/vice/mesa-*` beside the existing tags; validate with `vice-app-integrator` (`validate_dockerfile`, `validate_vice_config`) and register as DE tools/apps with its `create_tool`/`create_app`/`publish_app` tools.

**Phase 3 — Pod hardening + P1 (week 4–8, with CyVerse ops).** Seccomp/AppArmor profiles, Kyverno, PSA warn/audit; `hostUsers: false` where nodes allow; verify bubblewrap/Landlock sandboxes in a real VICE analysis (`/sandbox` in Claude Code, `agent --sandbox enabled`); `agent` UID inside the workbench; per-analysis NetworkPolicy levels; proposed `app-exposer` securityContext patch.

**Phase 4 — Broker + proxy + P2 (week 6–12).** OpenBao (K8s auth, JWT/Keycloak, SSH CA, Transit, audit), egress-proxy sidecar with sentinel injection, LiteLLM virtual keys with AI Verde, iRODS ticket minting, GitHub App tokens; first background agent pod as a Job sharing the workspace; approval inbox v1 (Claude http hooks + OpenCode API; deny-queue-resume); DE-visible parent/child analyses.

**Phase 5 — P3/P4 and GPU (week 10–16).** agent-sandbox `SandboxTemplate`s with gVisor and Kata RuntimeClasses; the two-week spike (KasmVNC/RStudio under gVisor, bwrap inside gVisor, vLLM under `--nvproxy`, s3fs under gVisor vs CSI); shared vLLM tier + gateway; Kueue quotas; Falco + kill switch; Agent Substrate/kagent re-evaluation ADR.

## Verification

- Repo: `docker buildx bake --check`; `make ci` = hadolint + dockle + bats; each image: `docker run --read-only -u 1000 <img> <health>` returns 2xx/3xx/401 on its port; `id -u` is 1000 and `sudo` is absent; `claude --version`, `codex --version`, `opencode --version`, `goose --version`, `agent --version`, `gocmd --version`, `gh --version`; MCP servers answer `initialize`; `bwrap --ro-bind / / --unshare-all --proc /proc true` succeeds under the shipped seccomp/AppArmor profile in a kind cluster (`tests/kind/`); Trivy/Grype SARIF uploaded; cosign `verify` passes; arm64 manifests present.
- VICE: launch each app through the DE (`vice-app-integrator` MCP `launch_app`/`vice_test_app`), confirm no dotfiles imported, `env` shows no API keys, `/sandbox` reports enabled in Claude Code, egress to a non-allowlisted host fails, Data Store still mounts, GPU app sees `nvidia-smi`.
- Broker: an agent pod can push to GitHub and write to its output collection while `cat ~/.irods/.irodsA`, `~/.aws/credentials`, `~/.ssh/id_*` do not exist and `printenv | grep -i key` shows sentinels only; revoking the OpenBao lease stops the job's access within one lease TTL.
- Autonomy: `claude -p --bare --permission-mode dontAsk ... --max-budget-usd 2` completes a task in a P2 pod while the human pod is stopped and restarted; an approval request appears in the inbox, is answered from the DE UI, and the job resumes via `--resume`.

## Decisions (confirmed with the user, 2026-09-06)

- **Repository:** `idss-mesa/mesa-sandbox`, public, MIT (Regents of the University of New Mexico), created with `gh repo create idss-mesa/mesa-sandbox --public`; first commit = docs/research + ADRs + `docs/plan.md` + `profiles.md` + node-baseline checklist; every later phase lands as its own commit(s) on `main` via short-lived branches and PRs.
- **Scope:** monorepo. `mesa-sandbox` builds `tools`, `cli`, `jupyterlab`, `rstudio`, `vscode`, `kasm`, `agent-runner` from one `docker-bake.hcl`, published as `harbor.cyverse.org/vice/mesa-*`. The existing five repos receive only the Phase 1 quick-win PRs; the private `idss-mesa/{jupyterlab,vscode,rstudio,kasm}` forks are archived once the new images are registered as DE tools.
- **Pilot clusters:** both in parallel. Phases 1–2 (images) target CyVerse VICE immediately; Phases 3–5 (seccomp/AppArmor profiles, `hostUsers`, OpenBao, egress proxy, agent-sandbox, gVisor/Kata, vLLM tier) are first validated on a Jetstream2 k3s cluster provisioned from a CACAO template (reusing `js2-substrate/cacao` and `caisp/cacao` patterns) and then ported to VICE with CyVerse ops; the plan keeps a `k8s/overlays/{js2,cyverse}` split so manifests differ only in StorageClass, RuntimeClass names, ingress and GPU labels.
- **Iron Bank:** methodology only (`resources.yaml` with sha256 for every download, no network at build beyond declared resources, numeric non-root `USER`, `scripts/` layout, no `ADD`, labels outside the Dockerfile); no Registry1 pulls.
