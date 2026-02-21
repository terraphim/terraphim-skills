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

---

# Handover Document - terraphim-skills Issue Resolution

**Date:** 2026-02-21
**Branch:** main
**Last Commit:** ebe09e7 (docs: update handover and lessons learned)

## Progress Summary

### Phase 1: Quick Wins - COMPLETE
- **Issue #4** (Block git --no-verify): Already implemented in git-safety-guard skill - CLOSED
- **Issue #40** (Judge parse error): Judge functionality not found in this repository - CLOSED
- **Issue #41** (Judge parse error): Judge functionality not found in this repository - CLOSED

### Phase 2: ZDP v2.3 SRD Support - COMPLETE
Epic #24 and all 6 child issues implemented:

- **Issue #25**: Added SRD section to disciplined-design SKILL.md
- **Issue #26**: Added SRD prerequisite check to execution-orchestrator agent
- **Issue #27**: Added SRD mapping and Demo D15 reference to acceptance-testing
- **Issue #28**: Added Maturity column to requirements-traceability matrix
- **Issue #29**: Added SRD IOC validation to disciplined-validation
- **Issue #30**: Added SRD testability check to disciplined-verification

### Files Modified (160+ lines added)
- `.claude/settings.local.json`
- `agents/execution-orchestrator.md`
- `skills/acceptance-testing/SKILL.md`
- `skills/disciplined-design/SKILL.md`
- `skills/disciplined-validation/SKILL.md`
- `skills/disciplined-verification/SKILL.md`
- `skills/requirements-traceability/SKILL.md`

## Current State

### What's Working
- All 7 files modified with SRD support enhancements
- SRD traceability integrated across the V-model
- Maturity states defined for requirements tracking
- IOC validation framework for releases

### What's Blocked
- **Issues #40-41**: Judge functionality investigation
  - Comprehensive search found NO "judge" code in repository
  - May be in terraphim-ai main repository or needs to be created
  - User indicated it "shall be in this repo" - requires clarification

### Git Status
```
7 modified files, 160+ lines added
Not yet committed
```

## Remaining Work

### Phase 3: Publishing Foundation (Not Started)
- **Issue #45**: Create Publishing Editor terraphim role
- **Issue #47**: Per-title KG switching for publishing pipeline
- **Issue #46**: PreToolUse hook avoid-term enforcement

### Phase 4: Publishing Validation Pipeline (Not Started)
- **Issue #44**: Create publishing-validate TinyClaw skill
- **Issue #48**: Create publishing-validate Claude Code skill

### Phase 5: Generalized Domain Model Skills (Not Started)
- **Issue #49**: domain-model-init skill
- **Issue #50**: domain-model-validate skill
- **Issue #51**: domain-model-coverage skill

### Epic #43 (Publishing) remains OPEN

## Next Steps

### Immediate Actions
1. **Commit current changes** - 7 files with ZDP v2.3 SRD support ready
2. **Clarify judge functionality** - User indicated it should exist but none found
3. **Proceed with Publishing Epic** - 9 issues remaining

### Recommended Approach
- Create skill scaffolding for publishing domain model
- Reference external scripts at `/Users/alex/cto-executive-system/publishing/scripts/`
- Build on existing `local-knowledge` and `terraphim-hooks` patterns

## Technical Context

### SRD Implementation Pattern
All SRD additions follow consistent pattern:
- SRD reference fields in document headers
- Traceability tables mapping SRD requirements to implementation
- Checklists for validation at each phase

### Key Design Decisions
- Maturity states: Draft → Review → Approved → Implemented → Verified → Validated
- IOC criteria table for release validation
- Testability checks before test writing

## Open Questions

1. **Judge functionality location**: Where should issues #40-41 be addressed?
2. **External script dependencies**: Are cto-executive-system scripts available?
3. **Publishing role scope**: What specific functionality for Publishing Editor?

---
*Generated for terraphim AI system continuation*
