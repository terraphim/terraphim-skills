# Handover Document - terraphim-skills

**Date:** 2026-01-06
**Branch:** main
**Last Commit:** adb87b1

## Progress Summary

### Tasks Completed This Session

1. **Claude Code Hooks Documentation:**
   - Documented all 10 Claude Code hook types (PreToolUse, PostToolUse, Stop, SubagentStop, etc.)
   - Created comprehensive hook configuration examples

2. **terraphim-agent Installed from GitHub Releases:**
   - Installed v1.4.7 from GitHub releases (crates.io v1.0.0 is outdated)
   - Binary at `~/.cargo/bin/terraphim-agent`
   - Supports `hook`, `guard`, and `replace` commands

3. **User-Level Hooks Configured:**
   - Updated `~/.claude/settings.local.json` with:
     - PreToolUse hook for git-safety-guard + knowledge graph replacement
     - PostToolUse hook for post-execution processing
     - Permissions for 21 terraphim-engineering-skills

4. **Hook Script Enhanced:**
   - `~/.claude/hooks/pre_tool_use.sh` now includes:
     - Git Safety Guard (blocks `git reset --hard`, `rm -rf`, etc.)
     - Knowledge graph replacement (npm -> bun, Claude Code -> Terraphim AI)
     - Fail-open semantics (passes through if agent unavailable)

5. **README Updates:**
   - Added "User-Level Activation (Complete Setup)" section with 6 steps
   - Added terraphim-agent installation instructions from GitHub releases
   - Documented all hook scripts and knowledge graph setup

6. **terraphim-ai README Updated:**
   - Added "Claude Code Integration" quick setup guide
   - Documented guard, replace, and hook commands
   - Added verification commands

### Current State

**What's Working:**
- Plugin installation: `claude plugin install terraphim-engineering-skills@terraphim-skills`
- 27+ skills available and properly formatted
- PreToolUse hook blocks destructive git commands
- PreToolUse hook transforms npm/yarn/pnpm -> bun
- PreToolUse hook transforms "Claude Code" -> "Terraphim AI" in commits
- All hooks use fail-open semantics

**Verified Tests:**
```bash
# Guard blocks destructive commands
echo "git reset --hard" | terraphim-agent guard --json
# {"decision":"block","reason":"git reset --hard destroys uncommitted changes..."}

# Replacement works
cd ~/.config/terraphim && echo "Claude Code is great" | terraphim-agent replace
# Terraphim AI is great

# Hook script works
echo '{"tool_name":"Bash","tool_input":{"command":"git checkout -- file.txt"}}' | ~/.claude/hooks/pre_tool_use.sh
# BLOCKED message
```

## Technical Context

```
Branch: main
Recent commits:
adb87b1 docs: add comprehensive user-level activation guide
00de603 docs: add terraphim-agent installation and user-level hooks config
44594d2 fix(hooks): use space in filename for bun install replacement
88edf57 docs: add cross-links to all skill repositories
f8761e7 docs: update handover and lessons learned for 2026-01-03 session

Status: clean (untracked: crates/, opencode-skills/)
```

## Key Files

| File | Purpose |
|------|---------|
| `README.md` | Complete user-level activation guide (6 steps) |
| `skills/terraphim-hooks/SKILL.md` | Knowledge graph hooks documentation |
| `skills/git-safety-guard/SKILL.md` | Destructive command blocking documentation |
| `~/.claude/settings.local.json` | User-level hooks + permissions config |
| `~/.claude/hooks/pre_tool_use.sh` | Combined guard + replacement hook |
| `~/.claude/hooks/post_tool_use.sh` | Post-execution hook |
| `~/.config/terraphim/docs/src/kg/` | Knowledge graph replacement rules |

## Installed Components

```
~/.cargo/bin/terraphim-agent          # v1.4.7 (from GitHub releases)
~/.claude/hooks/pre_tool_use.sh       # Guard + replacement hook
~/.claude/hooks/post_tool_use.sh      # Post-execution hook
~/.claude/settings.local.json         # Hooks + 21 skill permissions
~/.config/terraphim/docs/src/kg/      # Knowledge graph files:
  - bun.md                            # npm/yarn/pnpm -> bun
  - bun install.md                    # npm install -> bun install
  - bun run.md                        # npm run -> bun run
  - bunx.md                           # npx -> bunx
  - Terraphim AI.md                   # Claude Code -> Terraphim AI
```

## Commits Made This Session

| Repo | Commit | Description |
|------|--------|-------------|
| terraphim-skills | 00de603 | docs: add terraphim-agent installation and user-level hooks config |
| terraphim-skills | adb87b1 | docs: add comprehensive user-level activation guide |
| terraphim-ai | 2ecddfea | docs: add Claude Code integration quick setup guide |

## Next Steps

### Priority 1: Monitor Hook Effectiveness
- Verify hooks continue working across Claude Code updates
- Check if replacement happens consistently in git commits

### Priority 2: Consider Additional Knowledge Graph Rules
```bash
# Example: Add more replacements
cat > ~/.config/terraphim/docs/src/kg/cargo_test.md << 'EOF'
# cargo test
synonyms:: pytest, py.test
EOF
```

### Priority 3: Update crates.io Version
- Current crates.io version (v1.0.0) lacks hook/guard commands
- Consider publishing v1.4.7+ to crates.io

## Installation Commands (Working)

```bash
# 1. Add marketplace
claude plugin marketplace add terraphim/terraphim-skills

# 2. Install plugin
claude plugin install terraphim-engineering-skills@terraphim-skills

# 3. Install terraphim-agent
gh release download --repo terraphim/terraphim-ai \
  --pattern "terraphim-agent-aarch64-apple-darwin" --dir /tmp
chmod +x /tmp/terraphim-agent-aarch64-apple-darwin
mv /tmp/terraphim-agent-aarch64-apple-darwin ~/.cargo/bin/terraphim-agent

# 4. Configure hooks (see README for full settings.local.json)

# 5. Verify
terraphim-agent --version
echo "git reset --hard" | terraphim-agent guard --json
```

## Related Repositories

| Repository | Purpose |
|------------|---------|
| [terraphim/terraphim-skills](https://github.com/terraphim/terraphim-skills) | Claude Code plugin marketplace |
| [terraphim/terraphim-ai](https://github.com/terraphim/terraphim-ai) | terraphim-agent source + releases |
