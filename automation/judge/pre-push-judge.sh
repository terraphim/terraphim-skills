#!/usr/bin/env bash
# pre-push-judge.sh -- Git pre-push hook that runs the judge on changed files
# Part of the judge skill (Issue #22)
#
# Installation:
#   ln -sf ../../automation/judge/pre-push-judge.sh .git/hooks/pre-push
#
# Or add to .claude/settings.local.json hooks:
#   "PreToolUse": [{ "matcher": "Bash(git push:*)", "hooks": [{ "type": "command", "command": "automation/judge/pre-push-judge.sh" }] }]
#
# Exit codes:
#   0 - Push allowed (accepted or no files to judge)
#   1 - Push blocked (rejected)
#   2 - Human review needed (creates GitHub issue)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/run-judge.sh"

# Get files changed between local and remote
CHANGED_FILES=$(git diff --name-only HEAD @{u} 2>/dev/null || git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")

if [[ -z "$CHANGED_FILES" ]]; then
    echo "[pre-push-judge] No changed files to evaluate"
    exit 0
fi

# Filter to evaluable files (skip binary, images, lockfiles)
EVAL_FILES=()
while IFS= read -r file; do
    case "$file" in
        *.md|*.rs|*.py|*.ts|*.js|*.json|*.toml|*.yaml|*.yml|*.sh)
            if [[ -f "$file" ]]; then
                EVAL_FILES+=("$file")
            fi
            ;;
    esac
done <<< "$CHANGED_FILES"

if [[ ${#EVAL_FILES[@]} -eq 0 ]]; then
    echo "[pre-push-judge] No evaluable files in push"
    exit 0
fi

echo "[pre-push-judge] Evaluating ${#EVAL_FILES[@]} files..."

# Get task context from latest commit
TASK_ID=$(git log -1 --pretty=format:"%s" | grep -oP '#\d+' | head -1 | tr -d '#' || echo "unknown")
TASK_DESC=$(git log -1 --pretty=format:"%s")

# Run judge
"$RUNNER" \
    --task-id "$TASK_ID" \
    --description "$TASK_DESC" \
    "${EVAL_FILES[@]}"

EXIT_CODE=$?

case $EXIT_CODE in
    0)
        echo "[pre-push-judge] PASSED -- push allowed"
        ;;
    1)
        echo "[pre-push-judge] FAILED -- push blocked"
        echo "Fix the issues and try again, or override with: git push --no-verify"
        ;;
    2)
        echo "[pre-push-judge] NEEDS REVIEW -- check GitHub issues"
        echo "Push is allowed but human review is pending"
        exit 0  # Allow push but flag for review
        ;;
esac

exit $EXIT_CODE
