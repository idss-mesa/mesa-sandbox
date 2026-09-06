# ADR-0014: Human-in-the-loop as an asynchronous DE-owned approval inbox

Status: accepted. Sources: `docs/research/agent-harness-autonomy.md`, `prior-art-platforms.md`, `critique.md` (approvals gap).

## Context
Claude Code exposes `PermissionRequest`/`PreToolUse` `http` hooks (`allowedHttpHookUrls`, 600 s default timeout; a timed-out hook falls through to the normal permission flow), OpenCode exposes `POST /session/:id/permissions/:id` under `opencode serve` (headless `ask` currently hangs, issue #16367), Cursor relays `session/request_permission` over ACP, Goose/Gemini/Antigravity have policy-only modes. Anthropic's Remote Control cannot be used behind an LLM gateway. No harness guarantees blocking indefinitely.

## Decision
A DE-hosted approval-inbox service receives approval events (new domain from the egress proxy, `git push`, Data Store writes/deletes, destructive shell), records `tool_name`/`tool_input`, notifies the user (DE UI, e-mail, optional Slack/Matrix), and implements **deny-queue-resume**: the hook returns deny with a queued request id, the job pauses or exits resumable, and approval re-runs the tool via `claude -p --resume`, `codex exec resume`, `opencode` session API or `agent --resume`. Harnesses without a channel run in policy-only mode inside P3/P4. Every decision is written to the analysis audit record. Approving a domain hot-reloads the proxy allowlist.

## Consequences
The inbox is homegrown; Phase 4 delivers v1 for Claude Code and OpenCode, Phase 5 adds Cursor ACP and Codex if it gains a hook mechanism.
