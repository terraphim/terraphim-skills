#!/bin/bash
# Terraphim PreToolUse hook - combines git-safety-guard and knowledge graph replacement
#
# Features:
# 1. Blocks destructive git/filesystem commands (git reset --hard, rm -rf, etc.)
# 2. Replaces text in ALL bash commands using terraphim knowledge graph
#    - git commit messages: "Claude Code" -> "Terraphim AI"
#    - gh pr create: replaces text in PR body
#    - npm/yarn/pnpm -> bun (if configured in knowledge graph)
#
# Installation:
#   1. Copy to ~/.claude/hooks/pre_tool_use.sh
#   2. chmod +x ~/.claude/hooks/pre_tool_use.sh
#   3. Add hook config to ~/.claude/settings.local.json (see README)
#   4. Install terraphim-agent from GitHub releases
#   5. Set up knowledge graph in ~/.config/terraphim/docs/src/kg/

set -euo pipefail

# Read input from stdin
INPUT=$(cat)

# Extract tool name and command
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only process Bash commands
[ "$TOOL_NAME" != "Bash" ] && exit 0
[ -z "$COMMAND" ] && exit 0

# Find terraphim-agent
AGENT=""
if command -v terraphim-agent >/dev/null 2>&1; then
    AGENT="terraphim-agent"
elif [ -x "$HOME/.cargo/bin/terraphim-agent" ]; then
    AGENT="$HOME/.cargo/bin/terraphim-agent"
fi

# Fail-open if agent not found
[ -z "$AGENT" ] && exit 0

# Step 1: Git Safety Guard - block destructive commands
GUARD_RESULT=$($AGENT guard --json <<< "$COMMAND" 2>/dev/null || echo '{"decision":"allow"}')

if echo "$GUARD_RESULT" | jq -e '.decision == "block"' >/dev/null 2>&1; then
    REASON=$(echo "$GUARD_RESULT" | jq -r '.reason // "Blocked by git-safety-guard"')
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "BLOCKED: $REASON"
  }
}
EOF
    exit 0
fi

# Change to terraphim config directory for KG access
cd ~/.config/terraphim 2>/dev/null || exit 0

# Step 2: Knowledge graph text replacement for ALL commands
# Build knowledge graph (needed for replacement)
$AGENT graph --role "Terraphim Engineer" >/dev/null 2>&1 || true

# Replace text in the command using terraphim with JSON output
# Use printf to avoid adding trailing newlines
REPLACE_RESULT=$(printf '%s' "$COMMAND" | $AGENT replace --role "Terraphim Engineer" --json 2>/dev/null)

# Check if replacement happened
if [ -n "$REPLACE_RESULT" ]; then
    CHANGED=$(echo "$REPLACE_RESULT" | jq -r '.changed // false')
    if [ "$CHANGED" = "true" ]; then
        NEW_COMMAND=$(echo "$REPLACE_RESULT" | jq -r '.result')
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "updatedInput": {
      "command": $(echo "$REPLACE_RESULT" | jq '.result')
    }
  }
}
EOF
        exit 0
    fi
fi

# Step 3: Fallback to terraphim-agent hook handler
$AGENT hook --hook-type pre-tool-use --json <<< "$INPUT" 2>/dev/null
