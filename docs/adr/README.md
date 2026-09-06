# Architecture Decision Records

Numbered, append-only. Status values: proposed, accepted, superseded. Each ADR cites the research report that justifies it (`docs/research/`).

| ADR | Title | Status |
|---|---|---|
| [0001](0001-brain-hands-split.md) | Separate the human workbench pod from autonomous agent pods | accepted |
| [0002](0002-sandbox-profiles.md) | One sandbox-profile taxonomy (P0–P4) over four axes | accepted |
| [0003](0003-credential-broker-and-egress-proxy.md) | Agents never hold long-lived user secrets: OpenBao broker + credential-injecting egress proxy | accepted |
| [0004](0004-irods-access-for-agents.md) | iRODS access for agents: CSI mount, constrained tickets, hosted OAuth MCP; no `.irodsA` | accepted |
| [0005](0005-egress-at-pod-boundary.md) | Egress is enforced at the pod boundary, in-harness proxies are defense in depth | accepted |
| [0006](0006-llm-gateway-and-gpu-policy.md) | LLM access through a gateway with per-analysis keys; shared vLLM tier; GPU sharing rules | accepted |
| [0007](0007-agent-sandbox-primitive.md) | kubernetes-sigs/agent-sandbox is the pod primitive; Agent Substrate and kagent are watch items | accepted |
| [0008](0008-image-family.md) | One monorepo image family: tools image, common layer, Bake matrix, no sudo, digest pins, `resources.yaml` | accepted |
| [0009](0009-kasm-ai-dev-studio-base.md) | Kasm AI Dev Studio (`ubuntu-jammy-desktop-ai-dev`) is the desktop base | accepted |
| [0010](0010-cursor-cli.md) | Ship Cursor's `agent` CLI as a bring-your-own-subscription harness | accepted |
| [0011](0011-iron-bank-methodology.md) | Adopt Iron Bank's hardening and reproducible-build methodology, not its registry | accepted |
| [0012](0012-pilot-clusters.md) | Pilot on Jetstream2 k3s and CyVerse VICE in parallel | accepted |
| [0013](0013-multi-arch-build-fleet.md) | Native multi-architecture builds (amd64 + arm64) merged into manifest lists on harbor.cyverse.org | accepted |
| [0014](0014-approval-inbox.md) | Human-in-the-loop as an asynchronous DE-owned approval inbox (deny-queue-resume) | accepted |
| [0015](0015-app-bases.md) | App bases: quay.io Jupyter Docker Stacks, rocker (non-root rserver), coder/code-server, Kasm | accepted |
