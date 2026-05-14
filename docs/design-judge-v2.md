# Design Document: Judge v2 -- Terraphim-Native Implementation

**Status**: Draft
**Date**: 2026-02-17
**Issue**: #17 (Epic), #23 (Validation)
**Research**: docs/research-judge-v2.md
**Skill**: disciplined-design

## Design Summary

Rewrite the judge runner to use terraphim-cli for term normalization and validation, file-based prompt delivery to opencode, and a knowledge graph thesaurus defining the rubric vocabulary. The multi-iteration protocol (quick -> deep -> tiebreaker) remains unchanged. handle-disagreement.sh and pre-push-judge.sh remain unchanged.

## Changes Overview

| # | File | Action | Purpose |
|---|------|--------|---------|
| 1 | `automation/judge/kg/judge-semantic.md` | Create | KG thesaurus: semantic dimension synonyms |
| 2 | `automation/judge/kg/judge-pragmatic.md` | Create | KG thesaurus: pragmatic dimension synonyms |
| 3 | `automation/judge/kg/judge-syntactic.md` | Create | KG thesaurus: syntactic dimension synonyms |
| 4 | `automation/judge/kg/judge-verdicts.md` | Create | KG thesaurus: verdict vocabulary |
| 5 | `automation/judge/kg/judge-checklist.md` | Create | KG thesaurus: required checklist items |
| 6 | `automation/judge/run-judge.sh` | Rewrite | Use file-based prompts + terraphim-cli |
| 7 | `automation/judge/setup-judge-kg.sh` | Create | Setup script: symlink KG files to terraphim config |
| 8 | `skills/judge/SKILL.md` | Update | Document terraphim-cli integration |

**Unchanged files** (no modifications needed):
- `automation/judge/handle-disagreement.sh` -- works correctly
- `automation/judge/pre-push-judge.sh` -- works correctly
- `automation/judge/terraphim-agent-hook.toml` -- template, no changes
- `automation/judge/verdict-schema.json` -- schema is correct
- `automation/judge/opencode-judge.json` -- config is correct
- `skills/judge/references/prompt-quick.md` -- template is correct
- `skills/judge/references/prompt-deep.md` -- template is correct

## Detailed Design

### Step 1: Knowledge Graph Thesaurus Files

Create `automation/judge/kg/` directory with 5 markdown files following the terraphim KG format (`# Title` + `synonyms::` field).

**File: `automation/judge/kg/judge-semantic.md`**

```markdown
# semantic

Quality dimension measuring domain accuracy and factual correctness.

synonyms:: factual correctness, domain accuracy, correct terminology, factual, accurate, domain terminology, no contradictions, technical accuracy, subject matter accuracy, domain knowledge, correct facts, terminological accuracy, domain-specific, semantically correct, factually accurate
```

**File: `automation/judge/kg/judge-pragmatic.md`**

```markdown
# pragmatic

Quality dimension measuring actionability and usefulness for intended purpose.

synonyms:: actionable, useful, actionability, practical, enables action, addresses goal, fit for purpose, goal-oriented, task completion, meets requirements, usable, practical value, decision-enabling, implementable, addresses the task
```

**File: `automation/judge/kg/judge-syntactic.md`**

```markdown
# syntactic

Quality dimension measuring internal consistency and structural completeness.

synonyms:: internally consistent, well-structured, format compliance, structural completeness, no broken references, consistent structure, valid format, complete structure, properly formatted, structural integrity, consistent formatting, syntactically correct, well-formed, structurally sound, complete and consistent
```

**File: `automation/judge/kg/judge-verdicts.md`**

```markdown
# verdict

Judge verdict classification for task output quality.

synonyms:: accept, improve, reject, escalate, accepted, rejected, improved, pass, fail, needs improvement, quality gate, quality check, verdict result
```

**File: `automation/judge/kg/judge-checklist.md`**

```markdown
# judge checklist

Required elements in a judge verdict response.

synonyms:: scores, reasoning, improvements, verdict, semantic score, pragmatic score, syntactic score, average score, task_id, model, timestamp
```

### Step 2: Setup Script

**File: `automation/judge/setup-judge-kg.sh`**

Purpose: Copy or symlink judge KG files into `~/.config/terraphim/kg/` so terraphim-agent/cli can discover them.

