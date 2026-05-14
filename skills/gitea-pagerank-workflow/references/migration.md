# Migration Guide: Beads/Agent Mail to Gitea PageRank

## Command Mapping

### Task Discovery

| Before (Beads) | After (Gitea) |
|---|---|
| `br ready --json` | `gitea-robot ready --owner O --repo R` |
| `br ready` (text) | `gitea-robot ready --owner O --repo R --format markdown` |
| `bd ready --json` | Same as above |

### Task CRUD

| Before (Beads) | After (Gitea) |
|---|---|
| `br create --title "X" --type=task --priority=2` | `tea issues create --title "X" --labels "type/task,priority/P2-medium"` |
| `br update ID --status=in_progress` | `tea issues edit IDX --add-labels "status/in-progress" --add-assignees "AGENT"` |
| `br close ID --reason "Done"` | `tea issues close IDX` then `tea comment IDX "Done: reason"` |
| `br dep add` | `gitea-robot add-dep --owner O --repo R --issue X --blocks Y` |
| `br stats` | `gitea-robot triage --owner O --repo R --format markdown` |
| `br sync --flush-only` | Not needed (Gitea is server-side) |

### Agent Coordination

| Before (Agent Mail) | After (Gitea) |
|---|---|
| `register_agent(project_key, agent_name)` | Not needed (GITEA_TOKEN identifies agent) |
| `file_reservation_paths(exclusive=true)` | `tea comment IDX "RESERVED: paths..."` |
| `send_message(thread_id="br-123")` | `tea comment 123 "message"` |
| `fetch_inbox` | `tea issues list --assignee AGENT --state open` |
| `acknowledge_message` | `tea comment IDX "ACK: understood"` |
| `macro_start_session` | `gitea-robot ready` + `tea issues edit IDX --add-labels "status/in-progress"` |
| `macro_file_reservation_cycle` | Label + comment-based reservation |

### Identifiers

| Before | After |
|---|---|
| `br-123` / `bd-123` | `#123` (Gitea issue index) |
| `thread_id: br-123` | Issue `#123` (comments are the thread) |
| `subject: [br-123] Feature` | Issue title: `Feature` |
| Commit: `bd-123` | Commit: `Refs #123` or `Fixes #123` |

## Files to Remove After Migration

- `.beads/` directory (per-repo SQLite database)
- MCP Agent Mail snippet in `~/.claude/CLAUDE.md` (between START/END markers)
- `bd-to-br-migration` skill (archive)

## Migration Steps

1. Export existing beads issues: `br list --json > beads-export.json`
2. Create corresponding Gitea issues with labels via `tea issues create`
3. Add dependencies via `gitea-robot add-dep`
4. Replace CLAUDE.md snippet (see [claude-md-snippet.md](claude-md-snippet.md))
5. Verify with `gitea-robot triage` and `gitea-robot ready`
6. Remove `.beads/` directory once confirmed

## What Changes for Agents

- No need to run `br sync` -- Gitea is always current
- No need to connect to bigbox MCP Agent Mail server
- No Tailscale dependency for coordination
- PageRank auto-prioritizes based on dependency graph topology
- All coordination happens through Gitea issue comments
