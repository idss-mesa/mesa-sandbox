# ADR-0008: One monorepo image family

Status: accepted. Sources: `docs/research/image-build-technique.md`, `current-state-*.md`, user decision (monorepo).

## Context
Five repos copy-paste the same installer blocks, float on `:latest` bases, run `curl | bash` at build time, grant `NOPASSWD: ALL`, and have inconsistent CI. Native sidecars are GA, user namespaces are GA in Kubernetes 1.36, and Docker Bake, BuildKit attestations, cosign and Renovate are mainstream.

## Decision
- `resources.yaml` is the single source of truth for every downloaded artifact (url, filename, version, sha256 per arch), Iron Bank `hardening_manifest` style (ADR-0011); Dockerfiles consume it through `ARG`s and `COPY`, and Renovate updates it.
- A `tools` image holds every agent CLI and MCP server (Claude Code, Codex, OpenCode, Goose, Antigravity, `ccr`, `ant`, Cursor `agent`, `mcp-server-filesystem`, `irods-mcp-server`, `mesa-mcp` venv, `gocmd`, `gh`, GCM, `aws`, `ttyd`, `tini`) under `/opt/vice`; app images `COPY --from=tools`.
- `common/` holds the shared entry library (`vice-entry`), `cyverse-login`/`cyverse-logout`, `aiverde-setup`, harness configs (Claude managed settings, Codex, OpenCode, Goose, Cursor), MCP registrations pointing at OAuth endpoints, the `agent` user, and `osn-helper`.
- App overlays: `cli`, `jupyterlab`, `rstudio`, `vscode`, `kasm`, `agent-runner` (ADR-0015 for bases). Every image: fixed UID 1000 (GID 100 or the base's), no sudo package, final `USER 1000`, `tini`, no runtime writes into the image (Apptainer-clean), health endpoint per the vice-toolkit contract.
- `docker-bake.hcl`: targets `tools`, matrix `app × accel(cpu, cuda)`, `attest = ["type=provenance,mode=max", "type=sbom"]`, registry cache, `RUN --mount=type=cache`; multi-arch per ADR-0013; cosign keyless signing; hadolint DL3002, dockle CIS-DI-0001/0008, Trivy and Grype (report-only first, then gating); weekly rebuild.
- Published as `harbor.cyverse.org/vice/mesa-<app>[-cuda]:<tag>`; registered as DE tools through `vice-app-integrator`.

## Consequences
The five existing repos receive Phase 1 quick-win PRs only; the private idss-mesa image forks are archived after the new images are registered.
