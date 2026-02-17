# Research Document: Judge v2 -- Terraphim-Native Implementation

**Status**: Draft
**Date**: 2026-02-17
**Issue**: #17 (Epic), #23 (Validation)
**Supersedes**: docs/research-judge-skill.md (v1, bash+opencode-only approach)

## Executive Summary

The v1 judge runner (run-judge.sh) fails in practice: opencode's JSON event stream parsing is fragile, shell escaping breaks with large file content, and all term/rubric logic is hardcoded in bash. This research evaluates redesigning the judge to use terraphim-agent and terraphim-cli for term normalization, validation, and structured output parsing -- replacing brittle bash string manipulation with the knowledge graph automata engine.

## Essential Questions Check

| Question | Answer | Evidence |
|----------|--------|----------|
| Energizing? | Yes | v1 runner failed during validation; terraphim-native approach eliminates the class of problems |
| Leverages strengths? | Yes | Aho-Corasick matching, thesaurus normalization, and hook integration are terraphim's core capabilities |
| Meets real need? | Yes | Issue #23 validation exposed shell escaping and JSON parsing failures in pure-bash approach |

**Proceed**: Yes (3/3)

## Problem Statement

### Description

The v1 judge runner (automation/judge/run-judge.sh) has three failure modes discovered during Issue #23 validation:

1. **JSON extraction fragility**: opencode outputs `{"type":"text","part":{"text":"..."}}` event streams. Extracting the verdict JSON requires Python parsing of concatenated text fragments, which fails when the model splits JSON across multiple events or includes markdown fencing.

2. **Shell escaping with large content**: File contents passed as shell arguments to `opencode run` break when they contain backticks, dollar signs, single quotes, or other shell metacharacters. The `--file` flag helps but doesn't solve prompt template variable substitution.

3. **Hardcoded rubric logic**: All term definitions (semantic, pragmatic, syntactic), scoring thresholds, and verdict rules are embedded in bash heredocs. No normalization, no synonym matching, no checklist validation.

### Impact

The judge cannot run end-to-end. Issues #18-#22 delivered infrastructure (skill definition, configs, scripts, hooks) but Issue #23 validation cannot pass.

### Success Criteria

- Judge produces valid verdict JSON from real file evaluation
- Term normalization maps quality synonyms to canonical rubric dimensions
- Checklist validation uses terraphim-agent's `validate --checklist` command
- opencode prompt delivery uses file-based input (not shell argument injection)
- End-to-end test: run judge on a skill's SKILL.md and get accept/improve/reject

## Current State Analysis

### v1 Architecture (broken)

```
run-judge.sh
  |-- builds prompt as shell string (BREAKS with special chars)
  |-- calls opencode run --format json (returns event stream)
  |-- Python inline: parses JSON events, concatenates text, extracts verdict
  |-- Python inline: validates verdict JSON structure
  |-- Python inline: logs to verdicts.jsonl
  |-- on disagreement: calls handle-disagreement.sh
```

### What Terraphim Provides

| Component | terraphim-agent command | Purpose in judge |
|-----------|------------------------|------------------|
| Term normalization | `replace --mode synonym --json` | Map "accuracy", "correctness", "factual" to `semantic` |
| Term detection | `find` / `extract` | Find rubric-relevant terms in task output |
| Checklist validation | `validate --checklist` | Verify output covers required quality dimensions |
| Guard patterns | `guard` | Block judge on security-sensitive content |
| Hook integration | `hook --hook-type post-tool-use` | Trigger judge automatically on task completion |
| Fuzzy matching | `suggest --fuzzy` | Match near-miss quality terms |
| JSON output | `--robot --format json` | Structured output for all commands |

### terraphim-cli for Scripting

terraphim-cli provides the same core capabilities with non-interactive JSON output:

