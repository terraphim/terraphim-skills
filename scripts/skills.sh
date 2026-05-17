#!/usr/bin/env bash
# skills.sh -- Install Terraphim engineering skills into ~/.opencode/skills/
# Usage: curl -fsSL https://raw.githubusercontent.com/terraphim/terraphim-skills/main/scripts/skills.sh | bash
#   or:  bash scripts/skills.sh [--dest DIR] [--skill SKILL_NAME]
set -euo pipefail

DEST="${HOME}/.opencode/skills"
REPO="https://raw.githubusercontent.com/terraphim/terraphim-skills/main/skills"
SINGLE_SKILL=""
SKILLS=(
  acceptance-testing
  adf-orchestrate
  ai-config-management
  architecture
  code-review
  community-engagement
  debugging
  deterministic-rlm-review
  devops
  disciplined-design
  disciplined-implementation
  disciplined-quality-evaluation
  disciplined-research
  disciplined-specification
  disciplined-validation
  disciplined-verification
  documentation
  gitea-pagerank-workflow
  git-safety-guard
  gpui-components
  implementation
  judge
  kg-rlm-ingest
  learning-capture
  local-knowledge
  md-book
  open-source-contribution
  quality-gate
  quickwit-log-search
  requirements-traceability
  rust-ci-cd
  rust-development
  rust-observability
  rust-performance
  security-audit
  session-search
  structural-pr-review
  terraphim-hooks
  terraphim-rlm
  testing
  ubs-scanner
  visual-testing
)

usage() {
  echo "Usage: $0 [--dest DIR] [--skill SKILL_NAME]"
  echo ""
  echo "Options:"
  echo "  --dest DIR     Installation directory (default: ~/.opencode/skills)"
  echo "  --skill NAME   Install only a single skill"
  echo "  --list         List available skills and exit"
  echo "  --help         Show this help"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest)   DEST="$2"; shift 2 ;;
    --skill)  SINGLE_SKILL="$2"; shift 2 ;;
    --list)   printf '%s\n' "${SKILLS[@]}"; exit 0 ;;
    --help|-h) usage ;;
    *)        echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

install_skill() {
  local skill="$1"
  local dest_dir="${DEST}/${skill}"
  mkdir -p "$dest_dir"

  local url="${REPO}/${skill}/SKILL.md"
  local tmpfile
  tmpfile=$(mktemp)

  if command -v curl &>/dev/null; then
    curl -fsSL "$url" -o "$tmpfile" 2>/dev/null || { echo "  SKIP: ${skill} (not found)" && rm -f "$tmpfile" && return 1; }
  elif command -v wget &>/dev/null; then
    wget -q "$url" -O "$tmpfile" 2>/dev/null || { echo "  SKIP: ${skill} (not found)" && rm -f "$tmpfile" && return 1; }
  else
    echo "ERROR: Neither curl nor wget found" >&2
    rm -f "$tmpfile"
    exit 1
  fi

  mv "$tmpfile" "${dest_dir}/SKILL.md"
  echo "  OK: ${skill}"
  return 0
}

echo "Terraphim Engineering Skills v1.4.2"
echo "Installing to: ${DEST}"
echo ""

mkdir -p "$DEST"
INSTALLED=0
FAILED=0

if [[ -n "$SINGLE_SKILL" ]]; then
  if install_skill "$SINGLE_SKILL"; then
    INSTALLED=1
  else
    FAILED=1
  fi
else
  for skill in "${SKILLS[@]}"; do
    if install_skill "$skill"; then
      INSTALLED=$((INSTALLED + 1))
    else
      FAILED=$((FAILED + 1))
    fi
  done
fi

echo ""
echo "Done: ${INSTALLED} installed, ${FAILED} skipped"
echo "Skills are in: ${DEST}"
echo ""
echo "To use with OpenCode, skills are auto-discovered from ~/.opencode/skills/"
