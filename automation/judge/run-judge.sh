#!/usr/bin/env bash
# run-judge.sh -- Multi-iteration judge runner for task output evaluation
# Part of the judge skill (Issue #20)
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

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
QUICK_MODEL="opencode/gpt-5-nano"
DEEP_MODEL="opencode/kimi-k2.5-free"
TIEBREAKER_MODEL="opencode/gpt-5.1-codex-mini"
QUICK_TIMEOUT=45
DEEP_TIMEOUT=60
TIEBREAKER_TIMEOUT=45
MAX_ROUNDS=3
OPENCODE_CONFIG="${SCRIPT_DIR}/opencode-judge.json"
VERDICT_FILE="${SCRIPT_DIR}/verdicts.jsonl"
TASK_ID="unknown"
TASK_DESCRIPTION=""
ACCEPTANCE_CRITERIA=""
PROMPT_QUICK="${SCRIPT_DIR}/../../skills/judge/references/prompt-quick.md"
PROMPT_DEEP="${SCRIPT_DIR}/../../skills/judge/references/prompt-deep.md"

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
            head -14 "${BASH_SOURCE[0]}" | tail -12
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

# --- Collect task output ---
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

# Truncate for quick mode (4000 chars)
TASK_OUTPUT_QUICK="${TASK_OUTPUT:0:4000}"

# --- Detect timeout command (gtimeout on macOS, timeout on Linux) ---
if command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
elif command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
else
    echo "Error: Neither gtimeout nor timeout found. Install coreutils." >&2
    exit 1
fi

# --- Helper: get timestamp ---
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# --- Helper: call opencode and extract JSON ---
call_opencode() {
    local model="$1"
    local timeout_s="$2"
    local prompt="$3"
    local raw_output
    local exit_code=0

    raw_output=$($TIMEOUT_CMD "${timeout_s}s" opencode run \
        --model "$model" \
        --format json \
        --dir "$PROJECT_DIR" \
        "$prompt" 2>/dev/null) || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo ""
        return 1
    fi

    # Extract the last JSON object from the output (model response)
    # opencode --format json outputs JSON events; we need the text content
    local text_content
    text_content=$(echo "$raw_output" | grep -o '"text":"[^"]*"' | tail -1 | sed 's/"text":"//;s/"$//' || true)

    # If that fails, try to find raw JSON verdict in the output
    if [[ -z "$text_content" ]] || ! echo "$text_content" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        # Try extracting JSON object directly from raw output
        text_content=$(echo "$raw_output" | python3 -c "
import sys, json, re
data = sys.stdin.read()
# Try to find a JSON object with 'verdict' key
matches = re.findall(r'\{[^{}]*\"verdict\"[^{}]*\}', data, re.DOTALL)
if matches:
    # Validate and print the last match
    for m in reversed(matches):
        try:
            obj = json.loads(m)
            print(json.dumps(obj))
            sys.exit(0)
        except:
            continue
# Try parsing each line as JSON event and extracting text
for line in data.strip().split('\n'):
    try:
        evt = json.loads(line)
        if 'text' in evt:
            # Try to parse the text as JSON
            try:
                obj = json.loads(evt['text'])
                if 'verdict' in obj:
                    print(json.dumps(obj))
                    sys.exit(0)
            except:
                pass
    except:
        continue
sys.exit(1)
" 2>/dev/null) || true
    fi

    if [[ -z "$text_content" ]]; then
        echo ""
        return 1
    fi

    # Strip markdown fencing if present
    text_content=$(echo "$text_content" | sed 's/^```json//;s/^```//;s/```$//' | tr -d '\n')

    echo "$text_content"
}

# --- Helper: validate verdict JSON ---
validate_verdict() {
    local json_str="$1"
    python3 -c "
import sys, json
try:
    v = json.loads('''$json_str''')
    required = ['verdict', 'scores', 'reasoning']
    for r in required:
        if r not in v:
            sys.exit(1)
    if v['verdict'] not in ('accept', 'improve', 'reject', 'escalate'):
        sys.exit(1)
    for dim in ('semantic', 'pragmatic', 'syntactic'):
        s = v['scores'].get(dim)
        if not isinstance(s, (int, float)) or s < 1 or s > 5:
            sys.exit(1)
    sys.exit(0)
except:
    sys.exit(1)
" 2>/dev/null
}

# --- Helper: extract verdict field ---
get_field() {
    local json_str="$1"
    local field="$2"
    echo "$json_str" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('$field',''))" 2>/dev/null
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
v = json.loads('''${verdict_json}''')
v['task_id'] = '${TASK_ID}'
v['round'] = ${round_num}
v['judge_tier'] = '${tier}'
v['previous_rounds'] = json.loads('''${prev_rounds}''')
v['consensus'] = '${consensus}' if '${consensus}' != 'null' else None
v['human_override'] = None
print(json.dumps(v))
" >> "$VERDICT_FILE" 2>/dev/null
}

