#!/usr/bin/env bash
# run-judge.sh -- Multi-iteration judge runner for task output evaluation (v2)
# Part of the judge skill (Issue #20, #23)
#
# v2 changes: file-based prompt delivery to opencode (eliminates shell escaping),
# optional terraphim-cli integration for term normalization (fail-open).
#
# Usage: run-judge.sh [options] <file1> [file2 ...]
#   -t, --task-id     Task identifier (default: "unknown")
#   -d, --description Task description
#   -a, --acceptance  Acceptance criteria
#   -c, --config      Path to opencode config (default: automation/judge/opencode-judge.json)
#   -o, --output      Verdict JSONL output file (default: automation/judge/verdicts.jsonl)
#   -h, --help        Show help
#
# Exit codes:
#   0 - Accepted
#   1 - Rejected or exhausted all rounds
#   2 - Human fallback needed

set -euo pipefail

# --- Ensure tool binaries are in PATH ---
export PATH="$HOME/.bun/bin:$HOME/.cargo/bin:$PATH"

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
QUICK_MODEL="opencode/gpt-5-nano"
DEEP_MODEL="opencode/kimi-k2.5-free"
TIEBREAKER_MODEL="opencode/gpt-5.1-codex-mini"
QUICK_TIMEOUT=45
DEEP_TIMEOUT=60
TIEBREAKER_TIMEOUT=45
QUICK_TRUNCATE=4000
OPENCODE_CONFIG="${SCRIPT_DIR}/opencode-judge.json"
VERDICT_FILE="${SCRIPT_DIR}/verdicts.jsonl"
TASK_ID="unknown"
TASK_DESCRIPTION=""
ACCEPTANCE_CRITERIA=""

# Temp files for cleanup
TMPFILES=()
cleanup() {
    for f in "${TMPFILES[@]}"; do
        rm -f "$f" 2>/dev/null
    done
}
trap cleanup EXIT

# --- Parse arguments ---
FILES=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--task-id) TASK_ID="$2"; shift 2 ;;
        -d|--description) TASK_DESCRIPTION="$2"; shift 2 ;;
        -a|--acceptance) ACCEPTANCE_CRITERIA="$2"; shift 2 ;;
        -c|--config) OPENCODE_CONFIG="$2"; shift 2 ;;
        -o|--output) VERDICT_FILE="$2"; shift 2 ;;
        -h|--help)
            head -16 "${BASH_SOURCE[0]}" | tail -14
            exit 0
            ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) FILES+=("$1"); shift ;;
    esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "Error: No files specified" >&2
    echo "Usage: run-judge.sh [options] <file1> [file2 ...]" >&2
    exit 1
fi

# --- Collect task output from files ---
TASK_OUTPUT=""
for f in "${FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "Warning: File not found: $f" >&2
        continue
    fi
    TASK_OUTPUT+="--- FILE: ${f} ---"$'\n'
    TASK_OUTPUT+="$(cat "$f")"$'\n'
done

if [[ -z "$TASK_OUTPUT" ]]; then
    echo "Error: No readable files found" >&2
    exit 1
fi

# --- Detect timeout command (gtimeout on macOS, timeout on Linux) ---
if command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
elif command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
else
    echo "Warning: Neither gtimeout nor timeout found. Running without timeout." >&2
    TIMEOUT_CMD=""
fi

