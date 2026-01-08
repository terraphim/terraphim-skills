#!/bin/bash
# Install Terraphim hooks for Claude Code
#
# This script:
# 1. Creates ~/.claude/hooks directory
# 2. Copies hook scripts
# 3. Makes them executable
# 4. Creates knowledge graph directory
# 5. Adds sample knowledge graph files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Terraphim hooks for Claude Code..."

# Create hooks directory
mkdir -p ~/.claude/hooks

# Copy hook scripts
cp "$SCRIPT_DIR/pre_tool_use.sh" ~/.claude/hooks/
cp "$SCRIPT_DIR/post_tool_use.sh" ~/.claude/hooks/

# Make executable
chmod +x ~/.claude/hooks/pre_tool_use.sh
chmod +x ~/.claude/hooks/post_tool_use.sh

echo "[OK] Hook scripts installed to ~/.claude/hooks/"

# Create knowledge graph directory
mkdir -p ~/.config/terraphim/docs/src/kg

# Create sample knowledge graph files
cat > ~/.config/terraphim/docs/src/kg/bun_install.md << 'EOF'
# bun install

Install dependencies using Bun package manager.

synonyms:: npm install, yarn install, pnpm install, npm i
EOF

cat > ~/.config/terraphim/docs/src/kg/bunx.md << 'EOF'
# bunx

Execute packages using Bun.

synonyms:: npx, pnpx, yarn dlx
EOF

cat > ~/.config/terraphim/docs/src/kg/bun_run.md << 'EOF'
# bun run

Run scripts using Bun.

synonyms:: npm run, yarn run, pnpm run
EOF

cat > ~/.config/terraphim/docs/src/kg/terraphim_ai.md << 'EOF'
# Terraphim AI

Terraphim AI - Knowledge graph powered development.

synonyms:: Claude Code, Claude Opus 4.5
EOF

echo "[OK] Knowledge graph files created in ~/.config/terraphim/docs/src/kg/"

# Check if terraphim-agent is installed
if command -v terraphim-agent >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/terraphim-agent" ]; then
    echo "[OK] terraphim-agent found"
else
    echo ""
    echo "[WARNING] terraphim-agent not found!"
    echo "Install from GitHub releases:"
    echo ""
    echo "  # macOS ARM64 (Apple Silicon)"
    echo "  gh release download --repo terraphim/terraphim-ai \\"
    echo "    --pattern \"terraphim-agent-aarch64-apple-darwin\" --dir /tmp"
    echo "  chmod +x /tmp/terraphim-agent-aarch64-apple-darwin"
    echo "  mv /tmp/terraphim-agent-aarch64-apple-darwin ~/.cargo/bin/terraphim-agent"
    echo ""
fi

echo ""
echo "Next steps:"
echo "1. Add hook configuration to ~/.claude/settings.local.json"
echo "   (see README.md for the JSON configuration)"
echo ""
echo "2. Test the installation:"
echo "   echo 'git reset --hard' | terraphim-agent guard --json"
echo "   # Should show: {\"decision\":\"block\",...}"
echo ""
echo "   cd ~/.config/terraphim && echo 'npm install' | terraphim-agent replace"
echo "   # Should show: bun install"
echo ""
echo "Installation complete!"
