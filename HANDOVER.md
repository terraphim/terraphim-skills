# Handover Document - terraphim-skills

**Date:** 2026-01-14
**Branch:** feat/xero-skill
**Last Commit:** fdf7741

## Progress Summary

### Tasks Completed This Session

1. **Diagnosed terraphim Hook Not Triggering:**
   - Investigated why "Claude Code" was not being replaced with "Terraphim AI" in PR bodies
   - Root cause: `terraphim-agent` binary was not installed
   - Hook has fail-open design (pre_tool_use.sh:40) that silently exits when agent not found

2. **Installed terraphim-agent Binary:**
   - Downloaded v1.3.0 from GitHub releases for ARM64 macOS
   - Installed to `~/.cargo/bin/terraphim-agent`
   - Verified installation: `terraphim-agent --version` shows v1.3.0

3. **Built Knowledge Graph:**
   - Changed to `~/.config/terraphim` directory
   - Ran `terraphim-agent graph --role "Terraphim Engineer"`
   - Generated thesaurus for 10 concepts from KG files

4. **Verified Hook Functionality:**
   - Tested text replacement: "Claude Code" → "Terraphim AI" ✓
   - Tested full PR command with HEREDOC body ✓
   - Tested git commit message replacement ✓
   - Hook now properly intercepts all Bash commands

5. **Updated Settings:**
   - Added `WebSearch` permission to `.claude/settings.local.json`

### Current State

**What's Working:**
- terraphim-agent v1.3.0 installed and operational
- PreToolUse hook successfully replacing text in ALL Bash commands
- Knowledge graph contains 5 replacement rules:
  - `Claude Code` → `Terraphim AI`
  - `Claude Opus 4.5` → `Terraphim AI`
  - `npm install` → `bun install`
  - `npm run` → `bun run`
  - `npx` → `bunx`
- Git safety guard blocking destructive commands
- Fail-open semantics ensure commands pass through if agent unavailable

**Verified Tests:**
```bash
# Direct replacement test
cd ~/.config/terraphim && echo 'Claude Code' | terraphim-agent replace --role "Terraphim Engineer" --json
# {"result":"Terraphim AI\n","changed":false}

# Hook test - simple command
echo '{"tool_name":"Bash","tool_input":{"command":"echo \"Claude Code\""}}' | ~/.claude/hooks/pre_tool_use.sh
# {"tool_name":"Bash","tool_input":{"command":"echo \"Terraphim AI\""}}

# Hook test - git commit
echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m '\''Generated with Claude Code'\''"}}' | ~/.claude/hooks/pre_tool_use.sh
# {"tool_name":"Bash","tool_input":{"command":"git commit -m '\''Generated with Terraphim AI'\''"}}

# Hook test - PR creation with HEREDOC
cat << 'EOF' | ~/.claude/hooks/pre_tool_use.sh | jq .
{"tool_name":"Bash","tool_input":{"command":"gh pr create --title \"Test\" --body \"$(cat <<'PREOF'\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\nPREOF\n)\""}}
EOF
# Successfully replaces Claude Code → Terraphim AI in PR body
```

**What Changed:**
- `.claude/settings.local.json`: Added WebSearch permission
- `~/.cargo/bin/terraphim-agent`: Newly installed (was missing)

**What's Blocked:**
- None - hook is now fully functional

## Technical Context

```
Branch: feat/xero-skill
Recent commits:
fdf7741 feat(skill): add Xero API integration skill
5c49ad6 fix(config): add hooks to project-level settings
8231542 fix(hooks): remove trailing newline from hook output
5c50e57 feat(hooks): Add PreToolUse hooks with knowledge graph replacement for all commands
9417f4c docs: update handover and lessons learned for 2026-01-06 session

Modified files:
- .claude/settings.local.json (WebSearch permission added)

Untracked files:
- crates/ (terraphim_settings workspace)
- docs/ (best-practices documentation)
```

## Key Files

| File | Purpose | Status |
|------|---------|--------|
| `~/.cargo/bin/terraphim-agent` | Text replacement engine | v1.3.0 installed |
| `~/.claude/hooks/pre_tool_use.sh` | Guard + replacement hook | Working |
| `~/.claude/hooks/post_tool_use.sh` | Post-execution hook | Working |
| `~/.config/terraphim/docs/src/kg/` | Knowledge graph source | 5 files |
| `.claude/settings.local.json` | Project hook config | Updated |
| `~/.claude/settings.local.json` | User-level hook config | Active |

## Installation State

```
Component                           Status      Version/Location
---------------------------------------------------------------------------------------------------
terraphim-agent binary              ✓ Installed v1.3.0 at ~/.cargo/bin/terraphim-agent
Knowledge graph                     ✓ Built     10 concepts for "Terraphim Engineer" role
PreToolUse hook                     ✓ Active    ~/.claude/hooks/pre_tool_use.sh (executable)
PostToolUse hook                    ✓ Active    ~/.claude/hooks/post_tool_use.sh (executable)
User-level hook config              ✓ Active    ~/.claude/settings.local.json
Project-level hook config           ✓ Active    .claude/settings.local.json
Knowledge graph files               ✓ Present   5 files in ~/.config/terraphim/docs/src/kg/
```

