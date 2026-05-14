#!/usr/bin/env bash
# handle-disagreement.sh -- Disagreement handler and human fallback for judge verdicts
# Part of the judge skill (Issue #21)
#
# Usage: handle-disagreement.sh [options]
#   -t, --task-id       Task identifier (required)
#   -T, --task-title    Task title for issue creation
#   -f, --files         Comma-separated list of evaluated files
#   -v, --verdicts-file Path to verdicts JSONL file (default: automation/judge/verdicts.jsonl)
#   -r, --reason        Reason for escalation (disagreement|persistent-reject|timeout|invalid-json)
#   --override          Human override verdict (accept|reject) -- updates last verdict log entry
#   -h, --help          Show help
#
# Exit codes:
#   0 - Issue created / override logged successfully
#   1 - Error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERDICT_FILE="${SCRIPT_DIR}/verdicts.jsonl"
TASK_ID=""
TASK_TITLE=""
FILES_LIST=""
REASON="disagreement"
OVERRIDE_VERDICT=""

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--task-id) TASK_ID="$2"; shift 2 ;;
        -T|--task-title) TASK_TITLE="$2"; shift 2 ;;
        -f|--files) FILES_LIST="$2"; shift 2 ;;
        -v|--verdicts-file) VERDICT_FILE="$2"; shift 2 ;;
        -r|--reason) REASON="$2"; shift 2 ;;
        --override) OVERRIDE_VERDICT="$2"; shift 2 ;;
        -h|--help)
            head -15 "${BASH_SOURCE[0]}" | tail -13
            exit 0
            ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) shift ;;
    esac
done

# --- Human override mode ---
if [[ -n "$OVERRIDE_VERDICT" ]]; then
    if [[ ! "$OVERRIDE_VERDICT" =~ ^(accept|reject)$ ]]; then
        echo "Error: Override verdict must be 'accept' or 'reject'" >&2
        exit 1
    fi
    if [[ -z "$TASK_ID" ]]; then
        echo "Error: --task-id required for override" >&2
        exit 1
    fi

    # Append override record to verdicts
    python3 -c "
import json, sys
from datetime import datetime, timezone

override = {
    'task_id': '${TASK_ID}',
    'model': 'human',
    'mode': 'override',
    'verdict': '${OVERRIDE_VERDICT}',
    'scores': {'semantic': 0, 'pragmatic': 0, 'syntactic': 0},
    'average': 0,
    'reasoning': 'Human override',
    'improvements': [],
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'round': 0,
    'judge_tier': 'human',
    'previous_rounds': [],
    'consensus': None,
    'human_override': True
}
print(json.dumps(override))
" >> "$VERDICT_FILE"

    echo "Override logged: ${OVERRIDE_VERDICT} for task ${TASK_ID}"
    exit 0
fi

# --- Validation ---
if [[ -z "$TASK_ID" ]]; then
    echo "Error: --task-id is required" >&2
    exit 1
fi

if [[ -z "$TASK_TITLE" ]]; then
    TASK_TITLE="Task ${TASK_ID}"
fi

# --- Extract verdict history for this task ---
VERDICT_HISTORY=""
if [[ -f "$VERDICT_FILE" ]]; then
    VERDICT_HISTORY=$(python3 -c "
import json, sys
verdicts = []
with open('${VERDICT_FILE}') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            v = json.loads(line)
            if v.get('task_id') == '${TASK_ID}':
                verdicts.append(v)
        except:
            continue
for v in verdicts:
    print(json.dumps(v))
" 2>/dev/null) || true
fi

# --- Build scores comparison table ---
SCORES_TABLE=$(python3 -c "
import json, sys
verdicts = []
for line in '''${VERDICT_HISTORY}'''.strip().split('\n'):
    if not line.strip():
        continue
    try:
        verdicts.append(json.loads(line))
    except:
        continue

if not verdicts:
    print('No verdict data available')
    sys.exit(0)

print('| Round | Model | Verdict | Semantic | Pragmatic | Syntactic | Average |')
print('|-------|-------|---------|----------|-----------|-----------|---------|')
for v in verdicts:
    r = v.get('round', '?')
    m = v.get('model', '?')
    vd = v.get('verdict', '?')
    s = v.get('scores', {})
    avg = v.get('average', 0)
    print(f'| {r} | {m} | {vd} | {s.get(\"semantic\",\"?\")} | {s.get(\"pragmatic\",\"?\")} | {s.get(\"syntactic\",\"?\")} | {avg:.2f} |')
" 2>/dev/null) || SCORES_TABLE="No verdict data available"

# --- Determine issue label based on reason ---
case "$REASON" in
    disagreement) LABEL_PREFIX="JUDGE-DISAGREEMENT" ;;
    persistent-reject) LABEL_PREFIX="JUDGE-REJECTED" ;;
    timeout) LABEL_PREFIX="JUDGE-TIMEOUT" ;;
    invalid-json) LABEL_PREFIX="JUDGE-PARSE-ERROR" ;;
    *) LABEL_PREFIX="JUDGE-REVIEW" ;;
esac

# --- Create GitHub issue ---
ISSUE_BODY=$(cat <<ISSUE_EOF
## Judge Evaluation Requires Human Review

**Reason**: ${REASON}
**Task ID**: ${TASK_ID}

### Files Evaluated

${FILES_LIST:-"(not specified)"}

### Scores Comparison

${SCORES_TABLE}

### Full Verdict History

\`\`\`json
${VERDICT_HISTORY:-"[]"}
\`\`\`

### Action Needed

Human review and decision required. To override the automated verdict:

\`\`\`bash
automation/judge/handle-disagreement.sh \\
    --task-id "${TASK_ID}" \\
    --override accept   # or reject
\`\`\`

This will append a human override record to the verdicts log.
ISSUE_EOF
)

ISSUE_URL=$(gh issue create \
    --title "[${LABEL_PREFIX}] Review needed: ${TASK_TITLE}" \
    --body "$ISSUE_BODY" \
    --label "enhancement" 2>&1) || {
    echo "Warning: Failed to create GitHub issue" >&2
    echo "$ISSUE_URL" >&2
}

if [[ -n "$ISSUE_URL" ]]; then
    echo "GitHub issue created: ${ISSUE_URL}"
fi

# --- MCP Agent Mail notification (optional) ---
# Check if MCP Agent Mail tools are available via the agent environment
# This runs as a best-effort notification -- failure does not block the script
if command -v curl &>/dev/null; then
    AGENT_MAIL_URL="http://100.106.66.7:8765/api/"
    # Attempt to send high-priority message to CTO mailbox
    curl -s -X POST "${AGENT_MAIL_URL}send_message" \
        -H "Content-Type: application/json" \
        -d "{
            \"project_key\": \"$(pwd)\",
            \"from_agent\": \"judge-runner\",
            \"to_agent\": \"cto\",
            \"subject\": \"[${LABEL_PREFIX}] ${TASK_TITLE}\",
            \"body\": \"Judge evaluation for task ${TASK_ID} requires human review. Reason: ${REASON}. See GitHub issue: ${ISSUE_URL:-'(creation failed)'}\",
            \"thread_id\": \"${TASK_ID}\",
            \"importance\": \"high\"
        }" 2>/dev/null && echo "MCP Agent Mail notification sent" || echo "MCP Agent Mail notification skipped (server not available)"
fi

echo "Disagreement handler complete for task: ${TASK_ID}"
