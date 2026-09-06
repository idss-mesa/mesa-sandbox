# Sandbox profiles (normative)

One taxonomy for users, app authors, the DE and auditors. A profile is a bundle over four axes. The DE records the profile on the analysis; apps declare `default_profile` and `max_profile`; a user may raise the profile within the app's range after a consent screen; every audit record carries the profile.

## Axes

| Axis | Values |
|---|---|
| **R** runtime | R0 runc as today (no capability drop). R1 runc + `hostUsers: false` (where nodes allow) + VICE `Localhost` seccomp and AppArmor profiles, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, no sudo binary in the image. R2 gVisor `RuntimeClass` (`--nvproxy` on GPU nodes; ignores pod seccomp/AppArmor; no `hostUsers`). R3 Kata (`kata-qemu`, `kata-qemu-nvidia-gpu`). |
| **N** egress | N0 internet (proxy logs only). N1 trusted: CyVerse services (Keycloak, Data Store, DE/Terrain, Formation), LLM gateway, hosted MCP endpoints, GitHub, package registries (PyPI, conda-forge, CRAN, npm, Harbor). N2 CyVerse-only: Keycloak, Data Store, gateway, MCP. N3 none. |
| **C** credentials | C0 the user's own files in `$HOME` (legacy). C1 broker-issued (OpenBao), proxy-injected; the process sees sentinels only; non-HTTP credentials replaced by tickets, CSI, SSH CA, OAuth MCP. |
| **A** autonomy | A0 interactive prompts in the terminal/IDE. A1 allowlist + asynchronous approval inbox (deny-queue-resume). A2 policy-only automatic (`claude --permission-mode dontAsk|auto`, `codex -a never`, `opencode run` with a complete permission map, `GOOSE_MODE=auto`, `agent --force`). |

## Profiles

| Profile | Where the agent runs | R | N | C | A | Human dotfiles | Typical use |
|---|---|---|---|---|---|---|---|
| **P0 Legacy** | inside the workbench, same UID | R0 | N0 | C0 | A0 | shared | today's images; to be retired |
| **P1 Workbench** | inside the workbench as UID `agent` (1001) with in-harness sandbox (bubblewrap/Landlock) and managed settings that deny/mask credential paths and variables | R1 | N1 (N0 if the app allows) | human C0 in 0700 dirs; agent sees sentinels | A0 / A1 | 0700, not readable by `agent` | pair programming in JupyterLab/RStudio/VS Code/desktop/CLI |
| **P2 Background** | separate pod (Job or `Sandbox`), runc | R1 | N1 or N2 | C1 | A1 | not mounted | long analyses the user wants to keep running |
| **P3 Autonomous** | separate `Sandbox`, gVisor | R2 | N2 | C1 | A2 | not mounted | unattended jobs, untrusted inputs, prompt-injection-prone tasks |
| **P4 Isolated** | separate `Sandbox`, Kata, whole GPU | R3 | N2 or N3 | C1 | A2 | not mounted | sensitive (C-class) data, local models, Docker-in-pod |

## Data-class mapping (UNM classification, CARC Good Neighbor policy)

| Data | Allowed profiles | Constraints |
|---|---|---|
| P (public) | any | — |
| C (controlled research data) | P2+ with N2; P1 only with N2 and on-prem models | LLM traffic only to on-prem/AI Verde models; snapshots and workspace volumes stay on campus or CyVerse; no third-party subscriptions (Claude/Codex/Cursor/Gemini cloud) |
| E (restricted), HIPAA/PHI, PCI, FERPA, CUI, export-controlled | none | not permitted on VICE or CARC systems |

## What each profile guarantees

- **Credential exposure:** P1 removes the same-UID read path and env inheritance; P2+ remove the credentials from the pod entirely.
- **Blast radius of a prompt injection:** P1 limited to the agent UID's writable paths and the allowlisted network; P2 limited to the job's workspace and tickets; P3/P4 add kernel/VM isolation and no interactive session to hijack.
- **Durability:** P2+ jobs survive the human pod's restart; state on the workspace volume; `shutdownTime` from the analysis time limit.
- **Approvals:** A1 posts to the DE inbox (ADR-0014); A2 records denials and completions only.
- **GPU:** P1/P2 may request `nvidia.com/gpu` for science workloads; P3 only on nvproxy-supported drivers; P4 one whole GPU.

## DE / ai-sandboxes-ui contract

- Analysis field `sandbox_profile` (enum P0–P4) and `sandbox_axes` (R/N/C/A) recorded at launch; app metadata `default_profile`, `max_profile`, `allowed_egress` (extra domains for N1).
- Launch form shows the profile badge, the consent text for P2+ (what the agent can and cannot reach), and the parent analysis for child agent runs.
- Kyverno enforces the pod shape per profile; the launcher refuses a profile above the app's maximum.