## Commits Made This Session

None - troubleshooting session only. Changes to commit:
- `.claude/settings.local.json` (WebSearch permission)

## Next Steps

### Priority 1: Test Hook in Production Use
- Create a test PR with the hook active
- Verify "Claude Code" gets replaced with "Terraphim AI" in actual PR bodies
- Monitor console output to see if hook transformation is visible

### Priority 2: Document Troubleshooting Process
- Add troubleshooting section to README.md covering:
  - How to verify terraphim-agent is installed
  - How to test hooks manually
  - Common failure modes (missing binary, missing KG)

### Priority 3: Consider Improving Hook Error Reporting
**Current Issue:** Fail-open design silently allows commands when agent not found
**Improvement Ideas:**
- Add debug mode that logs when agent is missing
- Create a health check command: `terraphim-agent health`
- Document expected vs actual behavior when components missing

### Priority 4: Complete Xero Skill Work
- Review changes on feat/xero-skill branch
- Address any outstanding issues from fdf7741 commit
- Consider merging or closing branch

### Priority 5: Handle Untracked Files
- Review `crates/` directory - likely terraphim_settings workspace
- Review `docs/best-practices-skills-hooks-claude-code-codex-opencode.md`
- Decide whether to commit, gitignore, or remove

## Installation Commands (Verified Working)

```bash
# Install terraphim-agent binary
mkdir -p ~/.cargo/bin
gh release download --repo terraphim/terraphim-ai \
  --pattern "terraphim-agent-aarch64-apple-darwin" --dir /tmp
chmod +x /tmp/terraphim-agent-aarch64-apple-darwin
mv /tmp/terraphim-agent-aarch64-apple-darwin ~/.cargo/bin/terraphim-agent

# Verify installation
~/.cargo/bin/terraphim-agent --version

# Build knowledge graph (REQUIRED after installation)
cd ~/.config/terraphim
~/.cargo/bin/terraphim-agent graph --role "Terraphim Engineer"

# Test replacement
echo "Claude Code" | ~/.cargo/bin/terraphim-agent replace --role "Terraphim Engineer"
# Should output: Terraphim AI

# Test hook
echo '{"tool_name":"Bash","tool_input":{"command":"echo Claude Code"}}' | ~/.claude/hooks/pre_tool_use.sh
# Should output JSON with "echo Terraphim AI"
```

## Debugging Commands

```bash
# Check if terraphim-agent exists
which terraphim-agent
[ -x "$HOME/.cargo/bin/terraphim-agent" ] && echo "Found" || echo "Missing"

# Check hook script permissions
ls -la ~/.claude/hooks/

# Test hook components separately
cd ~/.config/terraphim

# 1. Test guard (blocks destructive commands)
echo "git reset --hard" | ~/.cargo/bin/terraphim-agent guard --json

# 2. Test replace (text substitution)
echo "Claude Code is great" | ~/.cargo/bin/terraphim-agent replace --role "Terraphim Engineer" --json

# 3. Test full hook (complete integration)
echo '{"tool_name":"Bash","tool_input":{"command":"echo Claude Code"}}' | ~/.claude/hooks/pre_tool_use.sh 2>/dev/null

# Check knowledge graph files
ls -la ~/.config/terraphim/docs/src/kg/

# Rebuild knowledge graph
cd ~/.config/terraphim
~/.cargo/bin/terraphim-agent graph --role "Terraphim Engineer"
```

## Related Repositories

| Repository | Purpose | Status |
|------------|---------|--------|
| [terraphim/terraphim-skills](https://github.com/terraphim/terraphim-skills) | Claude Code plugin marketplace | This repo |
| [terraphim/terraphim-ai](https://github.com/terraphim/terraphim-ai) | terraphim-agent source + releases | v1.3.0 |

## Known Issues

### terraphim-agent Warnings
When running `terraphim-agent replace`, you may see multiple WARN messages about `embedded_config.json` and `thesaurus_*.json` not found in memory. These warnings can be safely ignored - they're logged to stderr and don't affect functionality. The hook script uses `2>/dev/null` to suppress them in production.

### Hook Fail-Open Design
The PreToolUse hook is designed to fail-open (line 40 in pre_tool_use.sh), meaning:
- If terraphim-agent is not installed, commands pass through unchanged
- No error message is shown to the user
- This makes troubleshooting harder since there's no indication the hook isn't working

**Recommended:** Periodically verify terraphim-agent is installed and working:
```bash
~/.cargo/bin/terraphim-agent --version
```
