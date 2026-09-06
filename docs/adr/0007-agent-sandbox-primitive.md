# ADR-0007: kubernetes-sigs/agent-sandbox is the pod primitive; Agent Substrate and kagent are watch items

Status: accepted. Sources: `docs/research/k8s-agent-substrates.md`, `agent-substrate-kagent-brief.md`, `runtime-isolation.md`, `critique.md` (contradiction 2).

## Context
The team's js2-substrate design targets kagent `AgentHarness` on Agent Substrate 0.0.8. Verified facts: upstream Agent Substrate has one release (v0.0.0, "not ready for production"); "0.0.8" is the kagent fork; ingress is HTTP/WebSocket-only with no exec; GPUs are currently unsupported and CUDA checkpointing is unsolved; worker pods need 13 added capabilities with seccomp/AppArmor Unconfined; there is no ate-api authorization; kagent v0.10.0 overwrites the harness image's `openclaw.json` (the design's open question, answered in the bad case) and is replacing `AgentHarness` with a v1alpha3 `Harness`. kubernetes-sigs/agent-sandbox reached v1.0.0 on 2026-08-28 with a stable v1beta1 API, RuntimeClass-delegated isolation, `shutdownTime`, `volumeClaimTemplates`, warm pools and an optional router; NVIDIA OpenShell's Kubernetes driver builds on it.

## Decision
Use agent-sandbox `Sandbox`/`SandboxTemplate`/`SandboxClaim`/`SandboxWarmPool` for P2–P4 agent pods, with one `SandboxTemplate` per profile differing in `runtimeClassName` (runc, gvisor, kata) and NetworkPolicy. Set `shutdownPolicy: Delete` explicitly. Keep the DE as the control plane. Track Agent Substrate and kagent in this ADR's follow-ups; re-evaluate when Substrate publishes a versioned API and GPU/device support, or when kagent's `Harness` (claude|codex adapters, `credentialRef`, approvals) stabilises. A kagent `Harness` on a Substrate `WorkerPool` may later become an optional P3 backend for headless, CPU-only, public-data agents (the js2-substrate scope).

## Consequences
The js2-substrate repository remains a valid experiment for the Jetstream2 pilot but is not on the VICE critical path. The two-week gVisor/Kata spike (KasmVNC, RStudio, bubblewrap-in-gVisor, vLLM under nvproxy, s3fs) decides which apps may use R2/R3.
