#!/bin/bash
# Terraphim PostToolUse hook - processes tool results
#
# Installation:
#   1. Copy to ~/.claude/hooks/post_tool_use.sh
#   2. chmod +x ~/.claude/hooks/post_tool_use.sh
#   3. Add hook config to ~/.claude/settings.local.json (see README)

INPUT=$(cat)

# Find terraphim-agent
AGENT=""
if command -v terraphim-agent >/dev/null 2>&1; then
    AGENT="terraphim-agent"
elif [ -x "$HOME/.cargo/bin/terraphim-agent" ]; then
    AGENT="$HOME/.cargo/bin/terraphim-agent"
fi

# Fail-open if agent not found
[ -z "$AGENT" ] && exit 0

# Process tool results
$AGENT hook --hook-type post-tool-use --json <<< "$INPUT" 2>/dev/null || exit 0
