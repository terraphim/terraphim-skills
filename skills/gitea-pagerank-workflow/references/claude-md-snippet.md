# CLAUDE.md Snippet: Gitea PageRank Workflow

Replace the `<!-- MCP_AGENT_MAIL_AND_BEADS_SNIPPET_START -->` to `<!-- MCP_AGENT_MAIL_AND_BEADS_SNIPPET_END -->` block in `~/.claude/CLAUDE.md` with the content below.

---

<!-- GITEA_PAGERANK_WORKFLOW_START -->

## Gitea PageRank Workflow: task management and agent coordination

### Single source of truth

Gitea at `https://git.terraphim.cloud` is the authoritative system for all task management. Do NOT use beads (`br`/`bd`), `.beads/` directories, or MCP Agent Mail for task tracking.

### Environment

```bash
export GITEA_URL="https://git.terraphim.cloud"
export GITEA_TOKEN=$(op read "op://TerraphimPlatform/gitea-test-token/credential")
```

### Task discovery and prioritization

Use `gitea-robot` for PageRank-based issue prioritization:

```bash
# Get issues ranked by dependency impact (highest PageRank first)
gitea-robot triage --owner OWNER --repo REPO

# Get unblocked issues ready to work on
gitea-robot ready --owner OWNER --repo REPO

# View dependency graph
gitea-robot graph --owner OWNER --repo REPO

# Add dependency: issue X blocks issue Y
gitea-robot add-dep --owner OWNER --repo REPO --issue X --blocks Y
```

PageRank scores reflect how many downstream issues each task unblocks. Higher score = fix first.

### Issue lifecycle (tea CLI)

```bash
tea issues list --state open                                    # Browse issues
tea issues create --title "..." --labels "priority/P1-high"     # Create
tea issues edit IDX --add-labels "status/in-progress" --add-assignees "AGENT"  # Claim
tea comment IDX "progress update"                               # Update
tea issues close IDX                                            # Complete
```

### Agent workflow

1. **Pick work**: `gitea-robot ready --owner O --repo R` -- choose highest PageRank
2. **Claim**: `tea issues edit IDX --add-labels "status/in-progress" --add-assignees "AGENT"`
3. **Branch**: `git checkout -b task/IDX-short-title`
4. **Implement**: TDD, commit with `Refs #IDX`
5. **PR**: `tea pulls create --title "Fix #IDX: title" --base main --head task/IDX-short-title`
6. **Close**: `tea issues close IDX` after merge

### Multi-agent coordination

- **Claiming**: Assign yourself to an issue before starting. Check assignees first.
- **Communication**: Use `tea comment IDX "message"` on the relevant issue.
- **File reservation**: Post reserved paths in issue comments. Check before modifying overlapping files.
- **Notifications**: Check `$GITEA_URL/api/v1/notifications?status-types=unread` for updates.

### Identifiers

- Commits: `Refs #IDX` or `Fixes #IDX`
- Branches: `task/IDX-short-title`
- Cross-repo: `owner/repo#IDX`

<!-- GITEA_PAGERANK_WORKFLOW_END -->

---

## Also update these CLAUDE.md lines

Change:
```
- Keep track of all tasks in github issues using gh tool
- commit every change and keep github issues updated with the progress using gh tool
```

To:
```
- Keep track of all tasks in Gitea issues using tea and gitea-robot CLI tools
- commit every change and keep Gitea issues updated with progress using tea CLI
```
