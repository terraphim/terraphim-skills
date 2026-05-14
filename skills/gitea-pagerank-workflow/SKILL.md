---
name: gitea-pagerank-workflow
description: "PageRank-powered task management using Gitea, tea CLI, and gitea-robot. Replaces beads/br and mcp_agent_mail with Gitea-native tooling. Use when agents need to pick work, prioritize issues, manage dependencies, coordinate multi-agent work, or run agile workflows against git.terraphim.cloud. Triggers: 'what should I work on', 'pick next task', 'triage issues', 'show ready tasks', 'prioritize backlog', 'claim issue', 'close issue', 'add dependency', 'show dependency graph', 'coordinate work', 'start session', 'run workflow'. Keywords: gitea, pagerank, triage, ready, robot, tea, issue, priority, dependency, backlog, sprint."
---

# Gitea PageRank Workflow

Gitea is the single source of truth for task management, prioritization, and multi-agent coordination. Use `gitea-robot` for PageRank-based prioritization and `tea` for issue/PR lifecycle.

## Environment Setup

```bash
export GITEA_URL="https://git.terraphim.cloud"
export GITEA_TOKEN=$(op read "op://TerraphimPlatform/gitea-test-token/credential")
```

Verify: `curl -s -H "Authorization: token $GITEA_TOKEN" "$GITEA_URL/api/v1/user" | jq .login`

## Core Commands

### Discover Work (PageRank-ranked)

```bash
# Top priority issues ranked by dependency impact
gitea-robot triage --owner OWNER --repo REPO --format json

# Unblocked issues ready to start (no blocking dependencies)
gitea-robot ready --owner OWNER --repo REPO

# Full dependency graph
gitea-robot graph --owner OWNER --repo REPO
```

PageRank scores: higher = blocks more downstream work. Fix high-PageRank issues first.

### Issue Lifecycle (tea CLI)

```bash
# List open issues
tea issues list --state open

# Create issue with labels
tea issues create --title "..." --description "..." --labels "priority/P1-high,type/task"

# Claim issue (assign + label)
tea issues edit IDX --add-labels "status/in-progress" --add-assignees "AGENT_NAME"

# Add comment (progress, coordination)
tea comment IDX "message"

# Close issue
tea issues close IDX
```

### Dependencies

```bash
# Add: issue X blocks issue Y
gitea-robot add-dep --owner OWNER --repo REPO --issue X --blocks Y
```

### PR Workflow

```bash
tea pulls create --title "Fix #IDX: title" --description "..." --base main --head branch
tea pulls merge --style squash
```

## Agent Workflow

### Single-Agent Flow

1. **Pick work**: `gitea-robot ready --owner O --repo R` -- pick highest PageRank unblocked issue
2. **Claim**: `tea issues edit IDX --add-labels "status/in-progress" --add-assignees "AGENT"`
3. **Branch**: `git checkout -b task/IDX-short-title`
4. **Implement**: TDD in worktree, commit with `Refs #IDX` in messages
5. **PR**: `tea pulls create --title "Fix #IDX: title" --base main --head task/IDX-short-title`
6. **Close**: `tea issues close IDX` after merge, add completion comment

### Multi-Agent Coordination

For multi-agent conventions including file reservation via labels, coordination via comments, and cross-repo patterns, see [references/agent-coordination.md](references/agent-coordination.md).

## Label Convention

Repos need standard labels for the workflow. Run `scripts/gitea-setup-labels.sh` to create them. See [references/label-convention.md](references/label-convention.md) for the full set.

## CLAUDE.md Integration

To replace the MCP Agent Mail + Beads snippet in a project's CLAUDE.md, use the snippet in [references/claude-md-snippet.md](references/claude-md-snippet.md).

## Migration from Beads/Agent Mail

For mapping from br/bd commands and Agent Mail to Gitea equivalents, see [references/migration.md](references/migration.md).

## Identifier Conventions

| Context | Format | Example |
|---------|--------|---------|
| Commit message | `Refs #IDX` or `Fixes #IDX` | `Refs #42` |
| Branch name | `task/IDX-short-title` | `task/42-auth-refactor` |
| PR title | `Fix #IDX: description` | `Fix #42: Refactor auth` |
| Cross-repo | `owner/repo#IDX` | `terraphim/gitea#42` |
