# ADR-0001: Separate the human workbench pod from autonomous agent pods

Status: accepted (2026-09-06). Sources: `docs/research/agent-harness-autonomy.md`, `prior-art-platforms.md`, `cyverse-vice.md`, `critique.md`.

## Context
Today the human and up to seven agent CLIs share one pod, one Unix user, one home and passwordless sudo. Long autonomous runs are interrupted when the human's session ends, and any agent can read every credential the human brought in. Every platform examined (Anthropic Claude Code on the web and Managed Agents, OpenAI Codex cloud, Coder, GitHub Copilot coding agent, NVIDIA OpenShell) runs the agent loop in a disposable isolation unit separate from the person's workspace and shares only the working tree.

## Decision
The VICE analysis pod stays the human's interactive **workbench**. Every autonomous run is launched as a **separate pod** with its own UID, Kubernetes ServiceAccount, lifetime, credentials (ADR-0003) and egress policy (ADR-0005), sharing only the workspace volume (RWX PVC or the iRODS CSI mount with a narrower `path_mapping_json`). The primitive is a kubernetes-sigs/agent-sandbox `Sandbox` (ADR-0007); the first implementation may be a plain Job or a second VICE analysis launched through Formation, labelled with the parent analysis id so the DE can show parent/child runs. Harness session state (`CLAUDE_CONFIG_DIR`, Codex rollouts, Goose sessions, Cursor chats) lives on the workspace volume so an evicted job resumes with `--resume`.

## Consequences
The human pod can be stopped and restarted without killing the agent. Agents inside the workbench (profile P1) still run as a distinct `agent` UID with in-harness sandboxes, but that is a convenience tier, not the security boundary. app-exposer gains an optional agent-pod launch path (design note in `k8s/app-exposer/`).
