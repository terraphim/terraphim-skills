# Handover Document - terraphim-skills

**Date:** 2026-01-30
**Branch:** main
**Last Commit:** 6bcf7ff

## Progress Summary

### Tasks Completed This Session

1. **Fixed OpenCode Discipline Implementation Model Error:**
   - Root cause: `~/.config/opencode/agent/disciplined-implementation.md` had invalid `model: xai/grok-code-fast`
   - Also had `mode: subagent` which hid it from agent list
   - Fixed by removing invalid model reference and changing to `mode: primary`
   - Source file fixed: `~/private_agents_settings/opencode/agent/disciplined-implementation.md`

2. **Reinstalled Skills via skills.sh:**
   - Ran `npx skills add . -g -y` to install 31 skills globally
   - Skills installed to `~/.agents/skills/` with symlinks to 15 agent platforms

3. **Investigated skills.sh vs OpenCode Path Discrepancy:**
   - Initial assumption: skills.sh uses `skills/` (plural), OpenCode expects `skill/` (singular)
   - After investigation: OpenCode docs were updated to use `skills/` (plural)
   - skills.sh is CORRECT - no fix needed
   - Removed unnecessary fix script from repo

4. **Updated Documentation:**
   - Commit 4fc3ce1: Initial fix attempt (incorrect assumption)
   - Commit 6bcf7ff: Corrected documentation, removed fix script
   - Updated `docs/best-practices-skills-hooks-claude-code-codex-opencode.md` to use `skills/` (plural)

### Current State

**What's Working:**
- skills.sh installs 31 skills to `~/.config/opencode/skills/` (correct path)
- OpenCode starts without errors
- All discipline agents available: Disciplined-Research, Disciplined-Design, Disciplined-Implementation
- Essentialism + Karpathy guidelines present in skill content

**Verified Tests:**
```bash
# Reinstall from repo
npx skills add . -g -y
# Result: 31 skills installed to 15 agents

# OpenCode startup
opencode
# Result: No errors, agents visible via Tab cycling

# Skills path verification
ls ~/.config/opencode/skills/
# Result: 31 symlinks to ~/.agents/skills/
```

**What's NOT in Repo (Local Config Only):**
- OpenCode agents in `~/.config/opencode/agent/` - these use OpenCode-specific YAML format
- The fix to `disciplined-implementation.md` (removed invalid model) is in local config only
- Source of agents: `~/private_agents_settings/opencode/agent/`

## Technical Context

```
Branch: main
Recent commits:
  6bcf7ff fix: correct OpenCode skill path documentation
  4fc3ce1 fix: add OpenCode skill path fix script
  714a25a feat: add terraphim_settings crate and cross-platform skills documentation
  6b88b7e Merge remote: keep skills.sh README from canonical repo
  25055c4 docs: archive repository - migrate to terraphim-skills

Working tree: clean
```

## Architecture Clarification

| Component | Location | Format | Managed By |
|-----------|----------|--------|------------|
| Skills | `~/.agents/skills/` | Claude Code YAML | skills.sh |
| OpenCode Skills | `~/.config/opencode/skills/` | Symlinks | skills.sh |
| OpenCode Agents | `~/.config/opencode/agent/` | OpenCode YAML | Manual |
| Repo Agents | `agents/` | Claude Code YAML | Git |

**Key Difference:**
- **Skills** = reusable prompts (cross-platform, managed by skills.sh)
- **Agents** = platform-specific orchestration configs (OpenCode has different YAML schema)

## Next Steps

### Priority 1: OpenCode Agent Management
- [ ] Decide: Should OpenCode agents be added to repo?
- [ ] If yes: Create `opencode-agents/` directory with OpenCode-format agents
- [ ] Consider: Auto-conversion script from Claude Code format to OpenCode format

### Priority 2: Missing Discipline Phases in OpenCode
- [ ] OpenCode agents only have: research, design, implementation, orchestrator, quality-gatekeeper
- [ ] Missing: specification, verification, validation, left-side-of-v, right-side-of-v, execution-orchestrator
- [ ] Consider: Port remaining agents to OpenCode format

### Priority 3: Documentation
- [ ] Document the Skills vs Agents distinction clearly
- [ ] Add OpenCode-specific setup instructions if agents are added to repo

## Blockers

None currently. All functionality working.

## Files Changed This Session

| File | Change |
|------|--------|
| `README.md` | Removed incorrect OpenCode fix section |
| `docs/best-practices-skills-hooks-claude-code-codex-opencode.md` | Updated paths to `skills/` (plural) |
| `scripts/fix-opencode-paths.sh` | Deleted (not needed) |
| `.claude/settings.local.json` | Added session permissions |

## Local Config Changes (Not in Repo)

| File | Change |
|------|--------|
| `~/.config/opencode/agent/disciplined-implementation.md` | Removed `model: xai/grok-code-fast`, changed `mode: subagent` to `mode: primary` |
| `~/private_agents_settings/opencode/agent/disciplined-implementation.md` | Same fix applied to source |
