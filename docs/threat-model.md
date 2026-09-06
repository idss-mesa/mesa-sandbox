# Threat model

Adapted from the mesa-nmdid compliance design, Agent Substrate's threat model, Anthropic's sandboxing guidance and the OWASP Top 10 for Agentic Applications (2026). Scope: a VICE analysis (workbench pod) plus zero or more agent pods for one user.

## Assets
User credentials (CyVerse password / `.irodsA`, OSN keys, SSH keys, GitHub tokens, AI Verde and vendor API keys, harness OAuth caches); the user's Data Store home and shared collections; workspace contents; LLM spend and GPU time; the DE's Keycloak session; cluster nodes and other tenants.

## Adversaries
1. A prompt injection reaching an agent through a file, web page, MCP result or Data Store content.
2. An agent misbehaving on its own (wrong `rm`, pasting a key into a commit or chat, runaway loops).
3. A compromised upstream release of a harness, MCP server, extension or base image.
4. Another tenant on the same node or namespace.
5. A curious or malicious user trying to escalate from their own pod to the node or to other users' data.

## Trust boundaries
Human ↔ agent UID (P1); workbench pod ↔ agent pod (P2+); pod ↔ node (R1 seccomp/AppArmor/userns, R2 gVisor, R3 Kata); pod ↔ network (NetworkPolicy + egress proxy); agent ↔ credentials (OpenBao + proxy; tickets); DE ↔ cluster (app-exposer, Kyverno).

## Threats and controls

| # | Threat | Control | Profile |
|---|---|---|---|
| T1 | Agent reads `.irodsA`, `.aws`, `.ssh`, harness tokens | separate `agent` UID, 0700 human dirs, managed-settings deny/mask; P2+ never mount them | P1+ |
| T2 | Secrets in process environment leak via `env`, crash logs, subprocess inheritance | file-based keys, `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`, sentinels + proxy injection | P1+ |
| T3 | `sudo` to root defeats sandboxes, reads `/proc/*/environ` | no sudo binary, `allowPrivilegeEscalation: false`, drop ALL | P1+ |
| T4 | Exfiltration to an arbitrary host | default-deny NetworkPolicy + proxy allowlist (N1–N3); approvals for new domains | P1+ |
| T5 | Exfiltration through an allowed channel (LLM endpoint, GitHub) | data-class mapping (C-class → on-prem models only, N2), DLP gap tracked in backlog, audit of proxy requests | P2+ |
| T6 | Destructive Data Store operations | tickets with byte/use/expiry limits; ticket/ACL/rule MCP tools denied for agents; soft delete; approval inbox for deletes/moves | P2+ |
| T7 | Runaway spend / GPU hogging | LiteLLM budgets, `--max-budget-usd`/`--max-turns`, Kueue quotas, `shutdownTime` | all |
| T8 | Supply-chain compromise of a harness or MCP server | `resources.yaml` checksums, digest-pinned bases, SBOM/provenance, cosign verification at admission, weekly rebuilds with scans | all |
| T9 | Container escape from a compromised agent | R1 profiles + userns; R2 gVisor; R3 Kata for untrusted/sensitive work | P2+ |
| T10 | Cross-agent token theft (one harness reads another's cache) | per-agent 0700 dirs; per-job `emptyDir` in agent pods | P1+ |
| T11 | Approval fatigue / hidden approvals | inbox with full `tool_name`/`tool_input`, per-decision audit, expiring requests | A1 |
| T12 | Lost work when a pod is evicted | workspace volume holds harness state; resumable jobs; git worktrees per job | P2+ |
| T13 | Node-level compromise of a shared GPU | no time-slicing for agent pods; MIG/whole GPU; nvproxy driver pinning | P3/P4 |
| T14 | Snapshot/volume stores holding credentials or C-class data off campus | C1 (no secrets in pods), data-class location constraints | P2+ |
| T15 | Kill switch missing | runbook: revoke OpenBao leases, LiteLLM `/key/block`, delete tickets, stop analyses; Falco alerts | all |

## Residual risks
gVisor does not protect against NVIDIA driver bugs; in-harness sandboxes exclude MCP servers and hooks (why the pod boundary exists); third-party subscriptions send prompts to vendors (P-class data only); OSN keys are static until OSN offers STS; Cursor cannot be pointed at on-prem models.
