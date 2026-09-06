# ADR-0006: LLM access through a gateway; shared vLLM tier; GPU sharing rules

Status: accepted. Sources: `docs/research/gpu-local-llm.md`, `credential-brokering.md`, `critique.md` (GPU fairness, cost).

## Context
AI Verde (`llm-api.cyverse.ai`) is LiteLLM over vLLM; LiteLLM issues virtual keys with `duration`, `max_budget`, `models`, `tpm/rpm`. CyVerse VICE GPUs are NVIDIA A16 (no MIG); CARC has L40S (no MIG), H100 and A100 (MIG). Time-slicing gives no memory or fault isolation. vLLM and Ollama both expose Anthropic `/v1/messages` for Claude Code. Cursor cannot use a custom endpoint; Codex needs the Responses API.

## Decision
- Default topology: a shared, GPU-scheduled vLLM service per model tier, fronted by AI Verde/LiteLLM (or agentgateway), reachable from analyses only through the gateway with a per-analysis virtual key injected by the launcher/proxy. app-exposer injects `ANTHROPIC_BASE_URL`, `ANTHROPIC_DEFAULT_*_MODEL`, `OPENAI_HOST`/`OPENAI_BASE_PATH`, and the OpenCode/Codex/Goose configs.
- In-pod Ollama sidecar only for whole-GPU allocations (one A16 sub-GPU or one L40S), with `OLLAMA_MODELS` on a read-only model volume (OCI ImageVolume on Kubernetes ≥ 1.36, else PVC), `OLLAMA_KEEP_ALIVE` set, never on time-sliced GPUs.
- MIG only on A100/H100; MPS or HAMi where per-user memory caps are required on non-MIG cards; DRA (`resource.k8s.io/v1`) piloted behind a flag on Kubernetes ≥ 1.34 with the NVIDIA DRA driver v0.5.x, device plugin stays the production default.
- gVisor GPU pods pin node drivers to `runsc nvproxy list-supported-drivers`; Kata GPU = one whole GPU per pod.
- Budgets: LiteLLM `max_budget`/`budget_duration` per key and team, harness caps (`--max-budget-usd`, `--max-turns`), Kueue quotas for agent Sandboxes, GPU-hours reported per analysis.

## Consequences
Agent pods stay CPU-only and cheaply sandboxable by default; only science workloads request GPUs directly. A CI smoke test runs each harness against the gateway after every image or vLLM bump.