# --- Helper: get timestamp ---
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# --- Helper: write prompt to temp file ---
# Writes the complete prompt (instructions + task output) to a temp file.
# This eliminates shell escaping issues with special characters in file content.
write_prompt_file() {
    local mode="$1"       # quick, deep, or tiebreaker
    local model="$2"
    local task_out="$3"
    local extra="$4"      # extra context (prior verdicts for tiebreaker)
    local ts
    ts=$(get_timestamp)
    local tmpfile
    tmpfile=$(mktemp /tmp/judge-prompt-XXXXXX)
    TMPFILES+=("$tmpfile")

    if [[ "$mode" == "quick" ]]; then
        cat > "$tmpfile" <<PROMPT_EOF
You are a quality judge. Evaluate the provided task output against three dimensions.
Score each dimension 1-5. Output ONLY valid JSON, nothing else.

Evaluate this task output:

TASK: ${TASK_DESCRIPTION}
OUTPUT:
${task_out}

Score on three dimensions (1-5 each):
- semantic: Does it accurately represent the domain? Factual correctness, correct terminology, no contradictions.
- pragmatic: Does it enable intended actions? Actionable, useful, addresses the task goal.
- syntactic: Is it internally consistent and well-structured? Format compliance, completeness, no broken references.

Verdict rules:
- "accept" if all scores >= 3 AND average >= 3.5
- "improve" if any score < 3 but all >= 2
- "reject" if any score < 2

Respond with ONLY this JSON (no other text):
{
  "task_id": "${TASK_ID}",
  "model": "${model}",
  "mode": "quick",
  "verdict": "<accept|improve|reject>",
  "scores": {
    "semantic": "<1-5>",
    "pragmatic": "<1-5>",
    "syntactic": "<1-5>"
  },
  "average": "<calculated average>",
  "reasoning": "<one sentence justification>",
  "improvements": [],
  "timestamp": "${ts}"
}
PROMPT_EOF
    elif [[ "$mode" == "deep" || "$mode" == "tiebreaker" ]]; then
        cat > "$tmpfile" <<PROMPT_EOF
You are a thorough quality evaluator. Assess the provided task output against three
quality dimensions. Provide detailed reasoning and specific improvement suggestions.
Output ONLY valid JSON, nothing else.

Evaluate this task output thoroughly:

TASK: ${TASK_DESCRIPTION}

ACCEPTANCE CRITERIA:
${ACCEPTANCE_CRITERIA}

OUTPUT:
${task_out}

Score each dimension 1-5:

1. semantic: Does it accurately represent the domain?
2. pragmatic: Does it enable intended actions?
3. syntactic: Is it internally consistent and well-structured?

Verdict rules:
- "accept" if all scores >= 3 AND average >= 3.5
- "improve" if any score < 3 but all >= 2
- "reject" if any score < 2

For each improvement, specify: what to fix, where it is, and why it matters.

Respond with ONLY this JSON (no other text):
{
  "task_id": "${TASK_ID}",
  "model": "${model}",
  "mode": "${mode}",
  "verdict": "<accept|improve|reject>",
  "scores": {
    "semantic": "<1-5>",
    "pragmatic": "<1-5>",
    "syntactic": "<1-5>"
  },
  "average": "<calculated average>",
  "reasoning": "<detailed reasoning covering all three dimensions>",
  "improvements": [
    {
      "dimension": "<semantic|pragmatic|syntactic>",
      "location": "<where in the output>",
      "issue": "<what is wrong>",
      "suggestion": "<how to fix it>"
    }
  ],
  "timestamp": "${ts}"
}
PROMPT_EOF

        # Append tiebreaker context if provided
        if [[ -n "$extra" ]]; then
            cat >> "$tmpfile" <<TB_EOF

PRIOR VERDICTS (for context only -- form your own independent judgement):

${extra}

You are the tiebreaker. Evaluate independently, then state your verdict.
TB_EOF
        fi
    fi

    echo "$tmpfile"
}

# --- Helper: call opencode with file-based prompt ---
# The prompt is written to a file and piped via stdin to opencode.
# Task files are attached via --file flags.
call_opencode() {
    local model="$1"
    local timeout_s="$2"
    local prompt_file="$3"
    shift 3
    local file_args=()
    for f in "$@"; do
        file_args+=(--file "$f")
    done
    local raw_output
    local exit_code=0

    local cmd_prefix=""
    if [[ -n "$TIMEOUT_CMD" ]]; then
        cmd_prefix="${TIMEOUT_CMD} ${timeout_s}s"
    fi

    # Pipe prompt via stdin; attach task files via --file
    raw_output=$(${cmd_prefix} opencode run \
        --model "$model" \
        --format json \
        --dir "$PROJECT_DIR" \
        "${file_args[@]}" \
        < "$prompt_file" \
        2>/dev/null) || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo ""
        return 1
    fi

    # Extract text content from opencode JSON event stream
    # Each line is: {"type":"text","part":{"text":"..."}} or similar
    local text_content
    text_content=$(python3 -c "
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
" <<< "$raw_output" 2>/dev/null) || true

    echo "$text_content"
}

# --- Helper: extract verdict JSON from raw text ---
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
" <<< "$raw_text" 2>/dev/null
}

