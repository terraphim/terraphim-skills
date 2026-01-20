#!/usr/bin/env bash
# UBS Pre-Tool-Use Hook
# Scans code before Write/Edit operations to catch critical bugs early
#
# Install: Copy to ~/.claude/hooks/ and add to settings.local.json:
# {
#   "hooks": {
#     "PreToolUse": [
#       { "matcher": "Write|Edit", "hooks": [{"type": "command", "command": "~/.claude/hooks/ubs_pre_tool_use.sh"}] }
#     ]
#   }
# }

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only check Write and Edit operations
if [[ "$TOOL" != "Write" && "$TOOL" != "Edit" ]]; then
    echo '{}'
    exit 0
fi

# Get file path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
    echo '{}'
    exit 0
fi

# Check if UBS is installed
if ! command -v ubs &> /dev/null; then
    echo '{}'
    exit 0
fi

# Run quick UBS scan on the file (critical issues only)
UBS_OUTPUT=$(ubs scan "$FILE_PATH" --severity=critical --format=json 2>/dev/null || true)

# Check for critical findings
CRITICAL_COUNT=$(echo "$UBS_OUTPUT" | jq -r '.findings | map(select(.severity == "critical")) | length // 0' 2>/dev/null || echo "0")

if [[ "$CRITICAL_COUNT" -gt 0 ]]; then
    FINDING=$(echo "$UBS_OUTPUT" | jq -r '.findings[0].message // "Critical issue detected"' 2>/dev/null || echo "Critical issue detected")

    cat <<EOF
{
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": "UBS detected critical issue: $FINDING. Review before proceeding."
    }
}
EOF
    exit 0
fi

echo '{}'
