# ADR-0012: Pilot on Jetstream2 k3s and CyVerse VICE in parallel

Status: accepted (user decision 2026-09-06). Sources: `docs/research/cyverse-vice.md`, `mesa-carc.md`, js2-substrate and caisp CACAO templates.

## Context
Phases 3–5 need node-level changes (seccomp/AppArmor profiles, `hostUsers`, RuntimeClasses, OpenBao, GPU drivers) that CyVerse ops must schedule. MESA already has CACAO templates for Jetstream2 (js2-substrate, caisp) and an ACCESS allocation.

## Decision
Phases 1–2 (images, Phase 1 PRs) target CyVerse VICE immediately. Phases 3–5 are first validated on a Jetstream2 k3s cluster provisioned from a CACAO template in this repo (`k8s/overlays/js2`), then ported to VICE (`k8s/overlays/cyverse`) with CyVerse ops; manifests differ only in StorageClass, RuntimeClass names, ingress and GPU labels. The node-baseline checklist (`docs/runbooks/node-baseline-checklist.md`) is the hand-off to CyVerse ops.

## Consequences
Two overlays to maintain; results from Jetstream2 are recorded as dated `[measured]` notes in the relevant ADR before being claimed for VICE.