# --- Helper: validate and normalize verdict JSON ---
# Handles both {"scores":{"semantic":N}} and {"semantic":N} formats.
# Outputs normalized JSON (with scores wrapper) on success.
validate_and_normalize() {
    local json_str="$1"
    printf '%s' "$json_str" | python3 -c "
import sys, json
try:
    v = json.loads(sys.stdin.read().strip())
    if 'verdict' not in v:
        print('Missing: verdict', file=sys.stderr)
        sys.exit(1)
    if v['verdict'] not in ('accept', 'improve', 'reject', 'escalate'):
        print(f'Invalid verdict: {v[\"verdict\"]}', file=sys.stderr)
        sys.exit(1)
    # Normalize scores: handle flat format
    scores = v.get('scores', {})
    if not scores:
        scores = {}
        for d in ('semantic','pragmatic','syntactic'):
            if d in v:
                scores[d] = v.pop(d)
        v['scores'] = scores
    for dim in ('semantic', 'pragmatic', 'syntactic'):
        s = scores.get(dim)
        if not isinstance(s, (int, float)) or s < 1 or s > 5:
            print(f'Invalid score for {dim}: {s}', file=sys.stderr)
            sys.exit(1)
    if 'reasoning' not in v:
        print('Missing: reasoning', file=sys.stderr)
        sys.exit(1)
    # Ensure average is present
    if 'average' not in v:
        v['average'] = round(sum(scores[d] for d in ('semantic','pragmatic','syntactic')) / 3, 2)
    # Ensure improvements is present
    if 'improvements' not in v:
        v['improvements'] = []
    print(json.dumps(v))
except Exception as e:
    print(f'Validation error: {e}', file=sys.stderr)
    sys.exit(1)
"
}

# --- Helper: extract field from verdict JSON ---
get_field() {
    local json_str="$1"
    local field="$2"
    python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('$field',''))" <<< "$json_str" 2>/dev/null
}

# --- Helper: log verdict to JSONL ---
log_verdict() {
    local verdict_json="$1"
    local round_num="$2"
    local tier="$3"
    local prev_rounds="$4"
    local consensus="$5"

    python3 -c "
import sys, json
v = json.loads(sys.stdin.read())
v['task_id'] = '$TASK_ID'
v['round'] = $round_num
v['judge_tier'] = '$tier'
v['previous_rounds'] = json.loads('$prev_rounds')
v['consensus'] = '$consensus' if '$consensus' != 'null' else None
v['human_override'] = None
print(json.dumps(v))
" <<< "$verdict_json" >> "$VERDICT_FILE" 2>/dev/null
}

# --- Helper: terraphim-cli term check (optional enrichment) ---
# Uses "LLM Enforcer" role which loads KG files from ~/.config/terraphim/kg/
terraphim_check() {
    local text="$1"
    if ! command -v terraphim-cli &>/dev/null; then
        return 0  # fail-open: skip if not installed
    fi
    local matches
    matches=$(terraphim-cli find "$text" --format json 2>/dev/null) || return 0
    local count
    count=$(echo "$matches" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('count',0))" 2>/dev/null) || count=0
    if [[ "$count" -gt 0 ]]; then
        echo "  [terraphim] Matched ${count} rubric terms in reasoning"
    fi
}

# --- Main execution ---
echo "Judge evaluation starting for task: ${TASK_ID}"
echo "Files: ${FILES[*]}"
echo "---"

PREVIOUS_ROUNDS="[]"
QUICK_VERDICT_JSON=""
DEEP_VERDICT_JSON=""
ROUND=0

