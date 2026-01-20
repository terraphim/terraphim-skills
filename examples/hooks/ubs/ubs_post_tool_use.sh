#!/usr/bin/env bash
# UBS Post-Tool-Use Hook
# Scans code after git commit to report findings
#
# Install: Copy to ~/.claude/hooks/ and add to settings.local.json:
# {
#   "hooks": {
#     "PostToolUse": [
#       { "matcher": "Bash", "hooks": [{"type": "command", "command": "~/.claude/hooks/ubs_post_tool_use.sh"}] }
#     ]
#   }
# }

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only check Bash operations
if [[ "$TOOL" != "Bash" ]]; then
    echo '{}'
    exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only run after git commit
if [[ "$COMMAND" != *"git commit"* ]]; then
    echo '{}'
    exit 0
fi

# Check if UBS is installed
if ! command -v ubs &> /dev/null; then
    echo '{}'
    exit 0
fi

# Get files from last commit
CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | head -20)

if [[ -z "$CHANGED_FILES" ]]; then
    echo '{}'
    exit 0
fi

# Run UBS scan on committed files
UBS_OUTPUT=$(echo "$CHANGED_FILES" | xargs ubs scan --severity=high,critical --format=summary 2>/dev/null || true)

if [[ -n "$UBS_OUTPUT" && "$UBS_OUTPUT" != *"No issues found"* ]]; then
    # Escape for JSON
    ESCAPED_OUTPUT=$(echo "$UBS_OUTPUT" | head -5 | tr '\n' ' ' | sed 's/"/\\"/g')

    cat <<EOF
{
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "message": "UBS scan of committed files: $ESCAPED_OUTPUT"
    }
}
EOF
    exit 0
fi

echo '{}'
