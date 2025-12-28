---
name: terraphim-hooks
description: |
  Knowledge graph-based text replacement using Terraphim hooks.
  Intercepts commands and text to apply transformations defined in the knowledge graph.
  Works with Claude Code PreToolUse hooks and Git prepare-commit-msg hooks.
license: Apache-2.0
---

# Terraphim Hooks

Use this skill when setting up or using Terraphim's knowledge graph-based text replacement capabilities through hooks.

## Overview

Terraphim hooks intercept text at key points (CLI commands, commit messages) and apply transformations using Aho-Corasick automata built from knowledge graph definitions.

**Key Components:**
- `terraphim-agent replace` - CLI command for text replacement
- PreToolUse hooks - Intercept Claude Code tool calls before execution
- Git hooks - Transform commit messages using prepare-commit-msg

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Knowledge Graph (docs/src/kg/)              │
│  ┌──────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ bun.md       │  │ bun_install.md   │  │ terraphim_ai.md  │  │
│  │ synonyms::   │  │ synonyms::       │  │ synonyms::       │  │
│  │ npm, yarn,   │  │ npm install,     │  │ Claude Code,     │  │
│  │ pnpm, npx    │  │ yarn install...  │  │ Claude Opus...   │  │
│  └──────────────┘  └──────────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │   Aho-Corasick Automata       │
              │   (LeftmostLongest matching)  │
              └───────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
   ┌──────────────────────┐       ┌──────────────────────┐
   │  PreToolUse Hook     │       │  Git Hook            │
   │  (npm → bun)         │       │  (Claude → Terraphim)│
   │                      │       │                      │
   │  Input: Bash command │       │  Input: Commit msg   │
   │  Output: Modified    │       │  Output: Modified    │
   └──────────────────────┘       └──────────────────────┘
```

## For Humans

### Quick Start

```bash
# Clone terraphim-ai repository
git clone https://github.com/terraphim/terraphim-ai
cd terraphim-ai

# Build the agent
cargo build -p terraphim_agent --release

# Install all hooks (recommended)
./scripts/install-terraphim-hooks.sh --easy-mode

# Test replacement
echo "npm install react" | ./target/release/terraphim-agent replace
# Output: bun install react
```

### Manual Installation

**Git Hook (prepare-commit-msg):**
```bash
cp scripts/hooks/prepare-commit-msg .git/hooks/
chmod +x .git/hooks/prepare-commit-msg
```

**Claude Code Hook (PreToolUse):**

Add to `.claude/settings.local.json`:
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/npm_to_bun_guard.sh"
      }]
    }]
  }
}
```

### CLI Usage

```bash
# Basic replacement
echo "npm install package" | terraphim-agent replace
# Output: bun install package

# With JSON output (for programmatic use)
echo "npm install" | terraphim-agent replace --json
# Output: {"result":"bun install","original":"npm install","replacements":1,"changed":true}

# Fail-open mode (returns original on error)
echo "npm install" | terraphim-agent replace --fail-open
```

### Adding Custom Replacements

Create markdown files in `docs/src/kg/`:

```markdown
# my_term

Description of the replacement term.

synonyms:: term_to_replace, another_term, third_term
```

**Example - Replace pytest with cargo test:**

Create `docs/src/kg/cargo_test.md`:
```markdown
# cargo test

Rust's built-in test runner using Cargo.

synonyms:: pytest, py.test, python -m pytest
```

## For AI Agents

### Detecting Terraphim Capabilities

Check for terraphim-agent availability:

```bash
# Check if agent is available
if command -v terraphim-agent >/dev/null 2>&1; then
    echo "Terraphim agent available"
elif [ -x "./target/release/terraphim-agent" ]; then
    AGENT="./target/release/terraphim-agent"
elif [ -x "$HOME/.cargo/bin/terraphim-agent" ]; then
    AGENT="$HOME/.cargo/bin/terraphim-agent"
fi
```

### Using Replacement in Hooks

**PreToolUse Hook Pattern:**

```bash
#!/bin/bash
# Read JSON input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Only process Bash commands
[ "$TOOL_NAME" != "Bash" ] && exit 0

# Perform replacement with fail-open
REPLACED=$(terraphim-agent replace --fail-open <<< "$COMMAND")

# Output modified tool_input if changed
if [ "$REPLACED" != "$COMMAND" ]; then
    echo "$INPUT" | jq --arg cmd "$REPLACED" '.tool_input.command = $cmd'
fi
```

**Git Hook Pattern:**

```bash
#!/bin/bash
COMMIT_MSG_FILE=$1

# Read original message
ORIGINAL=$(cat "$COMMIT_MSG_FILE")

# Replace using knowledge graph
REPLACED=$(terraphim-agent replace --fail-open <<< "$ORIGINAL")

# Write back if changed
if [ "$REPLACED" != "$ORIGINAL" ]; then
    echo "$REPLACED" > "$COMMIT_MSG_FILE"
fi
```

### Programmatic Usage (Rust)

```rust
use terraphim_hooks::{ReplacementService, HookResult};
use terraphim_types::Thesaurus;

// Load thesaurus from knowledge graph
let thesaurus = load_thesaurus_from_kg("docs/src/kg/");

// Create replacement service
let service = ReplacementService::new(thesaurus);

// Perform replacement
let result: HookResult = service.replace_fail_open("npm install react");
// result.result == "bun install react"
// result.changed == true
// result.replacements == 1
```

### MCP Tool Integration

The `replace_matches` MCP tool provides the same functionality:

```json
{
  "tool": "replace_matches",
  "arguments": {
    "text": "npm install react",
    "role": "Default"
  }
}
```

## Hook Types and Use Cases

| Hook Type | Trigger Point | Use Case |
|-----------|---------------|----------|
| PreToolUse | Before tool execution | Transform commands (npm→bun) |
| PostToolUse | After tool execution | Validate outputs |
| prepare-commit-msg | Before commit | Transform attribution |
| pre-commit | Before commit | Block unwanted patterns |

## Error Handling

Hooks use **fail-open** semantics:
- If terraphim-agent is not found: pass through unchanged
- If replacement fails: return original text
- Errors logged to stderr only in verbose mode

Enable verbose mode:
```bash
export TERRAPHIM_VERBOSE=1
```

## Knowledge Graph Format

Knowledge graph files use markdown with frontmatter:

```markdown
# term_name

Optional description.

synonyms:: synonym1, synonym2, synonym3
```

**Matching behavior:**
- Aho-Corasick with LeftmostLongest matching
- Longer patterns match before shorter ones
- Case-sensitive by default

## Validation

Test your hooks:

```bash
# Run test script
./scripts/test-terraphim-hooks.sh

# Manual test - PreToolUse
echo '{"tool_name":"Bash","tool_input":{"command":"npm install"}}' | .claude/hooks/npm_to_bun_guard.sh

# Manual test - Git hook
echo "Claude Code generated this" | terraphim-agent replace
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Hook not triggering | Check `.claude/settings.local.json` configuration |
| No replacement happening | Verify knowledge graph files exist in `docs/src/kg/` |
| Agent not found | Build with `cargo build -p terraphim_agent --release` |
| Permission denied | Run `chmod +x` on hook scripts |
| jq not found | Install jq: `brew install jq` or `apt install jq` |

## Related Skills

- `implementation` - For building custom hooks
- `testing` - For validating hook behavior
- `devops` - For CI/CD integration with hooks