```bash
#!/usr/bin/env bash
# setup-judge-kg.sh -- Install judge knowledge graph files for terraphim
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KG_SRC="${SCRIPT_DIR}/kg"
KG_DEST="${HOME}/.config/terraphim/kg"

# Ensure destination exists
mkdir -p "$KG_DEST"

# Copy KG files (overwrite if exists)
for f in "${KG_SRC}"/judge-*.md; do
    fname=$(basename "$f")
    cp "$f" "${KG_DEST}/${fname}"
    echo "Installed: ${KG_DEST}/${fname}"
done

echo "Judge KG files installed. Verify with: terraphim-cli thesaurus --limit 50"
```

### Step 3: Rewrite run-judge.sh

Key changes from v1:

1. **File-based prompt delivery**: Write complete prompt (template + file content) to a temp file, pass to opencode via `--file <tempfile>`.

2. **terraphim-cli for term extraction**: After opencode returns raw text, use `terraphim-cli find` to detect rubric terms in the model's response.

3. **Simplified JSON extraction**: Since the prompt instructs JSON-only output, extract the JSON block directly from the concatenated text without complex Python parsing. Use python3 only for the minimal JSON validation step.

4. **Graceful degradation**: If terraphim-cli is not available, fall back to the v1 Python-based extraction (fail-open design).

#### Architecture of rewritten run-judge.sh

```
parse_args()
  |
collect_file_content()  -- reads files into variable
  |
write_prompt_to_tempfile()  -- writes template + content to tmp file
  |                            (eliminates shell escaping issues)
  |
call_opencode()  -- opencode run --model <model> --file <tmpfile>
  |                 extracts text from JSON event stream
  |                 returns raw text (not verdict JSON)
  |
extract_verdict_json()  -- finds {...} with "verdict" key in raw text
  |                        uses python3 for reliable JSON parsing
  |
validate_verdict()  -- checks required fields and value ranges
  |
[optional] terraphim_check()  -- terraphim-cli find on reasoning text
  |                               logs matched rubric terms
  |
log_verdict()  -- appends to verdicts.jsonl
  |
multi_iteration_protocol()  -- quick -> deep -> tiebreaker
                                (unchanged logic)
```

#### Key Function Changes

**write_prompt_to_tempfile()** (NEW -- replaces build_*_prompt heredocs):

```bash
write_prompt_to_tempfile() {
    local template_file="$1"  # prompt-quick.md or prompt-deep.md
    local task_id="$2"
    local task_desc="$3"
    local task_output="$4"
    local timestamp="$5"
    local tmpfile
    tmpfile=$(mktemp /tmp/judge-prompt-XXXXXX.md)

    # Read template and substitute variables
    sed -e "s|{{task_id}}|${task_id}|g" \
        -e "s|{{task_description}}|${task_desc}|g" \
        -e "s|{{timestamp}}|${timestamp}|g" \
        "$template_file" > "$tmpfile"

    # Append task output as-is (no escaping needed in file context)
    printf '\n--- TASK OUTPUT ---\n' >> "$tmpfile"
    printf '%s\n' "$task_output" >> "$tmpfile"

    echo "$tmpfile"
}
```

**call_opencode()** (SIMPLIFIED):

```bash
call_opencode() {
    local model="$1"
    local timeout_s="$2"
    local prompt_file="$3"  # file path, not text
    local raw_output
    local exit_code=0

    raw_output=$($TIMEOUT_CMD "${timeout_s}s" opencode run \
        --model "$model" \
        --format json \
        --dir "$PROJECT_DIR" \
        --file "$prompt_file" \
        "Evaluate the task output in the attached file and respond with JSON only." \
        2>/dev/null) || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo ""
        return 1
    fi

    # Extract text content from opencode JSON event stream
    local text_content
    text_content=$(echo "$raw_output" | python3 -c "
import sys, json
data = sys.stdin.read()
parts = []
for line in data.strip().split('\n'):
    try:
        evt = json.loads(line)
        if evt.get('type') == 'text':
            parts.append(evt.get('part', {}).get('text', ''))
    except:
        continue
print(''.join(parts))
" 2>/dev/null) || true

    echo "$text_content"
}
```

**extract_verdict_json()** (SIMPLIFIED):

