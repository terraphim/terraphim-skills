# Multi-Agent Coordination via Gitea

Replaces MCP Agent Mail's file reservations, messaging, and identity system with Gitea-native features.

## Identity

Agents authenticate with `GITEA_TOKEN`. No separate registration needed. The token identifies the agent via the Gitea user account.

## Claiming Work (Replaces Agent Mail `register_agent` + `macro_start_session`)

```bash
# 1. Discover ready work
gitea-robot ready --owner OWNER --repo REPO

# 2. Check issue is not already assigned
tea issues IDX  # verify assignees is empty

# 3. Claim it
tea issues edit IDX --add-labels "status/in-progress" --add-assignees "AGENT_NAME"

# 4. Announce start
tea comment IDX "Starting work on this issue. Working on branch task/IDX-short-title."
```

## File Reservation (Replaces Agent Mail `file_reservation_paths`)

Gitea has no native file-reservation mechanism. Use these conventions:

### Convention: Branch Isolation

Each agent works on a separate branch for their assigned issue. The branch name (`task/IDX-*`) implicitly reserves files related to that issue. Merge conflicts are detected at PR time.

### Convention: Comment-Based Path Reservation

For overlapping work, agents post a comment listing reserved paths:

```bash
tea comment IDX "RESERVED PATHS: src/auth/**, models/user.go
Agent: my-agent-name
Duration: until PR merge"
```

Other agents check issue comments before modifying the same paths. If conflict detected, coordinate via comments.

### Convention: Assignee as Exclusive Lock

Only one agent is assigned to an issue at a time. Check before claiming:

```bash
tea issues list --assignee AGENT_NAME --state open  # my current work
tea issues IDX  # check if already assigned
```

## Messaging (Replaces Agent Mail `send_message` / `fetch_inbox`)

### Send Message

```bash
tea comment IDX "@target-agent: your message here"
```

### Check Inbox

```bash
# List issues assigned to you (your active work)
tea issues list --assignee AGENT_NAME --state open

# Check for new comments on your issues via API
curl -s -H "Authorization: token $GITEA_TOKEN" \
  "$GITEA_URL/api/v1/repos/OWNER/REPO/issues/IDX/comments" | jq '.[-3:]'
```

### Notifications

```bash
# Unread notifications
curl -s -H "Authorization: token $GITEA_TOKEN" \
  "$GITEA_URL/api/v1/notifications?status-types=unread" | jq '.[].subject.title'
```

## Coordination Patterns

### Handoff Pattern

Agent A completes prerequisite, unblocks Agent B:

```bash
# Agent A: complete and notify
tea issues close IDX_A
tea comment IDX_B "Prerequisite #IDX_A completed. This issue is now unblocked."
```

### Blocking Pattern

Agent discovers a blocker:

```bash
# Add dependency
gitea-robot add-dep --owner O --repo R --issue IDX --blocks BLOCKED_IDX

# Label and comment
tea issues edit IDX --add-labels "status/blocked"
tea comment IDX "Blocked by #BLOCKER_IDX. Cannot proceed until resolved."
```

### Review Request

```bash
tea comment IDX "@reviewer: PR ready for review. See tea pulls list --state open"
```

## Cross-Repo Coordination

For multi-repo projects under the same Gitea organization:

- Reference issues across repos: `terraphim/other-repo#42`
- Create a coordination repo with meta-issues linking component issues
- Use consistent labels across all repos (run `gitea-setup-labels.sh` on each)
