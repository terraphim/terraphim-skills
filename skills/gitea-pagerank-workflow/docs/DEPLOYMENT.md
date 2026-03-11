# Gitea PageRank Workflow Skill - Setup Guide

## Prerequisites

1. **Gitea instance** at `https://git.terraphim.cloud` with Robot API (v1.26.0+)
2. **tea CLI** installed: `brew install tea` or from https://gitea.com/gitea/tea
3. **gitea-robot CLI** built from the Gitea fork:
   ```bash
   cd /path/to/terraphim/gitea
   go build -o ~/bin/gitea-robot ./cmd/gitea-robot
   ```
4. **1Password CLI** for token management

## Environment Setup

```bash
export GITEA_URL="https://git.terraphim.cloud"
export GITEA_TOKEN=$(op read "op://TerraphimPlatform/gitea-test-token/credential")
```

Tea login:
```bash
tea login add --name terraphim --url "$GITEA_URL" --token "$GITEA_TOKEN"
```

## Label Setup (per repo)

```bash
./scripts/gitea-setup-labels.sh OWNER REPO
```

This creates priority/P0-P4, status/in-progress|blocked|in-review, and type/task|bug|feature|chore labels.

## Verify Installation

```bash
# Check tea
tea repos list

# Check gitea-robot
gitea-robot triage --owner terraphim --repo gitea

# Check Robot API
curl -s -H "Authorization: token $GITEA_TOKEN" \
  "$GITEA_URL/api/v1/robot/ready?owner=terraphim&repo=gitea" | jq .
```

## Applying CLAUDE.md Changes

Replace the MCP Agent Mail + Beads section in `~/.claude/CLAUDE.md`:

1. Find the block between `<!-- MCP_AGENT_MAIL_AND_BEADS_SNIPPET_START -->` and `<!-- MCP_AGENT_MAIL_AND_BEADS_SNIPPET_END -->`
2. Replace with the content from `references/claude-md-snippet.md`

## Replaces

- **beads_rust** (`br`/`bd` CLI, `.beads/` directories)
- **MCP Agent Mail** (bigbox server at 100.106.66.7:8765)
- **bd-to-br-migration** skill (archive after transition)