```bash
extract_verdict_json() {
    local raw_text="$1"
    python3 -c "
import sys, json, re
text = sys.stdin.read()
# Strip markdown fencing
cleaned = re.sub(r'^\`\`\`json\s*', '', text.strip())
cleaned = re.sub(r'\`\`\`\s*$', '', cleaned.strip())
try:
    obj = json.loads(cleaned)
    if 'verdict' in obj:
        print(json.dumps(obj))
        sys.exit(0)
except:
    pass
# Fallback: find JSON with verdict key
for m in re.finditer(r'\{[^{}]*\"verdict\"[^{}]*\}', text, re.DOTALL):
    try:
        obj = json.loads(m.group())
        if 'verdict' in obj:
            print(json.dumps(obj))
            sys.exit(0)
    except:
        continue
sys.exit(1)
" <<< "$raw_text"
}
```

**terraphim_check()** (NEW, optional enrichment):

```bash
terraphim_check() {
    local reasoning="$1"
    if ! command -v terraphim-cli &>/dev/null; then
        return 0  # fail-open: skip if not installed
    fi
    # Find rubric terms in the judge's reasoning
    local matches
    matches=$(terraphim-cli find "$reasoning" --format json 2>/dev/null) || return 0
    echo "$matches"
}
```

### Step 4: Update SKILL.md

Add a section documenting the terraphim-cli integration:

```markdown
## Terraphim Integration (Optional)

When terraphim-cli is available, the judge runner uses knowledge graph-based
term normalization to enrich verdict analysis:

### Knowledge Graph Setup

```bash
# Install judge KG files
automation/judge/setup-judge-kg.sh

# Verify installation
terraphim-cli thesaurus --limit 50
```

### KG Files

Located in `automation/judge/kg/`:

| File | Purpose |
|------|---------|
| `judge-semantic.md` | Synonyms for semantic quality dimension |
| `judge-pragmatic.md` | Synonyms for pragmatic quality dimension |
| `judge-syntactic.md` | Synonyms for syntactic quality dimension |
| `judge-verdicts.md` | Verdict vocabulary normalization |
| `judge-checklist.md` | Required verdict elements |

### Fail-Open Design

If terraphim-cli is not installed, the judge falls back to direct JSON
extraction without term normalization. All core functionality works
without terraphim -- the KG integration is an enrichment layer.
```

## Implementation Order

| Step | File(s) | Depends On | Verification |
|------|---------|------------|-------------|
| 0 | Build terraphim-agent/cli | Rust toolchain | `terraphim-cli --help` |
| 1 | KG files (5 files) | None | `terraphim-cli thesaurus` shows terms |
| 2 | setup-judge-kg.sh | Step 1 | Script runs, files in ~/.config/terraphim/kg/ |
| 3 | run-judge.sh rewrite | Steps 0-2 | End-to-end test with real file |
| 4 | SKILL.md update | Step 3 | package_skill.py validates |
| 5 | Re-package judge.skill | Step 4 | .skill file updated |

## Verification Plan

1. **Build check**: `cargo build --release -p terraphim_cli` succeeds
2. **KG check**: After setup, `terraphim-cli find "factual correctness and actionability"` returns matches for `semantic` and `pragmatic`
3. **Prompt file check**: Temp file contains complete prompt with file content, no shell metacharacter issues
4. **End-to-end**: `./automation/judge/run-judge.sh --task-id test --description "Test skill quality" skills/judge/SKILL.md` produces valid verdict
5. **Fallback check**: Remove terraphim-cli from PATH, re-run judge -- should still work (fail-open)

## Risks

| Risk | Mitigation |
|------|-----------|
| terraphim-ai build fails | Try `cargo install --path crates/terraphim_cli`; fallback to gh release download |
| KG role configuration needed | Document setup steps; provide setup-judge-kg.sh |
| sed template substitution edge cases | Use delimiter `|` not `/` to avoid path conflicts |

## Essentialism Check

- **ONE essential outcome**: Judge produces valid verdict JSON from real file evaluation
- **Eliminated**: Server mode, TUI integration, learning capture, guard patterns, new LLM providers
- **Effortless inversion**: "What if parsing was easy?" -- Use file-based prompts (no escaping), terraphim-cli find (no custom parsing)
