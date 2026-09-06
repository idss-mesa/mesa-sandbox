# ADR-0002: One sandbox-profile taxonomy (P0–P4) over four axes

Status: accepted. Sources: `docs/research/critique.md` (contradiction 1), `runtime-isolation.md`, `k8s-agent-substrates.md`, `mesa-carc.md`.

## Context
The research produced six different "level" schemes (egress tiers, RuntimeClass tiers, UNM data classes, autonomy tiers, GPU tiers). They are orthogonal axes, and users, app authors and auditors need one vocabulary that the DE can record on an analysis.

## Decision
Define four axes and five named bundles (see `docs/profiles.md` for the normative table):
- Runtime R: R0 runc today; R1 runc + `hostUsers: false` + VICE `Localhost` seccomp/AppArmor, `allowPrivilegeEscalation: false`, drop ALL, no sudo; R2 gVisor; R3 Kata.
- Egress N: N0 internet; N1 trusted (CyVerse services, LLM gateway, MCP endpoints, GitHub, package registries); N2 CyVerse-only (Keycloak, Data Store, gateway, MCP); N3 none.
- Credentials C: C0 user's own files in `$HOME`; C1 broker-issued, proxy-injected, sentinels only.
- Autonomy A: A0 interactive prompts; A1 allowlist + asynchronous approval inbox; A2 policy-only automatic.
Profiles: P0 Legacy (R0/N0/C0/A0), P1 Workbench (R1/N1 or N0/C0 for the human, C1-style deny/mask for agents/A0–A1), P2 Background (separate runc pod, R1/N1–N2/C1/A1), P3 Autonomous (separate gVisor pod, R2/N2/C1/A2), P4 Isolated (Kata, whole GPU, R3/N2–N3/C1/A2). Data classes map onto profiles: UNM P-class any; C-class P2+ with N2 and on-campus snapshots; E-class and HIPAA/PHI/PCI/FERPA/CUI never (CARC Good Neighbor policy).

## Consequences
Apps declare a default and a maximum profile; raising a profile is a user action with consent text; the profile is a field on the analysis and appears in every audit record. Kyverno policies (ADR-0007, ADR-0008) are written per profile.