# --- Build prompts ---
build_quick_prompt() {
    local task_desc="$1"
    local task_out="$2"
    local ts
    ts=$(get_timestamp)
    cat <<PROMPT
Evaluate this task output:

TASK: ${task_desc}
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
  "model": "${QUICK_MODEL}",
  "mode": "quick",
  "verdict": "<accept|improve|reject>",
  "scores": {
    "semantic": <1-5>,
    "pragmatic": <1-5>,
    "syntactic": <1-5>
  },
  "average": <calculated average>,
  "reasoning": "<one sentence justification>",
  "improvements": [],
  "timestamp": "${ts}"
}
PROMPT
}

build_deep_prompt() {
    local task_desc="$1"
    local accept_criteria="$2"
    local task_out="$3"
    local ts
    ts=$(get_timestamp)
    cat <<PROMPT
Evaluate this task output thoroughly:

TASK: ${task_desc}

ACCEPTANCE CRITERIA:
${accept_criteria}

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

Respond with ONLY this JSON (no other text):
{
  "task_id": "${TASK_ID}",
  "model": "${DEEP_MODEL}",
  "mode": "deep",
  "verdict": "<accept|improve|reject>",
  "scores": {
    "semantic": <1-5>,
    "pragmatic": <1-5>,
    "syntactic": <1-5>
  },
  "average": <calculated average>,
  "reasoning": "<detailed reasoning>",
  "improvements": [],
  "timestamp": "${ts}"
}
PROMPT
}

build_tiebreaker_prompt() {
    local task_desc="$1"
    local accept_criteria="$2"
    local task_out="$3"
    local quick_json="$4"
    local deep_json="$5"
    local ts
    ts=$(get_timestamp)
    cat <<PROMPT
Evaluate this task output thoroughly:

TASK: ${task_desc}

ACCEPTANCE CRITERIA:
${accept_criteria}

OUTPUT:
${task_out}

PRIOR VERDICTS (for context only -- form your own independent judgement):

Quick judge verdict: ${quick_json}
Deep judge verdict: ${deep_json}

You are the tiebreaker. Evaluate independently, then state your verdict.

Score each dimension 1-5. Verdict rules:
- "accept" if all scores >= 3 AND average >= 3.5
- "improve" if any score < 3 but all >= 2
- "reject" if any score < 2

Respond with ONLY this JSON (no other text):
{
  "task_id": "${TASK_ID}",
  "model": "${TIEBREAKER_MODEL}",
  "mode": "tiebreaker",
  "verdict": "<accept|improve|reject>",
  "scores": {
    "semantic": <1-5>,
    "pragmatic": <1-5>,
    "syntactic": <1-5>
  },
  "average": <calculated average>,
  "reasoning": "<detailed reasoning>",
  "improvements": [],
  "timestamp": "${ts}"
}
PROMPT
}

# --- Main execution ---
echo "Judge evaluation starting for task: ${TASK_ID}"
echo "Files: ${FILES[*]}"
echo "---"

PREVIOUS_ROUNDS="[]"
QUICK_VERDICT_JSON=""
DEEP_VERDICT_JSON=""
FINAL_VERDICT=""
ROUND=0

# Round 1: Quick judge
ROUND=1
echo "[Round ${ROUND}] Quick judge (${QUICK_MODEL})..."
QUICK_PROMPT=$(build_quick_prompt "$TASK_DESCRIPTION" "$TASK_OUTPUT_QUICK")
QUICK_RESULT=$(call_opencode "$QUICK_MODEL" "$QUICK_TIMEOUT" "$QUICK_PROMPT") || true

if [[ -z "$QUICK_RESULT" ]]; then
    echo "[Round ${ROUND}] Quick judge returned empty response, retrying..."
    QUICK_RESULT=$(call_opencode "$QUICK_MODEL" "$QUICK_TIMEOUT" "$QUICK_PROMPT") || true
fi

if [[ -z "$QUICK_RESULT" ]] || ! validate_verdict "$QUICK_RESULT"; then
    echo "[Round ${ROUND}] Quick judge failed to produce valid verdict"
    echo "RESULT: Human fallback needed (invalid quick judge response)"
    exit 2
fi

QUICK_VERDICT=$(get_field "$QUICK_RESULT" "verdict")
QUICK_AVG=$(get_field "$QUICK_RESULT" "average")
QUICK_VERDICT_JSON="$QUICK_RESULT"
echo "[Round ${ROUND}] Quick verdict: ${QUICK_VERDICT} (avg: ${QUICK_AVG})"

log_verdict "$QUICK_RESULT" "$ROUND" "quick" "$PREVIOUS_ROUNDS" "null"

if [[ "$QUICK_VERDICT" == "accept" ]]; then
    echo "RESULT: ACCEPTED (quick judge, round ${ROUND})"
    FINAL_VERDICT="accept"
    exit 0
fi

if [[ "$QUICK_VERDICT" == "reject" ]]; then
    echo "RESULT: REJECTED (quick judge, round ${ROUND})"
    FINAL_VERDICT="reject"
    exit 1
fi

