---
name: learning-capture
description: |
  Automatic capture of failed commands as structured learning documents using Terraphim.
  PostToolUse hook intercepts bash command failures and records them with error context
  for later querying and correction. Builds an evolving knowledge base of developer
  mistakes and solutions to avoid repeating errors across sessions.
license: Apache-2.0
---

# Learning Capture

Use this skill when setting up, using, or troubleshooting Terraphim's automatic learning capture system that records failed commands and their context.

## Overview

Terraphim learning capture automatically records bash command failures during AI-assisted development sessions. Each failure is stored as a structured Markdown document with the command, error output, exit code, working directory, and timestamp.

**Key Capabilities:**
- Automatic capture via PostToolUse Claude Code hook
- Structured Markdown storage in `~/.local/share/terraphim/learnings/`
- Query past failures by command pattern
- Add corrections to existing learnings
- Install hooks for Claude Code, Codex, and OpenCode

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Claude Code (PostToolUse)                  │
│  Hook fires after every Bash tool call                       │
└───────────────────────┬─────────────────────────────────────┘
                        │ JSON: {tool_name, tool_input, tool_result}
                        ▼
┌─────────────────────────────────────────────────────────────┐
│            ~/.claude/hooks/learning-capture.sh               │
│  - Filters: only Bash tools, only non-zero exit codes        │
│  - Skips: test commands (cargo test, npm test, etc.)         │
│  - Fail-open: continues even if capture fails                │
└───────────────────────┬─────────────────────────────────────┘
                        │ terraphim-agent learn capture ...
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              terraphim-agent learn capture                   │
│  Stores structured learning document with YAML frontmatter   │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│     ~/.local/share/terraphim/learnings/learning-*.md         │
│  YAML frontmatter: id, command, exit_code, captured_at, tags │
│  Body: ## Command, ## Error Output sections                  │
└─────────────────────────────────────────────────────────────┘
```

## For Humans

### Quick Install

```bash
# Install the PostToolUse hook for Claude Code automatically
terraphim-agent learn install-hook claude

# Or manually: add to ~/.claude/settings.json under hooks.PostToolUse
# See the hook script at ~/.claude/hooks/learning-capture.sh
```

### Manual Hook Script Setup

Create `~/.claude/hooks/learning-capture.sh`:

```bash
#!/bin/bash
# Read JSON from stdin, call terraphim-agent learn hook
INPUT=$(cat)
echo "$INPUT" | terraphim-agent learn hook
echo "$INPUT"
```

Add to `~/.claude/settings.json`:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/learning-capture.sh"}]
      }
    ]
  }
}
```

### Querying Learnings

```bash
# List recent captured failures
terraphim-agent learn list

# Search by command pattern
terraphim-agent learn query "cargo build"
terraphim-agent learn query "git push"

# Add a correction to an existing learning
terraphim-agent learn correct <id> "Use 'cargo build --release' instead"
```

### Learning Document Format

Each captured learning is stored as:
```markdown
---
id: <hash>-<timestamp>
command: <failed command>
exit_code: <non-zero code>
source: Global
captured_at: <ISO timestamp>
working_dir: <project directory>
tags:
  - learning
  - exit-<code>
---

## Command

`<command that failed>`

## Error Output

```
<stderr/stdout from the failure>
```
```

## For AI Agents

### Before Running a Risky Command

Query learnings to check if a similar command has failed before:

```bash
terraphim-agent learn query "<command keyword>"
```

If results exist, review the error patterns and corrections before proceeding.

### After a Session

Review recent learnings to identify recurring patterns:

```bash
terraphim-agent learn list
```

### Debug Mode

Enable debug output from the hook:
```bash
export TERRAPHIM_LEARN_DEBUG=true
```

## When to Use This Skill

- Setting up a new development environment (run `install-hook`)
- Diagnosing why the hook is not capturing failures
- Reviewing accumulated learnings before starting a complex task
- Adding corrections after discovering the right fix for a recurring error
- Configuring hook behavior (filtering, debug mode)

## Trigger Phrases

- "why isn't learning capture working"
- "set up learning capture"
- "check my learnings for..."
- "what failed when I tried to..."
- "install the learning hook"
- "debug learning capture"

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TERRAPHIM_LEARN_DEBUG` | `false` | Enable debug logging from hook |
| Storage path | `~/.local/share/terraphim/learnings/` | Where learnings are stored |

## Supported AI Agents

| Agent | Install Command |
|-------|----------------|
| Claude Code | `terraphim-agent learn install-hook claude` |
| OpenAI Codex | `terraphim-agent learn install-hook codex` |
| OpenCode | `terraphim-agent learn install-hook opencode` |
