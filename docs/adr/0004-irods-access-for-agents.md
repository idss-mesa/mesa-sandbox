# ADR-0004: iRODS access for agents

Status: accepted. Sources: `docs/research/credential-brokering.md`, `cyverse-vice.md`, `mesa-carc.md`, `critique.md` (iRODS ticket gap).

## Context
`.irodsA` is the user's reversible CyVerse password (also their Keycloak/DE password). On CSI clusters the analysis pod reads `/data-store` with no credential at all (proxy auth lives in the driver's node DaemonSet); the password enters the pod only when the user runs `iinit`/`cyverse-login`. The iRODS native protocol cannot be rewritten by an HTTP proxy. iRODS tickets default to anyone, any host, any number of uses, forever.

## Decision
- Human workbench: keep `cyverse-login` for GoCommands and local MCP servers, but write `.irodsA` into a 0700 human-only home, pass `--ttl` equal to the analysis time limit, add `cyverse-logout`, and print the warning that the stored credential is the account password.
- Agents: read through the CSI mount (narrower `path_mapping_json`, read-only inputs, one writable output collection); write through **DE-minted tickets** always constrained with `mod uses`, `write-file`, `write-byte`, `expire=<analysis end>` and `add host` where pod egress IPs are stable; API access through the hosted OAuth MCP endpoints (`https://mcp.cyverse.ai/mcp` with client `mcp-client`, `https://de.cyverse.org/formation/mcp`) or a pod-local `mcp-remote` bridge for harnesses that cannot complete PKCE without a browser. Local `mesa-mcp`/`irods-mcp-server` in agent pods get tickets, never `.irodsA`. Deny the ticket/ACL/rule tools (`ds_create_ticket`, `ds_modify_ticket`, `ds_use_ticket`, `ds_modify_access`, `ds_modify_access_inheritance`, `ds_execute_rule`, `mesa_policy_enable`) at the gateway/proxy layer for P2+ (the mesa-nmdid rule).
- Ask CyVerse for Data Store ≥ 4.3.5 (ticket write-file limit fix), shorter `password_max_time` for VICE-launched sessions, and confirmation of the CSI driver's production auth mode.

## Consequences
No agent pod contains an iRODS password. Hard deletes by agents go through soft-delete/trash and approval (ADR-0014).
