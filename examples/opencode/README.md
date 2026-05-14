# OpenCode Safety Guard Plugins

Two-layer safety system for OpenCode that protects against destructive commands.

## Overview

| Layer | Plugin | Behavior |
|-------|--------|----------|
| 1 | `advisory-guard.js` | Warns about dangerous commands but allows execution |
| 2 | `safety-guard.js` | Blocks dangerous commands + captures for learning |

## Features

- **Dual Guard**: Uses both `terraphim-agent guard` and `dcg` (destructive_command_guard) as fallbacks
- **Learning Capture**: Blocked commands are captured for learning via `terraphim-agent learn`
- **Custom Patterns**: Add your own forbidden commands via `guard-thesaurus.json`
- **Fail-Open**: If guard tools fail, commands are allowed (safety first)

## Installation

### Quick Install (Global)

```bash
cd examples/opencode
./install.sh --global
```

### Local Install (Project)

```bash
cd examples/opencode
./install.sh
```

### Manual Install

1. Copy plugins to OpenCode plugins directory:
   ```bash
   mkdir -p ~/.config/opencode/plugins
   cp plugins/*.js ~/.config/opencode/plugins/
   ```

2. Add to `~/.config/opencode/opencode.json`:
   ```json
   {
     "plugin": ["advisory-guard", "safety-guard"]
   }
   ```

3. Restart OpenCode

## Custom Forbidden Patterns

Edit `guard-thesaurus.json` to add custom patterns:

```json
{
  "destructive_patterns": [
    "pkill tmux",
    "rm -rf /important"
  ],
  "reasons": {
    "pkill tmux": "Kills tmux sessions which may contain important work",
    "rm -rf /important": "Critical system path"
  }
}
```

## Commands Protected

### Blocked by Default

| Command | Reason |
|---------|--------|
| `git checkout -- <files>` | Discards uncommitted changes |
| `git reset --hard` | Destroys all uncommitted changes |
| `git clean -f` | Removes untracked files permanently |
| `git push --force` | Destroys remote history |
| `rm -rf` (non-temp) | Recursive deletion |
| `git stash drop` | Permanently deletes stashed changes |
| `git stash clear` | Deletes ALL stashed changes |
| `pkill tmux` | Kills tmux sessions (custom) |

### Explicitly Allowed

| Command | Why Safe |
|---------|----------|
| `git checkout -b <branch>` | Creates new branch |
| `git restore --staged` | Only unstages, doesn't discard |
| `git clean -n` | Preview/dry-run only |
| `rm -rf /tmp/...` | Temp directories are ephemeral |

## Testing

```bash
# Test a dangerous command (should be blocked)
echo "git reset --hard" | dcg --json
# {"decision":"block","reason":"git reset --hard destroys..."}

# Test with terraphim-agent
echo "git reset --hard" | terraphim-agent guard --json
# {"decision":"block","reason":"..."}

# Test learning capture
echo '{"command":"test","reason":"test","blocked":true}' | terraphim-agent learn hook
```

## Troubleshooting

### Plugins not loading?

Check OpenCode logs:
```bash
opencode --debug 2>&1 | grep -i plugin
```

### Verify plugins are installed:
```bash
ls -la ~/.config/opencode/plugins/
```

### Check config:
```bash
cat ~/.config/opencode/opencode.json
```

## Files

```
examples/opencode/
├── plugins/
│   ├── advisory-guard.js    # Layer 1: warns but allows
│   └── safety-guard.js      # Layer 2: blocks + learns
├── guard-thesaurus.json     # Custom forbidden patterns
├── opencode.json           # Config snippet
├── install.sh              # Installation script
└── README.md               # This file
```

## Related

- [terraphim-agent](https://github.com/terraphim/terraphim-agent) - CLI for knowledge graph
- [destructive_command_guard](https://github.com/Dicklesworthstone/destructive_command_guard) - Rust CLI for pattern matching
- [git-safety-guard skill](../skills/git-safety-guard/) - Claude Code version
