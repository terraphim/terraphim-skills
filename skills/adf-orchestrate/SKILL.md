---
name: adf-orchestrate
description: |
  Dispatch, monitor, and cancel long-running AI Dark Factory (ADF) agents
  on bigbox via the adf-ctl CLI. Use when the user wants to "trigger an
  agent", "run X overnight", "kick off the meta-learning agent", "check
  what ADF is doing", "cancel agent Y", or has a task that should run on
  bigbox rather than in-session (long-horizon analysis, scheduled work,
  agents that need the bigbox environment). Distinct from `terraphim-rlm`
  (in-session sandboxed execution): this skill fires-and-monitors
  background agents over SSH plus HMAC-signed webhook. Requires SSH access
  to bigbox and a webhook HMAC secret. Do not use for synchronous
  in-session work -- ADF is asynchronous by design.
license: Apache-2.0
---

# ADF Orchestrate

## When to use

Use this skill when the work belongs on bigbox, not in this session:

- Long-running (over about ten minutes) agent runs the user wants to start
  and walk away from
- Tasks that need bigbox-only resources (Firecracker, GPU, large local
  models, mounted haystacks)
- Scheduled or triggered overnight work
- Checking the status of agents started in a previous session
- Cancelling a stuck or runaway agent

Do NOT use when:

- The work is short and fits in-session -- use `terraphim-rlm` or call tools
  directly
- The user wants synchronous chat-bound results -- ADF runs asynchronously
- The user wants to ingest into the KG -- use `kg-rlm-ingest`

## Exact invocation -- do not invent subcommands

The CLI is `adf-ctl` with exactly four subcommands. Do not guess flag
names. The canonical invocations are:

```
adf-ctl agents
adf-ctl trigger <name> [--context "..."] [--wait] [--timeout 1200]
adf-ctl status [--since 1h]
adf-ctl cancel <name>
```

`trigger` is for starting an agent. There is no `adf-ctl agent start`,
no `--overnight` flag, no `--background` flag. The agent runs detached by
default unless `--wait` is passed.

## Why

ADF agents run on bigbox under a systemd-managed orchestrator and survive
this Claude Code session ending. `adf-ctl` is the safe, audited path: it
signs webhook payloads with HMAC, scopes commands through SSH, and the
orchestrator enforces an agent allowlist server-side. Using `ssh bigbox`
directly bypasses these guardrails.

## Prerequisites

- `adf-ctl` on `PATH` (built from
  `crates/terraphim_orchestrator/src/bin/adf-ctl.rs`)
- SSH access to the host alias `bigbox` (or override via `--host`)
- HMAC secret available via env (`ADF_WEBHOOK_SECRET`) or in
  `/opt/ai-dark-factory/orchestrator.toml`

If any are missing, surface the specific gap to the user; do not invent
workarounds.

## adf-ctl command reference

| Command | Purpose |
|---|---|
| `adf-ctl agents [--format json]` | List configured agent names from orchestrator TOML |
| `adf-ctl trigger <name> [--context "..."] [--wait] [--timeout 1200]` | Fire an agent; optionally block until it exits |
| `adf-ctl status [--since 1h] [--format json]` | Show running agents and recent exits |
| `adf-ctl cancel <name>` | Best-effort kill via SSH+pgrep |

Defaults: `--host bigbox`, `--endpoint http://172.18.0.1:9091/webhooks/gitea`.
Override only if the user has a non-default setup.

Whenever the result will be parsed (programmatic checks, scripted status
polling), pass `--format json` on `agents` and `status` so the output is a
stable envelope rather than free-form human text. Default remains `human`
for back-compatibility. JSON schemas (terraphim-ai #1495):

```jsonc
// adf-ctl agents --format json
{ "host": "bigbox", "agents": ["meta-learning", "build-runner", ...] }

// adf-ctl status --format json
{
  "host": "bigbox",
  "since": "1h",
  "recent_activity": [ { "line": "May 16 12:00 ..." }, ... ],
  "running_processes": [ { "pid": "12345", "etimes": "3600", "cputime": "...", "comm": "claude" }, ... ],
  "best_effort": true,
  "note": "best-effort via SSH process scan; not authoritative without admin socket"
}
```

## Procedure

1. **Confirm the agent exists**: `adf-ctl agents`. If the user named an
   agent not in the list, surface the gap -- do not silently rename or
   guess. The orchestrator TOML is the source of truth.

2. **Cross-reference Gitea**: if this dispatch is tied to ongoing work,
   run `gtr ready --owner terraphim --repo terraphim-ai` (or the relevant
   repo) and use the issue index in the context string. This links the
   ADF audit trail to the issue:

   ```
   adf-ctl trigger meta-learning --context "Refs #1234 -- weekly retro"
   ```

3. **Trigger**: `adf-ctl trigger <name> --context "<concrete task>"`. Add
   `--wait` only if the user explicitly wants synchronous blocking; the
   default 20-minute timeout will hold the session.

4. **Confirm running**: `adf-ctl status --since 5m`. Surface the real
   output to the user -- do not claim success without evidence. If the
   agent does not appear, the webhook may have been rejected (bad HMAC,
   bad payload) -- check the orchestrator logs.

5. **On-demand follow-up**: if the user later asks "is it still running?",
   call `adf-ctl status` once. Do not poll in a loop -- this skill is for
   one-shot dispatch and on-demand status, not babysitting.

6. **Cancel**: `adf-ctl cancel <name>`. Warn the user that cancel is
   best-effort (it uses SSH plus `pgrep`) and may leave partial state.
   Recommend they check `status` after cancellation to confirm exit.

## Anti-patterns

- Polling `adf-ctl status` in a tight loop -- use `--wait` if you want
  blocking behaviour
- Using `--wait` without warning the user about the default 20-minute
  timeout
- Bypassing `adf-ctl` to SSH bigbox directly to start agents -- the HMAC
  signature is how the orchestrator authorises and audits
- Inventing agent names not in `adf-ctl agents` output
- Triggering more than one agent in a single skill invocation without the
  user explicitly asking for fan-out

## Failure modes

| Symptom | Likely cause | Action |
|---|---|---|
| `HMAC secret missing` | env unset and TOML absent | Tell user to set `ADF_WEBHOOK_SECRET` or check `/opt/ai-dark-factory/orchestrator.toml` |
| `ssh: connect ... timed out` | Off-network or bigbox down | Surface raw ssh error; do not retry blindly |
| `agent not allowed` | Name absent from orchestrator TOML | Run `adf-ctl agents` and ask user to pick from the list |
| `status` empty after trigger | Webhook rejected | Check orchestrator logs via `ssh bigbox journalctl -u adf-orchestrator --since 5m` |

## CLI-first principle

Stay inside `adf-ctl`. Stay inside `gtr` for issue references. Do not
hand-craft SSH or curl commands when the CLIs exist.