# Round 2: Deep judge (quick returned "improve")
PREVIOUS_ROUNDS=$(python3 -c "
import json
prev = []
prev.append({'round': 1, 'model': '${QUICK_MODEL}', 'verdict': '${QUICK_VERDICT}', 'average': ${QUICK_AVG}})
print(json.dumps(prev))
")

ROUND=2
echo "[Round ${ROUND}] Deep judge (${DEEP_MODEL})..."
DEEP_PROMPT=$(build_deep_prompt "$TASK_DESCRIPTION" "$ACCEPTANCE_CRITERIA" "$TASK_OUTPUT")
DEEP_RESULT=$(call_opencode "$DEEP_MODEL" "$DEEP_TIMEOUT" "$DEEP_PROMPT") || true

if [[ -z "$DEEP_RESULT" ]]; then
    echo "[Round ${ROUND}] Deep judge returned empty response, retrying..."
    DEEP_RESULT=$(call_opencode "$DEEP_MODEL" "$DEEP_TIMEOUT" "$DEEP_PROMPT") || true
fi

if [[ -z "$DEEP_RESULT" ]] || ! validate_verdict "$DEEP_RESULT"; then
    echo "[Round ${ROUND}] Deep judge failed to produce valid verdict"
    echo "RESULT: Human fallback needed (invalid deep judge response)"
    exit 2
fi

DEEP_VERDICT=$(get_field "$DEEP_RESULT" "verdict")
DEEP_AVG=$(get_field "$DEEP_RESULT" "average")
DEEP_VERDICT_JSON="$DEEP_RESULT"
echo "[Round ${ROUND}] Deep verdict: ${DEEP_VERDICT} (avg: ${DEEP_AVG})"

log_verdict "$DEEP_RESULT" "$ROUND" "deep" "$PREVIOUS_ROUNDS" "null"

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
        exit 1
    else
        # Both returned "improve" -- human fallback
        echo "RESULT: Human fallback needed (both judges returned 'improve')"
        exit 2
    fi
fi

# Round 3: Tiebreaker
PREVIOUS_ROUNDS=$(python3 -c "
import json
prev = [
    {'round': 1, 'model': '${QUICK_MODEL}', 'verdict': '${QUICK_VERDICT}', 'average': ${QUICK_AVG}},
    {'round': 2, 'model': '${DEEP_MODEL}', 'verdict': '${DEEP_VERDICT}', 'average': ${DEEP_AVG}}
]
print(json.dumps(prev))
")

ROUND=3
echo "[Round ${ROUND}] Tiebreaker (${TIEBREAKER_MODEL})..."
TIEBREAKER_PROMPT=$(build_tiebreaker_prompt "$TASK_DESCRIPTION" "$ACCEPTANCE_CRITERIA" "$TASK_OUTPUT" "$QUICK_VERDICT_JSON" "$DEEP_VERDICT_JSON")
TIEBREAKER_RESULT=$(call_opencode "$TIEBREAKER_MODEL" "$TIEBREAKER_TIMEOUT" "$TIEBREAKER_PROMPT") || true

if [[ -z "$TIEBREAKER_RESULT" ]]; then
    echo "[Round ${ROUND}] Tiebreaker returned empty response, retrying..."
    TIEBREAKER_RESULT=$(call_opencode "$TIEBREAKER_MODEL" "$TIEBREAKER_TIMEOUT" "$TIEBREAKER_PROMPT") || true
fi

if [[ -z "$TIEBREAKER_RESULT" ]] || ! validate_verdict "$TIEBREAKER_RESULT"; then
    echo "[Round ${ROUND}] Tiebreaker failed to produce valid verdict"
    echo "RESULT: Human fallback needed (invalid tiebreaker response)"
    exit 2
fi

TIEBREAKER_VERDICT=$(get_field "$TIEBREAKER_RESULT" "verdict")
TIEBREAKER_AVG=$(get_field "$TIEBREAKER_RESULT" "average")
echo "[Round ${ROUND}] Tiebreaker verdict: ${TIEBREAKER_VERDICT} (avg: ${TIEBREAKER_AVG})"

# Determine consensus
CONSENSUS="split"
if [[ "$QUICK_VERDICT" == "$DEEP_VERDICT" && "$DEEP_VERDICT" == "$TIEBREAKER_VERDICT" ]]; then
    CONSENSUS="unanimous"
elif [[ "$QUICK_VERDICT" == "$TIEBREAKER_VERDICT" ]] || [[ "$DEEP_VERDICT" == "$TIEBREAKER_VERDICT" ]]; then
    CONSENSUS="majority"
fi

log_verdict "$TIEBREAKER_RESULT" "$ROUND" "tiebreaker" "$PREVIOUS_ROUNDS" "$CONSENSUS"

if [[ "$TIEBREAKER_VERDICT" == "accept" ]]; then
    echo "RESULT: ACCEPTED (tiebreaker, round ${ROUND}, consensus: ${CONSENSUS})"
    exit 0
elif [[ "$TIEBREAKER_VERDICT" == "reject" ]]; then
    echo "RESULT: REJECTED (tiebreaker, round ${ROUND}, consensus: ${CONSENSUS})"
    exit 1
else
    echo "RESULT: Human fallback needed (tiebreaker returned '${TIEBREAKER_VERDICT}')"
    exit 2
fi