# --- Helper: run a judge round ---
run_judge_round() {
    local round_num="$1"
    local tier="$2"
    local model="$3"
    local timeout_s="$4"
    local mode="$5"
    local task_out="$6"
    local extra="${7:-}"

    echo "[Round ${round_num}] ${tier} judge (${model})..."

    # Write prompt to file (eliminates shell escaping issues)
    local prompt_file
    prompt_file=$(write_prompt_file "$mode" "$model" "$task_out" "$extra")

    # Call opencode with prompt via stdin, task files attached via --file
    local raw_text
    raw_text=$(call_opencode "$model" "$timeout_s" "$prompt_file" "${FILES[@]}") || true

    if [[ -z "$raw_text" ]]; then
        echo "[Round ${round_num}] ${tier} judge returned empty response, retrying..."
        raw_text=$(call_opencode "$model" "$timeout_s" "$prompt_file" "${FILES[@]}") || true
    fi

    if [[ -z "$raw_text" ]]; then
        echo "[Round ${round_num}] ${tier} judge failed to produce output"
        return 1
    fi

    # Extract verdict JSON from raw text
    local extracted_json
    extracted_json=$(extract_verdict_json "$raw_text") || true

    if [[ -z "$extracted_json" ]]; then
        echo "[Round ${round_num}] ${tier} judge response did not contain valid verdict JSON"
        echo "[Round ${round_num}] Raw response (first 500 chars): ${raw_text:0:500}"
        return 1
    fi

    # Validate and normalize (handles flat vs nested score formats)
    local verdict_json
    verdict_json=$(validate_and_normalize "$extracted_json") || true

    if [[ -z "$verdict_json" ]]; then
        echo "[Round ${round_num}] ${tier} judge verdict failed validation"
        return 1
    fi

    local verdict
    verdict=$(get_field "$verdict_json" "verdict")
    local avg
    avg=$(get_field "$verdict_json" "average")
    echo "[Round ${round_num}] ${tier} verdict: ${verdict} (avg: ${avg})"

    # Optional: terraphim-cli term enrichment
    local reasoning
    reasoning=$(get_field "$verdict_json" "reasoning")
    terraphim_check "$reasoning"

    # Store result in global variable (bash workaround for returning complex data)
    ROUND_RESULT_JSON="$verdict_json"
    ROUND_RESULT_VERDICT="$verdict"
    ROUND_RESULT_AVG="$avg"
}

# ============================
# Round 1: Quick judge
# ============================
ROUND=1
TASK_OUTPUT_QUICK="${TASK_OUTPUT:0:$QUICK_TRUNCATE}"

if ! run_judge_round "$ROUND" "Quick" "$QUICK_MODEL" "$QUICK_TIMEOUT" "quick" "$TASK_OUTPUT_QUICK"; then
    echo "RESULT: Human fallback needed (invalid quick judge response)"
    "${SCRIPT_DIR}/handle-disagreement.sh" -t "$TASK_ID" -T "$TASK_DESCRIPTION" -f "${FILES[*]}" -r "invalid-json" || true
    exit 2
fi

QUICK_VERDICT_JSON="$ROUND_RESULT_JSON"
QUICK_VERDICT="$ROUND_RESULT_VERDICT"
QUICK_AVG="$ROUND_RESULT_AVG"

log_verdict "$QUICK_VERDICT_JSON" "$ROUND" "quick" "$PREVIOUS_ROUNDS" "null"

if [[ "$QUICK_VERDICT" == "accept" ]]; then
    echo "RESULT: ACCEPTED (quick judge, round ${ROUND})"
    exit 0
fi

if [[ "$QUICK_VERDICT" == "reject" ]]; then
    echo "RESULT: REJECTED (quick judge, round ${ROUND})"
    "${SCRIPT_DIR}/handle-disagreement.sh" -t "$TASK_ID" -T "$TASK_DESCRIPTION" -f "${FILES[*]}" -r "persistent-reject" || true
    exit 1
fi

