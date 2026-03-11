#!/usr/bin/env bash
# Create standard labels on a Gitea repository for the PageRank workflow.
# Usage: ./gitea-setup-labels.sh [--owner OWNER] [--repo REPO]
#
# Requires: tea CLI authenticated, GITEA_URL and GITEA_TOKEN set.

set -euo pipefail

OWNER="${1:?Usage: gitea-setup-labels.sh OWNER REPO}"
REPO="${2:?Usage: gitea-setup-labels.sh OWNER REPO}"

: "${GITEA_URL:?Set GITEA_URL}"
: "${GITEA_TOKEN:?Set GITEA_TOKEN}"

create_label() {
    local name="$1" color="$2" description="$3"
    # Strip leading # from color if present
    color="${color#\#}"
    curl -s -X POST \
        -H "Authorization: token $GITEA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$name\",\"color\":\"#$color\",\"description\":\"$description\"}" \
        "$GITEA_URL/api/v1/repos/$OWNER/$REPO/labels" \
        > /dev/null 2>&1 || true
    echo "  Created: $name"
}

echo "Setting up labels for $OWNER/$REPO..."

echo "Priority labels:"
create_label "priority/P0-critical" "FF0000" "Production down, security breach"
create_label "priority/P1-high"     "FF6600" "Must fix this sprint"
create_label "priority/P2-medium"   "FFCC00" "Should fix soon"
create_label "priority/P3-low"      "00CC00" "Nice to have"
create_label "priority/P4-minimal"  "0066CC" "Backlog, someday"

echo "Status labels:"
create_label "status/in-progress"   "1D76DB" "Agent actively working"
create_label "status/blocked"       "B60205" "Waiting on dependency"
create_label "status/in-review"     "5319E7" "PR open, awaiting review"

echo "Type labels:"
create_label "type/task"            "0075CA" "Implementation work"
create_label "type/bug"             "D73A4A" "Defect fix"
create_label "type/feature"         "A2EEEF" "New capability"
create_label "type/chore"           "EDEDED" "Maintenance, cleanup"

echo "Done. Labels created for $OWNER/$REPO."
