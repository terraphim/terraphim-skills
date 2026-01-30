#!/bin/bash
# Fix OpenCode skill paths after skills.sh installation
#
# skills.sh creates symlinks in ~/.config/opencode/skills/ (plural)
# but OpenCode expects ~/.config/opencode/skill/ (singular)
#
# This script creates the correct symlink for OpenCode compatibility.

set -e

OPENCODE_CONFIG="$HOME/.config/opencode"
AGENTS_SKILLS="$HOME/.agents/skills"

echo "Fixing OpenCode skill paths..."

# Check if skills.sh has installed skills
if [ ! -d "$AGENTS_SKILLS" ]; then
    echo "Error: ~/.agents/skills/ not found. Run 'npx skills add .' first."
    exit 1
fi

# Remove incorrect skills/ directory if it exists (created by skills.sh)
if [ -d "$OPENCODE_CONFIG/skills" ]; then
    echo "Removing incorrect skills/ directory (plural)..."
    rm -rf "$OPENCODE_CONFIG/skills"
fi

# Remove existing skill symlink or directory
if [ -L "$OPENCODE_CONFIG/skill" ]; then
    rm "$OPENCODE_CONFIG/skill"
elif [ -d "$OPENCODE_CONFIG/skill" ]; then
    echo "Backing up existing skill/ directory..."
    mv "$OPENCODE_CONFIG/skill" "$OPENCODE_CONFIG/skill.bak.$(date +%Y%m%d%H%M%S)"
fi

# Create correct symlink
ln -s "$AGENTS_SKILLS" "$OPENCODE_CONFIG/skill"
echo "Created: $OPENCODE_CONFIG/skill -> $AGENTS_SKILLS"

# Verify
echo ""
echo "Installed skills:"
ls "$OPENCODE_CONFIG/skill/" | head -10
echo "..."
echo ""
echo "OpenCode skill paths fixed successfully."
