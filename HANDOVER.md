# Handover Document - terraphim-skills

**Date:** 2026-01-03
**Branch:** main
**Last Commit:** d40db4a

## Progress Summary

### Tasks Completed This Session
1. **Repository Renamed:** `claude-skills` -> `terraphim-skills`
   - GitHub repository renamed via `gh repo rename`
   - All references updated in plugin.json, marketplace.json, README.md
   - Git remote updated to new URL

2. **Marketplace Configuration Fixed:**
   - marketplace.json `name` field updated to `terraphim-skills`
   - Old marketplaces removed (`terraphim-ai`, `terraphim-claude-skills`)
   - Fresh installation tested and working

3. **Terraphim Hooks Installed:**
   - terraphim-agent v1.3.0 downloaded from GitHub releases
   - Installed to `~/.cargo/bin/terraphim-agent`
   - PreToolUse hook script created at `~/.claude/hooks/pre_tool_use.sh`
   - Git prepare-commit-msg hook installed in this repo
   - Knowledge graph files created at `~/.config/terraphim/docs/src/kg/`

4. **Documentation Updated:**
   - `skills/terraphim-hooks/SKILL.md` updated with:
     - Quick start using released binary
     - Correct knowledge graph format (use spaces, not underscores)
     - Complete hook setup instructions

5. **Bug Report Filed:**
   - Issue #394 created for terraphim-agent case preservation and over-replacement bugs

### Current State

**What's Working:**
- Plugin installation: `claude plugin install terraphim-engineering-skills@terraphim-skills`
- 27 skills available and properly formatted
- PreToolUse hook transforms npm/yarn/pnpm commands to bun
- Git hook transforms commit messages (with known issues)

**What's Blocked/Has Issues:**
- terraphim-agent outputs lowercase replacements (bug #394)
- terraphim-agent over-replaces text in URLs (bug #394)
- Git hook temporarily disabled in this session to avoid mangled commits

## Technical Context

```
Branch: main
Recent commits:
d40db4a docs: update terraphim-hooks skill with released binary installation
dfc4ed4 chore: rename repository to terraphim-skills
bfdcf24 feat: add git-safety-guard skill
02e39cd feat: add disciplined development agents for V-model workflow
44d4b3e fix: update marketplace name and URLs for claude-skills repo rename

Status: clean (untracked: crates/, opencode-skills/)
```

## Key Files

| File | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Plugin manifest (name: terraphim-engineering-skills) |
| `.claude-plugin/marketplace.json` | Marketplace config (name: terraphim-skills) |
| `skills/` | 27 skill directories with SKILL.md files |
| `~/.claude/hooks/pre_tool_use.sh` | PreToolUse hook for npm->bun replacement |
| `~/.config/terraphim/docs/src/kg/` | Knowledge graph files for replacements |
| `.git/hooks/prepare-commit-msg` | Git hook for commit message transformation |

## Installed Components

```
~/.cargo/bin/terraphim-agent          # v1.3.0
~/.claude/hooks/pre_tool_use.sh       # PreToolUse hook script
~/.claude/settings.local.json         # Hook configuration
~/.config/terraphim/docs/src/kg/      # Knowledge graph files:
  - bun.md                            # npm/yarn/pnpm -> bun
  - bun install.md                    # npm install -> bun install
  - bun_run.md                        # npm run -> bun
  - bunx.md                           # npx -> bunx
  - Terraphim AI.md                   # Claude Code -> Terraphim AI (has issues)
```

## Next Steps

### Priority 1: Fix terraphim-agent Bugs
Wait for or contribute fix to issue #394:
- Case preservation from markdown headings
- Word boundary matching to avoid URL replacement

### Priority 2: Re-enable Git Hook
Once bug #394 is fixed:
```bash
# The hook is already installed but produces lowercase output
# Test after terraphim-agent update:
cd ~/.config/terraphim && echo "Claude Code" | terraphim-agent replace
# Should output: Terraphim AI (not: terraphim ai)
```

### Priority 3: Consider Global Hook Installation
For user-wide hooks, add to `~/.claude/settings.local.json`:
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/pre_tool_use.sh"
      }]
    }]
  }
}
```

## Installation Commands (Working)

```bash
# Add marketplace
claude plugin marketplace add terraphim/terraphim-skills

# Install plugin
claude plugin install terraphim-engineering-skills@terraphim-skills

# Verify
claude plugin validate .
```

## Related Issues

- [#394](https://github.com/terraphim/terraphim-ai/issues/394) - terraphim-agent case preservation and over-replacement
