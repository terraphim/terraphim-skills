# UBS Hook Integration

These hooks integrate Ultimate Bug Scanner (UBS) into Claude Code for real-time bug detection.

## Prerequisites

Install UBS:
```bash
curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/ultimate_bug_scanner/main/install.sh | bash
```

## Hooks

### Pre-Tool-Use Hook (`ubs_pre_tool_use.sh`)

Scans code before Write/Edit operations. Prompts for confirmation if critical issues are detected.

**Behavior**:
- Triggers on: `Write`, `Edit` tool calls
- Runs: `ubs scan <file> --severity=critical`
- If critical issues found: Asks user to confirm before proceeding

### Post-Tool-Use Hook (`ubs_post_tool_use.sh`)

Reports UBS findings after git commits.

**Behavior**:
- Triggers on: `Bash` tool calls containing `git commit`
- Runs: `ubs scan <committed-files> --severity=high,critical`
- Reports: Summary of findings as a message

## Installation

1. Copy hooks to Claude config:
```bash
cp ubs_*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/ubs_*.sh
```

2. Add to `~/.claude/settings.local.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/ubs_pre_tool_use.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/ubs_post_tool_use.sh"
          }
        ]
      }
    ]
  }
}
```

## Configuration

### Adjusting Severity

Edit the hooks to change the severity threshold:

```bash
# In ubs_pre_tool_use.sh - scan for critical only (fast)
ubs scan "$FILE_PATH" --severity=critical

# Or scan for high and critical (more thorough)
ubs scan "$FILE_PATH" --severity=high,critical
```

### Skipping Certain Files

Add exclusions in the hooks:

```bash
# Skip test files
if [[ "$FILE_PATH" == *"test"* || "$FILE_PATH" == *"spec"* ]]; then
    echo '{}'
    exit 0
fi
```

## Integration with Quality Gate

The `ubs-scanner` skill provides comprehensive UBS integration for the quality gate workflow. Use the hooks for real-time feedback during development, and the skill for formal verification.

```
Development Flow:
1. Write code → Pre-hook scans for critical issues
2. Commit → Post-hook reports findings
3. PR ready → quality-gate skill runs full UBS scan
```
