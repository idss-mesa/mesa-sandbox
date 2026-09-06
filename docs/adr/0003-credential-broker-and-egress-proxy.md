# ADR-0003: Agents never hold long-lived user secrets

Status: accepted. Sources: `docs/research/credential-brokering.md`, `prior-art-platforms.md`, `agent-harness-autonomy.md`.

## Context
Credentials currently reach the agent as files (`~/.irods/.irodsA`, `~/.aws`, `~/.ssh`, `~/.config/gh`, each harness's OAuth cache) and environment variables (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `LLM_API_KEY` exported from `~/.bashrc`). Anthropic's cloud sandboxes, Claude Code's `sandbox.credentials` (mask, `injectHosts`, `awsPairs`), OpenShell's providers v2 and Agent Substrate's egress policies all use the same pattern: the sandbox sees a sentinel, a proxy outside the sandbox swaps in the real secret for allow-listed hosts.

## Decision
- **Broker:** OpenBao 2.6.x (MPL-2.0) with `auth/kubernetes` (one ServiceAccount per analysis, role bound by `bound_service_account_names/namespaces`, short TTL), `auth/jwt` against Keycloak with CEL-bound claims for user and analysis, response wrapping for the launcher hand-off, SSH secrets engine (CA-signed 30-minute certificates), Transit (encrypt user-owned material such as OSN keys at rest), KV, Kubernetes secrets engine, and an audit device streamed into the DE analysis record. The AWS engine is available as the official external plugin `openbao-plugin-secrets-aws` if OSN ever exposes STS.
- **Egress proxy:** a native sidecar (initContainer with `restartPolicy: Always`) built from `@anthropic-ai/sandbox-runtime`'s TLS-terminating proxy (Apache-2.0) or agentgateway, holding per-analysis secrets fetched from OpenBao, injecting `Authorization`/API-key headers only for allow-listed hosts (AI Verde, api.anthropic.com, api.openai.com, api.github.com), re-signing SigV4 for OSN, and providing a scoped git credential. NetworkPolicy makes it the only egress (ADR-0005).
- **Per credential:** AI Verde → per-analysis LiteLLM virtual key (`duration`, `max_budget`, `models`); GitHub → GitHub App installation token (1 h) via credential helper or proxy; SSH → OpenBao SSH CA + `ssh-agent` socket, never key files; OSN → keys only in OpenBao, proxy re-signs; subscriptions (Claude, Codex, Cursor, Gemini) → user's own OAuth caches stay 0700 in the human home and are never mounted into agent pods.
- **Substrate-independent fix now:** agents run as a distinct `agent` UID (1001) with no sudoers entry; human dotfiles are 0700; `.irodsA` obfuscation is keyed on the uid so a different uid cannot trivially decode it.

## Consequences
The launcher (app-exposer) must create a ServiceAccount per analysis and pass a wrapped OpenBao token. Non-HTTP protocols cannot be proxied and are replaced (ADR-0004). Revocation is one OpenBao lease revoke plus LiteLLM `/key/block`.