```bash
# Find quality terms in output
terraphim-cli find "The implementation is correct and well-structured" --role judge

# Replace with normalized terms
terraphim-cli replace "The code has good accuracy and is actionable" --mode synonym --role judge

# Show thesaurus terms for judge role
terraphim-cli thesaurus --role judge --limit 100
```

### Build Status

Neither terraphim-agent nor terraphim-cli is currently installed:
- Source at `/Users/alex/projects/terraphim/terraphim-ai/`
- Workspace version: 1.8.0
- Build: `cargo build --release -p terraphim_agent -p terraphim_cli`
- No binaries in PATH or ~/.cargo/bin

## Constraints

### Technical Constraints

| Constraint | Source | Impact |
|------------|--------|--------|
| terraphim-agent/cli not yet installed | Build required | Must build from source before testing |
| KG files are markdown with `synonyms::` format | ~/.config/terraphim/kg/*.md | Judge thesaurus must follow this format |
| opencode still needed for LLM calls | No LLM in terraphim-agent | terraphim handles parsing/normalization, opencode handles model invocation |
| Roles define KG scope | terraphim config | Need a "judge" role pointing to judge KG files |

### Vital Few (Max 3)

| Constraint | Why Vital | Evidence |
|------------|-----------|---------|
| File-based prompt delivery | Eliminates shell escaping failures | v1 validation failure root cause |
| KG-based term normalization | Makes rubric extensible without code changes | Current approach hardcodes all terms in bash |
| JSON output from terraphim-cli | Replaces brittle inline Python parsing | v1 uses 6 separate inline Python scripts |

### Eliminated from Scope

| Eliminated | Why |
|------------|-----|
| Server mode for terraphim-agent | Offline mode is sufficient; adds complexity |
| TUI/REPL integration | Judge is automated, not interactive |
| Learning capture integration | Future enhancement, not needed for core judge |
| Guard pattern integration | Already works via existing hooks; judge doesn't need its own guard |
| New LLM providers | opencode models work; problem was parsing, not models |

## Dependencies

### Internal Dependencies

| Dependency | Impact | Risk |
|------------|--------|------|
| terraphim-ai source | Must build to get binaries | Medium -- Rust build may have dependency issues |
| KG file format | Judge thesaurus must conform | Low -- format is simple markdown |
| opencode | Still needed for LLM model invocation | Low -- already working for short prompts |
| Existing judge skill files | SKILL.md and prompt templates remain valid | Low -- no changes needed |

### External Dependencies

| Dependency | Version | Risk | Alternative |
|------------|---------|------|-------------|
| Rust toolchain | stable | Low | Pre-built binaries from releases |
| opencode | latest | Low | Already installed |
| python3 | 3.x | Low | Already available |

## Risks and Unknowns

### Known Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| terraphim-ai build fails | Medium | High | Check Cargo.lock, use `cargo build --release` with locked deps |
| Judge role config complexity | Low | Medium | Provide setup script or template |
| KG file changes don't reload | Low | Low | terraphim rebuilds automata on startup |

### Open Questions

1. Does terraphim-agent `validate --checklist` support custom checklist definitions? -- Needs source verification
2. Can terraphim-cli `find` return match positions and scores? -- Needed for term coverage analysis
3. Does the `--robot` flag produce machine-parseable exit codes? -- Critical for script integration

### Assumptions

| Assumption | Basis | Risk if Wrong | Verified? |
|------------|-------|---------------|-----------|
| terraphim-ai builds cleanly on macOS | Rust cross-platform support | Need to fix build issues | No |
| `find` command returns JSON with matched terms and positions | CLI source review | Would need alternative parsing | No |
| `validate --checklist` works offline | Offline mode is default | Would need server | No |
| KG files in ~/.config/terraphim/kg/ are loaded by role | Config system design | Would need different KG path | Partially |

## Research Findings

### Key Insights

1. **terraphim-cli `find` replaces 90% of inline Python**: Instead of Python scripts extracting verdict fields, `terraphim-cli find` matches all rubric terms in text and returns structured JSON. The judge script becomes: run opencode -> pipe output through terraphim-cli find -> check term coverage.

2. **Knowledge graph as rubric definition**: Instead of hardcoding "semantic means factual correctness, domain terminology", define a KG file `judge-semantic.md` with `synonyms:: factual correctness, domain terminology, accurate, factual, correct terminology, no contradictions`. The thesaurus engine then normalizes any of these to "semantic".

3. **`validate --checklist` as quality gate**: Define a checklist `judge_verdict` that requires all three dimensions present. `terraphim-cli validate --checklist judge_verdict` returns pass/fail based on whether the output covers all required terms.

4. **File-based opencode invocation**: Write the full prompt (template + file content) to a temp file, pass to opencode via `--file`. This eliminates all shell escaping issues.

5. **terraphim-agent hooks for automation**: Configure PostToolUse hook to trigger judge on task completion. The hook receives tool output JSON and can invoke the judge runner.

### KG Design for Judge Rubric

Three KG files define the rubric vocabulary:

```
~/.config/terraphim/kg/judge/
  judge-semantic.md     -- synonyms for semantic dimension
  judge-pragmatic.md    -- synonyms for pragmatic dimension
  judge-syntactic.md    -- synonyms for syntactic dimension
  judge-verdicts.md     -- verdict vocabulary (accept, improve, reject)
  judge-checklist.md    -- required checklist items
```

Example `judge-semantic.md`:
```markdown
# semantic

Quality dimension measuring domain accuracy and factual correctness.

synonyms:: factual correctness, domain accuracy, correct terminology, factual, accurate, domain terminology, no contradictions, technical accuracy, domain knowledge, subject matter accuracy
```

### Architecture: v2 Judge Flow

```
run-judge.sh (simplified)
  |
  |-- 1. Write prompt to temp file (template + file content)
  |-- 2. Call opencode run --model <model> --file <tempfile>
  |-- 3. Pipe raw output through: terraphim-cli find --role judge
  |      (extracts rubric terms, returns JSON with matches)
  |-- 4. Pipe raw output through: terraphim-cli validate --checklist judge_verdict --role judge
  |      (checks all dimensions present)
  |-- 5. Extract verdict JSON (still needed, but simpler with structured text)
  |-- 6. Log verdict to JSONL
  |
  handle-disagreement.sh (unchanged)
  pre-push-judge.sh (unchanged)
```

### Simplification Gains

| v1 Component | v2 Replacement | Lines Saved |
|--------------|----------------|-------------|
| 6 inline Python scripts | terraphim-cli find/validate | ~80 lines |
| Shell variable substitution in heredocs | File-based prompt with sed | ~30 lines |
| Hardcoded rubric terms | KG markdown files | ~60 lines in prompts |
| Manual JSON field extraction | terraphim-cli --format json | ~20 lines |

## Recommendations

### Proceed/No-Proceed

**Proceed**. The v1 approach failed during validation. terraphim-cli provides the exact primitives needed (find, validate, replace) and outputs structured JSON. The KG-based rubric is more maintainable than hardcoded bash strings.

### Scope

1. Build terraphim-agent and terraphim-cli from source
2. Create judge role and KG thesaurus files
3. Rewrite run-judge.sh to use file-based prompts and terraphim-cli parsing
4. Validate end-to-end with real file evaluation
5. Update SKILL.md to document terraphim-cli integration

### Risk Mitigation

- Build terraphim binaries first as a prerequisite check
- Keep opencode for LLM invocation (proven for short prompts)
- Retain handle-disagreement.sh and pre-push-judge.sh (these work correctly)
- Test each terraphim-cli command independently before integrating

## Next Steps

If approved, proceed to disciplined-design phase:
1. Design KG thesaurus files for judge rubric
2. Design simplified run-judge.sh using terraphim-cli
3. Design judge role configuration
4. Implementation plan with file-by-file changes
