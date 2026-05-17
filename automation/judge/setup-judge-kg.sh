#!/usr/bin/env bash
# setup-judge-kg.sh -- Install judge knowledge graph files for terraphim
# Part of the judge skill (Issue #23)
#
# Usage: setup-judge-kg.sh
#
# Copies judge KG files to ~/.config/terraphim/kg/ so terraphim-agent
# can use them for term normalization and validation. (terraphim-cli was
# renamed to terraphim-agent in v1.17.0.)
#
# Exit codes:
#   0 - Success
#   1 - Error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KG_SRC="${SCRIPT_DIR}/kg"
KG_DEST="${HOME}/.config/terraphim/kg"

if [[ ! -d "$KG_SRC" ]]; then
    echo "Error: KG source directory not found: ${KG_SRC}" >&2
    exit 1
fi

# Ensure destination exists
mkdir -p "$KG_DEST"

# Copy KG files (overwrite if exists)
COUNT=0
for f in "${KG_SRC}"/judge-*.md; do
    if [[ ! -f "$f" ]]; then
        continue
    fi
    fname=$(basename "$f")
    cp "$f" "${KG_DEST}/${fname}"
    echo "Installed: ${KG_DEST}/${fname}"
    COUNT=$((COUNT + 1))
done

if [[ $COUNT -eq 0 ]]; then
    echo "Warning: No judge-*.md files found in ${KG_SRC}" >&2
    exit 1
fi

echo "${COUNT} judge KG files installed."

# Set up LLM Enforcer role (loads KG files from ~/.config/terraphim/kg/)
# and verify with terraphim-agent search. Fail-open: missing binary or
# search returning no hits never blocks setup -- it just skips enrichment.
if command -v terraphim-agent &>/dev/null; then
    echo ""
    echo "Configuring LLM Enforcer role..."
    terraphim-agent setup --template llm-enforcer --path "$KG_DEST" --add-role 2>/dev/null || echo "  (LLM Enforcer role already exists or setup failed)"
    terraphim-agent roles select "LLM Enforcer" 2>/dev/null || true

    echo ""
    echo "Verification (terraphim-agent search):"
    if ! terraphim-agent search "factual correctness and actionability" --limit 5 2>/dev/null | grep -E '^\[[0-9]+\]'; then
        echo "  (no matches -- run: terraphim-agent setup --template llm-enforcer --path ~/.config/terraphim/kg --add-role)"
    fi
else
    echo ""
    echo "Note: terraphim-agent not installed -- judge will run without KG enrichment."
fi
