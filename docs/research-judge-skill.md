# Research Document: Multi-Model Judge Skill

**Status**: Approved
**Date**: 2026-02-17
**Issue**: #17 (Epic), #18 (Phase 1)

## Executive Summary

The judge skill evaluates agent task outputs using free LLM models via opencode with a three-tier consensus protocol. No judge infrastructure currently exists in the repository -- the entire system must be built from scratch. The existing KLS quality evaluation framework (Semantic/Pragmatic/Syntactic dimensions) provides the rubric foundation.

## Essential Questions Check

| Question | Answer | Evidence |
|----------|--------|----------|
| Energizing? | Yes | Automated quality assurance at task boundary reduces manual review burden |
| Leverages strengths? | Yes | Builds on existing KLS framework and V-model quality gates |
| Meets real need? | Yes | No automated post-task quality check exists; pre-commit hooks catch syntax only |

**Proceed**: Yes (3/3)

## Problem Statement

### Description
Agent task outputs (documentation, code, specifications) have no automated quality evaluation at the task completion boundary. Quality gates exist within the disciplined development pipeline but require manual invocation. A judge skill would provide automatic evaluation using multiple free LLM models with consensus-based verdicts.

### Success Criteria
- Judge skill files load correctly when referenced
- Quick judge prompt produces valid verdict JSON in < 30s
- Deep judge prompt produces valid verdict JSON with improvement suggestions in < 60s
- Rubric reuses existing KLS dimensions (Semantic, Pragmatic, Syntactic)
- Verdict schema is backward-compatible with future pre-push hook format

## Current State Analysis

### What Exists
- **KLS 6-dimension framework** in `skills/disciplined-quality-evaluation/SKILL.md` -- provides Semantic, Pragmatic, Syntactic (and 3 other) dimensions with 1-5 scoring
- **Quality gate skill** in `skills/quality-gate/SKILL.md` -- orchestrates verification passes with Pass/Pass-with-follow-ups/Fail verdicts
- **Hook infrastructure** in `.claude/settings.local.json` -- PreToolUse and PostToolUse hooks configured
- **opencode source** at `/Users/alex/projects/terraphim/opencode` -- not installed globally but available

### What Does NOT Exist
- `automation/judge/` directory -- referenced in issues but not created
- `verdict-schema.json` -- referenced but not created
- `pre-push-judge.sh` -- referenced as "existing" but does not exist
- `terraphim-agent` binary -- only documentation references exist
- `run-judge.sh` -- referenced in issues but not created
- Any judge skill files

### Implication
All issues (#18-#23) describe greenfield work. References to "existing pre-push hook" in the issue descriptions are aspirational, not actual.

## Constraints

### Technical Constraints
- opencode not installed globally; must be installable or assumed present
- Free LLM providers (Zen, Copilot) have variable latency and availability
- 45s timeout per opencode call; GLM 5 excluded (33% timeout rate per issue #20)

### Vital Few (Max 3)

| Constraint | Why Vital | Evidence |
|------------|-----------|---------|
| Verdict must be valid JSON | Enables automation, logging, and future hook integration | Issue #18 acceptance criteria |
| Rubric must match KLS dimensions | Consistency with existing quality framework | Issue #17 architecture |
| Max 3 rounds before human fallback | Prevents infinite loops, bounds cost | Issue #20 constraints |

### Eliminated from Scope (Issue #18 only)

| Eliminated | Why |
|------------|-----|
| Runner script (run-judge.sh) | Issue #20, not #18 |
| opencode config | Issue #19, not #18 |
| Disagreement handling | Issue #21, not #18 |
| terraphim-agent integration | Issue #22, not #18 |
| Pre-push hook | Future work, not referenced as dependency |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| opencode not available on target system | Medium | High | Design skill files to be provider-agnostic; opencode is the runner, not the skill |
| Free LLM models produce inconsistent JSON | Medium | Medium | Strict prompt templates with JSON-only output instructions |
| KLS dimensions too abstract for quick judge | Low | Medium | Simplify to 3 core dimensions (Semantic/Pragmatic/Syntactic) with concrete criteria |

## Assumptions

| Assumption | Basis | Risk if Wrong |
|------------|-------|---------------|
| opencode will be installed before judge is used | Issue #19 handles setup | Judge runner fails |
| Zen and Copilot providers produce valid JSON when prompted | Common LLM capability | Need fallback parsing |
| 3 KLS dimensions sufficient for task-level evaluation | Issue #17 specifies this subset | May miss quality issues |

## Recommendations

Proceed with creating 3 files for Issue #18:
1. `skills/judge/SKILL.md` -- Judge skill definition (as a proper skill with SKILL.md format)
2. `skills/judge/references/prompt-quick.md` -- Quick judge prompt template
3. `skills/judge/references/prompt-deep.md` -- Deep judge prompt template

Plus the verdict schema:
4. `automation/judge/verdict-schema.json` -- JSON schema for verdict output

Use the skill-creator tooling for the judge skill. Place prompt templates as reference files within the skill (not as standalone skills).