# ============================
# Round 2: Deep judge (quick returned "improve")
# ============================
PREVIOUS_ROUNDS=$(python3 -c "
import json
prev = [{'round': 1, 'model': '${QUICK_MODEL}', 'verdict': '${QUICK_VERDICT}', 'average': ${QUICK_AVG}}]
print(json.dumps(prev))
")

ROUND=2

if ! run_judge_round "$ROUND" "Deep" "$DEEP_MODEL" "$DEEP_TIMEOUT" "deep" "$TASK_OUTPUT"; then
    echo "RESULT: Human fallback needed (invalid deep judge response)"
    "${SCRIPT_DIR}/handle-disagreement.sh" -t "$TASK_ID" -T "$TASK_DESCRIPTION" -f "${FILES[*]}" -r "invalid-json" || true
    exit 2
fi

DEEP_VERDICT_JSON="$ROUND_RESULT_JSON"
DEEP_VERDICT="$ROUND_RESULT_VERDICT"
DEEP_AVG="$ROUND_RESULT_AVG"

log_verdict "$DEEP_VERDICT_JSON" "$ROUND" "deep" "$PREVIOUS_ROUNDS" "null"

# Check for disagreement requiring tiebreaker
NEEDS_TIEBREAKER=false
if [[ "$QUICK_VERDICT" == "accept" && "$DEEP_VERDICT" == "reject" ]] || \
   [[ "$QUICK_VERDICT" == "reject" && "$DEEP_VERDICT" == "accept" ]]; then
    NEEDS_TIEBREAKER=true
fi

if [[ "$NEEDS_TIEBREAKER" == "false" ]]; then
    if [[ "$DEEP_VERDICT" == "accept" ]]; then
        echo "RESULT: ACCEPTED (deep judge, round ${ROUND})"
        exit 0
    elif [[ "$DEEP_VERDICT" == "reject" ]]; then
        echo "RESULT: REJECTED (deep judge, round ${ROUND})"
        "${SCRIPT_DIR}/handle-disagreement.sh" -t "$TASK_ID" -T "$TASK_DESCRIPTION" -f "${FILES[*]}" -r "persistent-reject" || true
        exit 1
    else
        # Both returned "improve" -- human fallback
        echo "RESULT: Human fallback needed (both judges returned 'improve')"
        "${SCRIPT_DIR}/handle-disagreement.sh" -t "$TASK_ID" -T "$TASK_DESCRIPTION" -f "${FILES[*]}" -r "disagreement" || true
        exit 2
    fi
fi

# ============================
# Round 3: Tiebreaker
# ============================
PREVIOUS_ROUNDS=$(python3 -c "
import json
prev = [
    {'round': 1, 'model': '${QUICK_MODEL}', 'verdict': '${QUICK_VERDICT}', 'average': ${QUICK_AVG}},
    {'round': 2, 'model': '${DEEP_MODEL}', 'verdict': '${DEEP_VERDICT}', 'average': ${DEEP_AVG}}
]
print(json.dumps(prev))
")

ROUND=3
TIEBREAKER_EXTRA="Quick judge verdict: ${QUICK_VERDICT_JSON}
Deep judge verdict: ${DEEP_VERDICT_JSON}"

if ! run_judge_round "$ROUND" "Tiebreaker" "$TIEBREAKER_MODEL" "$TIEBREAKER_TIMEOUT" "tiebreaker" "$TASK_OUTPUT" "$TIEBREAKER_EXTRA"; then
    echo "RESULT: Human fallback needed (invalid tiebreaker response)"
    "${SCRIPT_DIR}/handle-disagreement.sh" -t "$TASK_ID" -T "$TASK_DESCRIPTION" -f "${FILES[*]}" -r "invalid-json" || true
    exit 2
fi

TIEBREAKER_VERDICT="$ROUND_RESULT_VERDICT"
TIEBREAKER_AVG="$ROUND_RESULT_AVG"

# Determine consensus
CONSENSUS="split"
if [[ "$QUICK_VERDICT" == "$DEEP_VERDICT" && "$DEEP_VERDICT" == "$TIEBREAKER_VERDICT" ]]; then
    CONSENSUS="unanimous"
elif [[ "$QUICK_VERDICT" == "$TIEBREAKER_VERDICT" ]] || [[ "$DEEP_VERDICT" == "$TIEBREAKER_VERDICT" ]]; then
    CONSENSUS="majority"
fi

log_verdict "$ROUND_RESULT_JSON" "$ROUND" "tiebreaker" "$PREVIOUS_ROUNDS" "$CONSENSUS"

if [[ "$TIEBREAKER_VERDICT" == "accept" ]]; then
    echo "RESULT: ACCEPTED (tiebreaker, round ${ROUND}, consensus: ${CONSENSUS})"
    exit 0
elif [[ "$TIEBREAKER_VERDICT" == "reject" ]]; then
    echo "RESULT: REJECTED (tiebreaker, round ${ROUND}, consensus: ${CONSENSUS})"
    "${SCRIPT_DIR}/handle-disagreement.sh" -t "$TASK_ID" -T "$TASK_DESCRIPTION" -f "${FILES[*]}" -r "persistent-reject" || true
    exit 1
else
    echo "RESULT: Human fallback needed (tiebreaker returned '${TIEBREAKER_VERDICT}')"
    "${SCRIPT_DIR}/handle-disagreement.sh" -t "$TASK_ID" -T "$TASK_DESCRIPTION" -f "${FILES[*]}" -r "disagreement" || true
    exit 2
fi
