#!/bin/bash
# Install OpenCode Safety Guard Plugins
# 
# Layer 1: Advisory Guard - warns but allows
# Layer 2: Safety Guard - blocks dangerous commands
#
# Usage: ./install.sh [--global]
#   --global: Install to ~/.config/opencode/ (user-level)
#   Without flag: Install to .opencode/ (project-level)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR=""
GLOBAL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --global)
            GLOBAL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "$GLOBAL" = true ]; then
    INSTALL_DIR="$HOME/.config/opencode"
    echo "Installing OpenCode plugins globally to: $INSTALL_DIR"
else
    INSTALL_DIR="$SCRIPT_DIR/../../.opencode"
    echo "Installing OpenCode plugins locally to: $INSTALL_DIR"
fi

# Create plugins directory
mkdir -p "$INSTALL_DIR/plugins"

# Copy plugin files
echo "Installing advisory-guard.js..."
cp "$SCRIPT_DIR/plugins/advisory-guard.js" "$INSTALL_DIR/plugins/advisory-guard.js"

echo "Installing safety-guard.js..."
cp "$SCRIPT_DIR/plugins/safety-guard.js" "$INSTALL_DIR/plugins/safety-guard.js"

# Copy custom guard thesaurus (if custom patterns wanted)
if [ -f "$SCRIPT_DIR/guard-thesaurus.json" ]; then
    echo "Installing guard-thesaurus.json..."
    cp "$SCRIPT_DIR/guard-thesaurus.json" "$INSTALL_DIR/guard-thesaurus.json"
fi

# Update opencode.json to include plugins
CONFIG_FILE="$INSTALL_DIR/opencode.json"
PLUGINS_ENTRY='"plugin": ["advisory-guard", "safety-guard"]'

if [ -f "$CONFIG_FILE" ]; then
    if ! grep -q "advisory-guard" "$CONFIG_FILE" 2>/dev/null; then
        echo "Updating $CONFIG_FILE to include plugins..."
        # Use node/json to merge properly if possible, otherwise append
        if command -v node >/dev/null 2>&1; then
            node -e "
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('$CONFIG_FILE', 'utf8'));
config.plugin = config.plugin || [];
if (!config.plugin.includes('advisory-guard')) config.plugin.push('advisory-guard');
if (!config.plugin.includes('safety-guard')) config.plugin.push('safety-guard');
fs.writeFileSync('$CONFIG_FILE', JSON.stringify(config, null, 2) + '\n');
"
        else
            echo "Warning: node not found, manual config update required"
        fi
    fi
else
    echo "Creating $CONFIG_FILE with plugin config..."
    cp "$SCRIPT_DIR/opencode.json" "$CONFIG_FILE"
fi

echo ""
echo "=============================================="
echo "OpenCode Safety Guard installed successfully!"
echo "=============================================="
echo ""
echo "Two-layer protection enabled:"
echo "  Layer 1: advisory-guard - warns but allows"
echo "  Layer 2: safety-guard - blocks dangerous commands"
echo ""
echo "Custom forbidden patterns:"
echo "  - pkill tmux"
echo ""
echo "Run 'opencode' to activate the plugins."
echo ""
