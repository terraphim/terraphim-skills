# Best Practices: Building Skills and Hooks for Claude Code, Codex, and OpenCode

**Status**: Draft
**Author**: Research Agent
**Date**: 2026-01-09

## Executive Summary

This document synthesizes best practices for building skills and hooks across three major AI coding platforms: Claude Code (Anthropic), Codex CLI (OpenAI), and OpenCode (OpenCode.ai). While each platform has unique characteristics, they share common patterns in skill structure, hook implementation, and integration strategies. Understanding these patterns enables cross-platform skill development with minimal code duplication.

## Platform Overview

### Claude Code (Anthropic)

**Installation**: Plugin marketplace
**Skill Location**: Plugin repositories with `.claude-plugin/` directory
**Triggering**: Automatic selection or explicit invocation
**Key Features**:
- Plugin-based architecture with marketplace
- Built-in hook system (PreToolUse, PostToolUse)
- Rich skill metadata with YAML frontmatter
- Subagent system with session management
- User and project-level configuration

### Codex CLI (OpenAI)

**Installation**: npm, brew, or direct binary
**Skill Location**: `~/.codex/skills/`, `.codex/skills/`, or `/etc/codex/skills/`
**Triggering**: Automatic discovery with explicit `$skill-name` or implicit selection
**Key Features**:
- Skills discovered by precedence (project > repo > user > system)
- Simple markdown-based skill files
- Agent definitions in separate AGENTS.md files
- Minimal metadata requirements

### OpenCode (OpenCode.ai)

**Installation**: Manual copy to config directory
**Skill Location**: `~/.config/opencode/skill/` or `.opencode/skill/`
**Triggering**: Automatic discovery with on-demand invocation
**Key Features**:
- Compatible with Claude Code's `.claude/skills/` path
- Single skill/ directory structure
- Agent definitions in AGENTS.md
- Cross-platform compatibility

## Table of Contents

1. [Skill Structure and Format](#skill-structure-and-format)
2. [Skill Development Best Practices](#skill-development-best-practices)
3. [Hook Types and Implementation](#hook-types-and-implementation)
4. [Hook Development Patterns](#hook-development-patterns)
5. [Cross-Platform Compatibility](#cross-platform-compatibility)
6. [Security and Safety](#security-and-safety)
7. [Testing Strategies](#testing-strategies)
8. [Documentation Standards](#documentation-standards)
9. [Installation and Distribution](#installation-and-distribution)
10. [Common Anti-Patterns](#common-anti-patterns)
11. [Migration and Upgrades](#migration-and-upgrades)
12. [Performance Considerations](#performance-considerations)
13. [Community and Maintenance](#community-and-maintenance)

---

## Skill Structure and Format

### Claude Code Skills

**File Structure**:
```
.claude-plugin/
├── plugin.json          # Plugin metadata
├── marketplace.json      # Marketplace listing
└── skills/
    ├── skill-name/
    │   └── SKILL.md     # Skill definition
    └── another-skill/
        └── SKILL.md
```

**SKILL.md Format**:
```markdown
---
name: skill-name
description: |
  Brief description (1-2 lines).
  When to use it. What it produces.
license: Apache-2.0
---

[500+ word system prompt with:]
- Core principles
- Primary responsibilities
- Technology preferences
- Output formats
- Constraints
- Success metrics
```

**Required Fields**:
- `name`: kebab-case identifier
- `description`: When to use (3-4 detailed examples with context)
- `license`: License identifier (e.g., Apache-2.0)

**Best Practices**:
1. **Descriptive Names**: Use action-oriented, specific names (e.g., `rust-performance` not `optimization`)
2. **Rich Descriptions**: Include 3-4 detailed usage examples with context/commentary
3. **Lengthy System Prompts**: 500+ words for complex skills; 300+ for simple skills
4. **Technology Constraints**: Explicitly list preferred technologies and patterns
5. **Success Metrics**: Define measurable outcomes

### Codex CLI Skills

**File Structure**:
```
~/.codex/skills/
├── skill-name.md
├── another-skill.md
└── AGENTS.md (optional)
```

**Skill Format**:
```markdown
---
name: skill-name
description: Brief description
---

[Skill content - less strict on length]
```

**Discovery Precedence** (highest to lowest):
1. `.codex/skills/` in current directory
2. `.codex/skills/` at repository root
3. `~/.codex/skills/` (user home)
4. `/etc/codex/skills/` (system-wide)

**Best Practices**:
1. **Keep It Simple**: Minimal metadata, focus on content
2. **File Naming**: Use kebab-case for consistency
3. **Explicit Invocation**: Support `$skill-name` prefix
4. **Agent Definitions**: Separate AGENTS.md for complex skills

### OpenCode Skills

**File Structure**:
```
~/.config/opencode/skill/
├── skill-name.md
├── another-skill.md
└── AGENTS.md (optional)
```

**Compatibility**: Also supports Claude Code's `.claude/skills/` path

**Best Practices**:
1. **Cross-Platform Compatibility**: Structure for both OpenCode and Claude Code
2. **Unified Agents**: Single AGENTS.md for all skills
3. **Simple Discovery**: Leverage automatic scanning

---

## Skill Development Best Practices

### 1. Single Responsibility

**Good**: One skill per capability
```markdown
# testing.md - Only testing strategies
# security-audit.md - Only security reviews
```

**Bad**: Multiple capabilities in one skill
```markdown
# quality.md - Testing + security + code review (too broad)
```

### 2. Clear Triggering Conditions

**Claude Code** (from terraphim-hooks):
```markdown
description: |
  Use this skill when setting up or using Terraphim's knowledge graph-based
  text replacement capabilities through hooks.

  Examples:
  - "Set up text replacement for npm → bun"
  - "Transform all Claude Code attributions to Terraphim AI"
  - "Create hooks for command replacement"
```

### 3. Rich Examples with Context

**Good** (from architecture skill):
```markdown
Example 1: API Design
Context: Need to design a RESTful API for user authentication
Trigger: "Design a plugin system for our application"
Output: ADR document with context and decision

Example 2: Module Structure
Context: Refactoring database layer for better separation
Trigger: "We need to refactor the database layer"
Output: Module structure diagram, public API definitions
```

### 4. Explicit Constraints

**From architecture skill**:
```markdown
## Constraints

- Never write implementation code
- Always provide rationale for decisions
- Consider backward compatibility
- Document breaking changes explicitly
- Design for testability
```

### 5. Success Metrics

**From testing skill**:
```markdown
## Success Metrics

- All tests pass consistently
- Coverage meets project requirements (80% min, 90% target)
- No flaky tests in CI
- Benchmarks show no regressions
```

### 6. Technology Preferences

**From architecture skill**:
```markdown
## Technology Preferences

**Languages & Runtimes:**
- Rust as primary language (safety, performance, WASM target)
- TypeScript for frontend and tooling
- WebAssembly for portable, sandboxed execution

**Infrastructure:**
- Cloudflare Workers for edge computing
- Fluvio for event streaming
- Redis for caching and feature stores
```

---

## Hook Types and Implementation

### Claude Code Hooks

**Configuration Location**: `~/.claude/settings.local.json`

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/pre_tool_use.sh"
      }]
    }],
    "PostToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/post_tool_use.sh"
      }]
    }]
  }
}
```

### Hook Types

#### PreToolUse Hook

**Trigger**: Before any tool execution
**Input**: JSON with `tool_name` and `tool_input`
**Output**: JSON with `hookSpecificOutput`

**Use Cases**:
- Validate commands before execution
- Transform commands (text replacement)
- Block dangerous operations
- Log command execution

**Example Input**:
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "git reset --hard"
  }
}
```

**Example Output (Block)**:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "BLOCKED: git reset --hard destroys uncommitted changes"
  }
}
```

**Example Output (Modify)**:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "updatedInput": {
      "command": "bun install react"
    }
  }
}
```

#### PostToolUse Hook

**Trigger**: After tool execution completes
**Input**: JSON with tool name, input, output, and result
**Output**: Optional JSON modifications

**Use Cases**:
- Process tool results
- Validate outputs
- Trigger downstream actions
- Update knowledge base

**Example Input**:
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "cargo test"
  },
  "tool_output": "test result: ...",
  "tool_result": {
    "success": true
  }
}
```

### Git Hooks

**Types**:
- `prepare-commit-msg`: Modify commit messages before saving
- `pre-commit`: Validate changes before commit
- `post-commit`: Actions after commit

**Example**: prepare-commit-msg hook
```bash
#!/bin/bash
COMMIT_MSG_FILE=$1
ORIGINAL=$(cat "$COMMIT_MSG_FILE")
REPLACED=$(terraphim-agent replace --fail-open <<< "$ORIGINAL")

if [ "$REPLACED" != "$ORIGINAL" ]; then
  echo "$REPLACED" > "$COMMIT_MSG_FILE"
fi
```

---

## Hook Development Patterns

### 1. Fail-Open Semantics

**Critical Pattern**: Always allow execution if hook fails

**Good** (from pre_tool_use.sh):
```bash
# Fail-open if agent not found
[ -z "$AGENT" ] && exit 0

# Replace with fail-open
REPLACED=$(terraphim-agent replace --fail-open <<< "$COMMAND")
```

**Bad** (hard fail):
```bash
# Agent MUST be present or hook fails
[ -z "$AGENT" ] && exit 1
```

**Rationale**: Hooks should never block legitimate development work

### 2. Matcher-Based Filtering

**Pattern**: Filter by tool type before processing

```bash
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only process Bash commands
[ "$TOOL_NAME" != "Bash" ] && exit 0
[ -z "$COMMAND" ] && exit 0
```

### 3. JSON Pipeline Processing

**Pattern**: Process JSON input/output with jq

```bash
# Read JSON input
INPUT=$(cat)

# Extract fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Output JSON response
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "$REASON"
  }
}
EOF
```

### 4. Multi-Stage Processing

**Pattern**: Combine multiple hook responsibilities

**From terraphim pre_tool_use.sh**:
```bash
# Step 1: Git Safety Guard - block destructive commands
GUARD_RESULT=$($AGENT guard --json <<< "$COMMAND" 2>/dev/null || echo '{"decision":"allow"}')

if echo "$GUARD_RESULT" | jq -e '.decision == "block"' >/dev/null 2>&1; then
    # Block and exit
    ...
fi

# Step 2: Knowledge graph text replacement
$AGENT graph --role "Terraphim Engineer" >/dev/null 2>&1 || true
NEW_COMMAND=$(echo "$COMMAND" | $AGENT replace --role "Terraphim Engineer" 2>/dev/null || echo "$COMMAND")

if [ "$NEW_COMMAND" != "$COMMAND" ]; then
    # Output modified command
    ...
fi

# Step 3: Fallback handler
$AGENT hook --hook-type pre-tool-use --json <<< "$INPUT" 2>/dev/null
```

### 5. Pattern Matching for Safety

**Pattern**: Regex-based allow/block lists

**From git-safety-guard**:
```rust
// Destructive patterns
const DESTRUCTIVE_PATTERNS: &[&str] = &[
    r"git\s+checkout\s+--\s+",  // Discards changes
    r"git\s+reset\s+--hard",     // Destroys work
    r"rm\s+-rf\s+[^/\s]",       // Non-temp deletion
];

// Safe patterns (override)
const SAFE_PATTERNS: &[&str] = &[
    r"git\s+checkout\s+-b\s+",   // Creates branch
    r"git\s+checkout\s+--orphan", // Creates orphan
    r"rm\s+-rf\s+/tmp/",         // Temp directory
];
```

### 6. Exit Code Handling

**Pattern**: Always exit 0; signal errors through output

```bash
# Process command
if [ "$BLOCKED" = "true" ]; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "$REASON"
  }
}
EOF
fi

# Always exit 0
exit 0
```

---

## Cross-Platform Compatibility

### Strategy: Single Source of Truth

**Pattern**: Maintain skills in one location, adapt for platforms

```bash
# Directory structure for cross-platform skills
skills/
├── testing/
│   ├── SKILL.md           # Claude Code format (rich)
│   ├── skill.md          # Codex format (minimal)
│   └── examples/
│       └── test_strategy.md
```

### Conversion Strategy

**Claude Code → Codex**:
```python
# Strip frontmatter, convert description
def convert_claude_to_codex(skill_path):
    content = read_file(skill_path)
    # Extract frontmatter
    name, description = extract_frontmatter(content)
    # Create minimal version
    minimal = f"---\nname: {name}\ndescription: {description}\n---\n\n"
    minimal += content.split("---\n")[2]  # Main content
    return minimal
```

**Claude Code → OpenCode**:
```python
# Direct copy (compatible structure)
def deploy_to_opencode(skill_path):
    copy_file(skill_path, "~/.config/opencode/skill/")
```

### Compatibility Checklist

- [ ] Skill names use kebab-case (all platforms)
- [ ] Description fits single line (Codex limit)
- [ ] No platform-specific commands in skill content
- [ ] File permissions set correctly (chmod +x for hooks)
- [ ] Dependencies declared (jq, terraphim-agent, etc.)
- [ ] Fail-open semantics implemented
- [ ] JSON I/O standardized

### Platform-Specific Adaptations

**Claude Code Only**:
- Plugin metadata (plugin.json, marketplace.json)
- Rich frontmatter with license
- 500+ word system prompts

**Codex Only**:
- AGENTS.md for complex agent definitions
- Minimal frontmatter
- Explicit `$skill-name` prefix support

**OpenCode Only**:
- Agent definitions in AGENTS.md
- Compatible with Claude Code paths
- Manual installation to ~/.config/

---

## Security and Safety

### 1. Fail-Open Semantics

**Critical Security Principle**: Hooks must never block legitimate work

**Implementation**:
```bash
# Check agent availability
if ! command -v terraphim-agent >/dev/null 2>&1; then
    exit 0  # Pass through unchanged
fi

# Process with error handling
RESULT=$(terraphim-agent guard --json <<< "$COMMAND" 2>/dev/null || echo '{"decision":"allow"}')
```

### 2. Input Sanitization

**Pattern**: Sanitize all user input

```bash
# Use printf to avoid command injection
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
printf '%s' "$COMMAND" | terraphim-agent replace
```

### 3. Path Validation

**Pattern**: Validate file paths before operations

```bash
# Validate path is safe
PATH=$(echo "$INPUT" | jq -r '.tool_input.path')

if [[ "$PATH" == *"../"* ]] || [[ "$PATH" == *"/"* ]]; then
    echo '{"error":"Invalid path"}'
    exit 0
fi
```

### 4. Command Whitelisting

**Pattern**: Explicitly allow safe commands

```rust
// Safe git commands
const SAFE_GIT_COMMANDS: &[&str] = &[
    "git status",
    "git log",
    "git show",
    "git diff",
    "git branch",
];

// Only allow whitelisted commands
if !SAFE_GIT_COMMANDS.contains(&cmd) {
    return GuardResult::block("Command not whitelisted");
}
```

### 5. Audit Logging

**Pattern**: Log all hook decisions

```bash
# Log decision
if [ "$DECISION" = "block" ]; then
    echo "[$(date)] BLOCKED: $COMMAND - $REASON" >> ~/.claude/hook-audit.log
fi
```

### 6. Dependency Management

**Pattern**: Declare and validate dependencies

```bash
# Check dependencies
check_deps() {
    local deps=("jq" "terraphim-agent")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Missing dependency: $dep"
            exit 0  # Fail-open
        fi
    done
}
check_deps
```

### Security Incident Learning

**From git-safety-guard skill**:

> On December 17, 2025, an AI agent ran `git checkout --` on multiple files containing hours of uncommitted work from another agent. This destroyed work instantly and silently. The files were recovered from a dangling Git object via `git fsck --lost-found`, but it was a close call.
>
> **Instructions alone don't prevent accidents. Mechanical enforcement does.**

---

## Testing Strategies

### 1. Unit Testing Hooks

**Test individual functions**:

```bash
#!/bin/bash
# test_guard_patterns.sh

# Test blocked command
assert_blocked "git checkout -- file.txt"

# Test allowed command
assert_allowed "git checkout -b new-branch"

# Test safe pattern override
assert_allowed "rm -rf /tmp/cache"
```

### 2. Integration Testing

**Test hook with actual tool calls**:

```bash
#!/bin/bash
# test_pre_tool_use.sh

# Test blocking
echo '{"tool_name":"Bash","tool_input":{"command":"git reset --hard"}}' | \
  ~/.claude/hooks/pre_tool_use.sh

# Test modification
echo '{"tool_name":"Bash","tool_input":{"command":"npm install"}}' | \
  ~/.claude/hooks/pre_tool_use.sh

# Test pass-through
echo '{"tool_name":"Read","tool_input":{"filePath":"README.md"}}' | \
  ~/.claude/hooks/pre_tool_use.sh
```

### 3. Manual Testing

**From terraphim-hooks**:

```bash
# Test guard command
echo "git reset --hard" | terraphim-agent guard --json
# Expected: {"decision":"block","reason":"..."}

# Test replacement (from config directory)
cd ~/.config/terraphim && echo "npm install react" | terraphim-agent replace
# Expected: bun install react

# Test hook script
echo '{"tool_name":"Bash","tool_input":{"command":"git checkout -- file.txt"}}' | \
  ~/.claude/hooks/pre_tool_use.sh
# Expected: BLOCKED message
```

### 4. Edge Case Testing

**Test boundary conditions**:

```bash
# Empty input
echo '{}' | ~/.claude/hooks/pre_tool_use.sh

# Null fields
echo '{"tool_name":"Bash","tool_input":{"command":""}}' | \
  ~/.claude/hooks/pre_tool_use.sh

# Missing tool_name
echo '{"tool_input":{"command":"test"}}' | ~/.claude/hooks/pre_tool_use.sh

# Special characters
echo '{"tool_name":"Bash","tool_input":{"command":"echo \"$(whoami)\"}}' | \
  ~/.claude/hooks/pre_tool_use.sh
```

### 5. Performance Testing

**Test hook latency**:

```bash
#!/bin/bash
# benchmark_hook.sh

for i in {1..100}; do
    time echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | \
      ~/.claude/hooks/pre_tool_use.sh > /dev/null
done
```

### 6. Flakiness Testing

**Test for non-deterministic behavior**:

```bash
#!/bin/bash
# test_determinism.sh

for i in {1..50}; do
    RESULT=$(echo "test" | hook.sh)
    echo "$RESULT" >> results.log
done

# Check all results are identical
uniq results.log | wc -l  # Should be 1
```

---

## Documentation Standards

### 1. SKILL.md Structure

**Template** (from disciplined-research):

```markdown
---
name: skill-name
description: |
  Brief description.
  When to use it (3-4 examples with context).
  What it produces.
license: Apache-2.0
---

## Core Principles

1. [Principle 1]
2. [Principle 2]

## Primary Responsibilities

1. [Responsibility 1]
2. [Responsibility 2]

## Technology Preferences

[Preferred technologies and patterns]

## Output Formats

[Example outputs with templates]

## Constraints

- [Constraint 1]
- [Constraint 2]

## Success Metrics

- [Metric 1]
- [Metric 2]
```

### 2. Hook Script Documentation

**Template** (from pre_tool_use.sh):

```bash
#!/bin/bash
# Hook Name - Brief description
#
# Features:
# 1. [Feature 1]
# 2. [Feature 2]
#
# Installation:
#   1. Copy to ~/.claude/hooks/hook_name.sh
#   2. chmod +x ~/.claude/hooks/hook_name.sh
#   3. Add hook config to ~/.claude/settings.local.json
#   4. Install dependencies
#
# Dependencies: jq, terraphim-agent
# Author: Your Name
# License: Apache-2.0
```

### 3. README.md for Skills

**Template**:

```markdown
# Skill Name

Brief description.

## Installation

### Claude Code
```bash
claude plugin install skill-name@marketplace
```

### Codex
```bash
cp skill-name.md ~/.codex/skills/
```

### OpenCode
```bash
cp skill-name.md ~/.config/opencode/skill/
```

## Usage

### Example 1: [Use case]
```
[Example command]
```

### Example 2: [Use case]
```
[Example command]
```

## Configuration

[Configuration options]

## Troubleshooting

| Issue | Solution |
|-------|----------|
| [Issue 1] | [Solution 1] |
```

### 4. Agent Documentation (AGENTS.md)

**Template**:

```markdown
# Agent Definitions

## agent-name

**Purpose**: [Purpose]

**Skills Used**:
- [Skill 1]
- [Skill 2]

**Workflow**:
1. [Step 1]
2. [Step 2]

**Example Usage**:
```bash
codex "[prompt]"
```
```

### 5. Inline Code Documentation

**Pattern**: Document with examples

```bash
# Step 1: Check command safety
# Uses regex patterns to identify destructive operations
# Example: "git checkout --" discards uncommitted work
GUARD_RESULT=$($AGENT guard --json <<< "$COMMAND")
```

---

## Installation and Distribution

### 1. Claude Code Marketplace

**Plugin Structure**:
```
plugin-name/
├── .claude-plugin/
│   ├── plugin.json          # Plugin metadata
│   └── marketplace.json      # Marketplace listing
├── skills/
│   └── skill-name/
│       └── SKILL.md
└── README.md
```

**plugin.json**:
```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "Plugin description",
  "author": {
    "name": "Author Name",
    "url": "https://github.com/author"
  },
  "homepage": "https://github.com/author/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "Apache-2.0",
  "keywords": ["keyword1", "keyword2"]
}
```

**marketplace.json**:
```json
{
  "name": "marketplace-name",
  "owner": {
    "name": "Owner Name",
    "email": "owner@example.com"
  },
  "metadata": {
    "description": "Marketplace description",
    "version": "1.0.0"
  },
  "plugins": [{
    "name": "plugin-name",
    "source": "./",
    "description": "Plugin description",
    "version": "1.0.0",
    "author": {
      "name": "Author Name"
    },
    "category": "engineering"
  }]
}
```

**Installation**:
```bash
# Add marketplace
claude plugin marketplace add owner/marketplace-name

# Install plugin
claude plugin install plugin-name@marketplace-name
```

### 2. Codex CLI Distribution

**Installation Script**:
```bash
#!/bin/bash
# install.sh

# Copy skills
mkdir -p ~/.codex/skills/
cp skills/*.md ~/.codex/skills/

# Copy hooks
mkdir -p ~/.codex/hooks/
cp hooks/*.sh ~/.codex/hooks/
chmod +x ~/.codex/hooks/*.sh

echo "Installation complete"
```

**Usage**:
```bash
# Clone repository
git clone https://github.com/owner/skills.git

# Run installer
cd skills && ./install.sh
```

### 3. OpenCode Distribution

**Installation Script**:
```bash
#!/bin/bash
# install.sh

# Copy skills
mkdir -p ~/.config/opencode/skill/
cp skill/*.md ~/.config/opencode/skill/

echo "OpenCode skills installed"
```

### 4. Cross-Platform Installer

**Unified installer for all platforms**:

```bash
#!/bin/bash
# install.sh

PLATFORMS=("claude" "codex" "opencode")

install_claude() {
    echo "Installing for Claude Code..."
    mkdir -p .claude/skills/
    cp skills/*.md .claude/skills/
}

install_codex() {
    echo "Installing for Codex..."
    mkdir -p ~/.codex/skills/
    cp skills/*.md ~/.codex/skills/
}

install_opencode() {
    echo "Installing for OpenCode..."
    mkdir -p ~/.config/opencode/skill/
    cp skill/*.md ~/.config/opencode/skill/
}

# Parse arguments
for platform in "$@"; do
    if [[ " ${PLATFORMS[@]} " =~ " ${platform} " ]]; then
        "install_${platform}"
    fi
done

echo "Installation complete"
```

**Usage**:
```bash
./install.sh claude codex opencode
```

---

## Common Anti-Patterns

### 1. Monolithic Skills

**Bad**: One skill doing everything
```markdown
# quality.md
Handles testing, security, performance, documentation, deployment...
```

**Good**: Focused, single-purpose skills
```markdown
# testing.md - Only testing
# security-audit.md - Only security
# performance.md - Only performance
```

### 2. Hard Fail on Dependency Missing

**Bad**:
```bash
if ! command -v jq >/dev/null 2>&1; then
    echo "jq not found"
    exit 1  # Blocks all operations!
fi
```

**Good**:
```bash
if ! command -v jq >/dev/null 2>&1; then
    exit 0  # Fail-open
fi
```

### 3. Insufficient Context in Descriptions

**Bad**:
```markdown
description: "Testing skill"
```

**Good** (from architecture skill):
```markdown
description: |
  System architecture design for Rust/WebAssembly projects. Creates ADRs,
  designs APIs, plans module structures, and documents architectural decisions.
  Never writes implementation code - focuses purely on design and documentation.

  Example 1: Designing a plugin system for extensibility
  Example 2: Refactoring database layer for better separation
  Example 3: Planning authentication with ADR
```

### 4. No Error Handling

**Bad**:
```bash
RESULT=$(terraphim-agent guard --json <<< "$COMMAND")
```

**Good**:
```bash
RESULT=$(terraphim-agent guard --json <<< "$COMMAND" 2>/dev/null || echo '{"decision":"allow"}')
```

### 5. Platform-Specific Commands in Skills

**Bad**:
```markdown
Use `claude plugin install` to install
```

**Good**:
```markdown
**Claude Code**: `claude plugin install`
**Codex**: Copy to ~/.codex/skills/
**OpenCode**: Copy to ~/.config/opencode/skill/
```

### 6. Vague Success Criteria

**Bad**:
```markdown
## Success Metrics
- Code is good
- Tests pass
```

**Good** (from testing skill):
```markdown
## Success Metrics

- All tests pass consistently
- Coverage meets project requirements (80% min, 90% target)
- No flaky tests in CI
- Benchmarks show no regressions
- Test suite completes in reasonable time
- All error paths tested
- Edge cases explicitly covered
```

### 7. No Hook Output

**Bad**:
```bash
# Process silently
terraphim-agent guard --json <<< "$COMMAND"
exit 0
```

**Good**:
```bash
RESULT=$(terraphim-agent guard --json <<< "$COMMAND")
if echo "$RESULT" | jq -e '.decision == "block"' >/dev/null; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "$(echo "$RESULT" | jq -r '.reason')"
  }
}
EOF
fi
exit 0
```

---

## Migration and Upgrades

### 1. Versioning Strategy

**Semantic Versioning**:
```
MAJOR.MINOR.PATCH
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes (backward compatible)
```

**plugin.json**:
```json
{
  "version": "2.1.0"
}
```

### 2. Breaking Change Handling

**Document breaking changes**:
```markdown
# CHANGELOG.md

## [2.0.0] - 2026-01-09

### Breaking Changes
- Skill output format changed from JSON to YAML
- Hook input now requires `tool_id` field

### Migration Guide
```bash
# Convert old format
convert-old-to-new.sh
```
```

### 3. Backward Compatibility

**Support multiple formats**:

```bash
# Parse both old and new formats
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .tool_id // empty')
```

### 4. Deprecation Notice

**Warn about deprecated features**:

```bash
if [ -z "$NEW_FORMAT" ]; then
    echo "Warning: Old format detected. Please upgrade to version 2.0.0" >&2
fi
```

### 5. Automated Migration

**Provide migration scripts**:

```bash
#!/bin/bash
# migrate-v1-to-v2.sh

echo "Migrating skills from v1 to v2..."

# Update skill files
for skill in skills/*.md; do
    # Update format
    sed -i.bak 's/old_format/new_format/g' "$skill"
    rm "$skill.bak"
done

echo "Migration complete. Please test your skills."
```

---

## Performance Considerations

### 1. Hook Latency

**Target**: Hooks should complete in < 100ms

**Optimization Techniques**:

1. **Cache External Calls**:
```bash
# Cache knowledge graph
if [ ! -f "/tmp/kg_cache.txt" ] || [ $(find /tmp/kg_cache.txt -mmin +5) ]; then
    $AGENT graph --role "Terraphim Engineer" > /tmp/kg_cache.txt
fi
```

2. **Avoid Redundant Operations**:
```bash
# Bad: Build graph every time
NEW_COMMAND=$(echo "$COMMAND" | $AGENT replace)

# Good: Build once, reuse
$AGENT graph >/dev/null 2>&1 || true
NEW_COMMAND=$(echo "$COMMAND" | $AGENT replace)
```

3. **Use Efficient Tools**:
```bash
# Use jq for JSON (faster than python)
RESULT=$(echo "$INPUT" | jq -r '.tool_name')

# Use grep for pattern matching (faster than regex)
if echo "$COMMAND" | grep -q "git checkout --"; then
    ...
fi
```

### 2. Memory Usage

**Guidelines**:
- Hook scripts should use < 10MB
- Skills should load minimal data

**Optimization**:

```bash
# Process line by line (low memory)
while read line; do
    process "$line"
done <<< "$INPUT"

# Not: Load entire file into memory
CONTENT=$(cat large_file.txt)
process "$CONTENT"
```

### 3. Startup Time

**Lazy Load Dependencies**:

```bash
# Bad: Load all dependencies upfront
load_all_dependencies

# Good: Load only when needed
if [ "$NEED_JQ" = "true" ]; then
    check_jq_available
fi
```

### 4. Network Calls

**Minimize External Requests**:

```bash
# Bad: Fetch data every hook call
DATA=$(curl -s https://api.example.com/data)

# Good: Cache and refresh periodically
if [ ! -f "/tmp/api_cache.json" ] || [ $(find /tmp/api_cache.json -mmin +60) ]; then
    curl -s https://api.example.com/data > /tmp/api_cache.json
fi
DATA=$(cat /tmp/api_cache.json)
```

### 5. Benchmarking

**Measure performance**:

```bash
#!/bin/bash
# benchmark.sh

for i in {1..100}; do
    START=$(date +%s%N)
    echo "test" | hook.sh
    END=$(date +%s%N)
    echo $((END - START)) >> latency.log
done

# Calculate average
awk '{sum+=$1} END {print sum/NR}' latency.log
```

---

## Community and Maintenance

### 1. Contributing Guidelines

**Template** (CONTRIBUTING.md):

```markdown
# Contributing

## Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes

## Skill Guidelines

1. Follow existing SKILL.md format
2. Include 500+ word system prompts
3. Provide 3-4 usage examples with context
4. Test on all supported platforms

## Hook Guidelines

1. Implement fail-open semantics
2. Handle all error cases
3. Document dependencies
4. Include tests

## Testing

```bash
# Run tests
./scripts/test-all.sh

# Test manual installation
./scripts/test-install.sh
```

## Submitting

1. Update CHANGELOG.md
2. Create pull request
3. Link to related issues
```

### 2. Issue Templates

**Bug Report Template**:

```markdown
## Bug Report

**Platform**: Claude Code / Codex / OpenCode
**Version**: X.Y.Z
**Skill/Hook**: skill-name

### Description
[Bug description]

### Steps to Reproduce
1. [Step 1]
2. [Step 2]

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Environment
- OS: [OS version]
- CLI version: [version]
- Dependencies: [jq, terraphim-agent versions]
```

**Feature Request Template**:

```markdown
## Feature Request

**Platform**: Claude Code / Codex / OpenCode
**Skill/Hook**: skill-name

### Description
[Feature description]

### Use Case
[Why this is needed]

### Proposed Solution
[Suggested implementation]

### Alternatives
[Other approaches considered]
```

### 3. Release Checklist

**Before releasing**:

- [ ] All tests pass on all platforms
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped
- [ ] Dependencies verified
- [ ] Security review completed
- [ ] Manual testing done
- [ ] Migration guide (if breaking change)

### 4. Maintenance Tasks

**Regular maintenance**:

1. **Weekly**:
   - Check for security updates in dependencies
   - Review and triage issues

2. **Monthly**:
   - Update documentation
   - Review community contributions
   - Performance profiling

3. **Quarterly**:
   - Dependency audit
   - Feature gap analysis
   - User feedback review

### 5. Support Channels

**Setup**:

```markdown
## Support

- **Issues**: [GitHub Issues](https://github.com/owner/repo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/owner/repo/discussions)
- **Discord**: [Community Server](https://discord.gg/example)
```

### 6. Recognition

**Acknowledge contributors**:

```markdown
## Contributors

Thanks to all contributors who have helped make this project better:

- [@contributor1](https://github.com/contributor1) - Feature X
- [@contributor2](https://github.com/contributor2) - Bug fix Y
```

---

## References and Resources

### Official Documentation

- **Claude Code**: https://code.claude.com/docs/en/overview
- **Claude Code GitHub**: https://github.com/anthropics/claude-code
- **Codex CLI**: https://github.com/openai/codex
- **OpenCode**: https://opencode.ai

### Example Repositories

- **terraphim/terraphim-skills**: Claude Code skills (this repository)
- **terraphim/codex-skills**: Codex CLI skills
- **terraphim/opencode-skills**: OpenCode skills
- **anthropics/claude-code**: Claude Code reference implementation

### Related Projects

- **Terraphim AI**: https://github.com/terraphim/terraphim-ai
- **Terraphim Hooks**: Knowledge graph-based text replacement
- **Git Safety Guard**: Pattern-based command blocking

### Standards and Best Practices

- **Semantic Versioning**: https://semver.org/
- **Apache 2.0 License**: https://www.apache.org/licenses/LICENSE-2.0
- **RFC 2119**: Key words (MUST, SHOULD, etc.)

## Glossary

- **Skill**: Reusable prompt definition for AI agents
- **Hook**: Script that intercepts tool execution
- **PreToolUse**: Hook that runs before tool execution
- **PostToolUse**: Hook that runs after tool execution
- **Fail-open**: Behavior that passes through if hook fails
- **Agent**: AI entity with specific role and capabilities
- **Plugin**: Collection of skills for Claude Code
- **Marketplace**: Plugin distribution system

---

## Questions for Reviewer

1. Should we standardize on Claude Code's rich frontmatter format for all platforms?
2. What is the recommended minimum system prompt length for effective skills?
3. Should we establish a shared testing framework for cross-platform skills?
4. How do we handle platform-specific features in cross-platform skills?
5. What is the acceptable latency threshold for PreToolUse hooks?
6. Should we recommend a specific license for open source skills?
7. How do we handle skill deprecation and migration?
8. What metrics should we track for skill performance?
9. Should we establish a skill review process similar to code review?
10. How do we balance simplicity vs. rich metadata in skill descriptions?

---

## Appendices

### Appendix A: Quick Reference

**Skill Creation Checklist**:
- [ ] Name uses kebab-case
- [ ] Description has 3-4 examples with context
- [ ] System prompt is 500+ words
- [ ] Technology preferences listed
- [ ] Constraints documented
- [ ] Success metrics defined
- [ ] Tested on all platforms

**Hook Creation Checklist**:
- [ ] Implements fail-open semantics
- [ ] Filters by tool type
- [ ] Validates input
- [ ] Handles errors gracefully
- [ ] Returns proper JSON output
- [ ] Has unit tests
- [ ] Has integration tests
- [ ] Documented with examples

### Appendix B: Common Patterns

**Pattern 1: Tool Type Filtering**
```bash
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL_NAME" != "Bash" ] && exit 0
```

**Pattern 2: Fail-Open Error Handling**
```bash
RESULT=$(command 2>/dev/null || echo '{"status":"ok"}')
```

**Pattern 3: JSON Output**
```bash
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
EOF
```

### Appendix C: Troubleshooting Guide

| Issue | Cause | Solution |
|-------|-------|----------|
| Hook not triggering | Missing configuration | Add to `~/.claude/settings.local.json` |
| Permission denied | Script not executable | Run `chmod +x hook.sh` |
| Command not found | Dependency missing | Install jq, terraphim-agent |
| Hook blocks everything | Logic error | Add debug logging |
| Performance issues | Expensive operations | Cache external calls |
| Skills not discovered | Wrong path | Check platform-specific paths |

### Appendix D: Migration Guide

**From Codex to Claude Code**:
1. Convert minimal frontmatter to rich format
2. Add 500+ word system prompt
3. Create plugin.json and marketplace.json
4. Test in local environment
5. Submit to marketplace

**From Claude Code to Codex**:
1. Strip to minimal frontmatter
2. Keep core content
3. Copy to ~/.codex/skills/
4. Test explicit invocation with `$skill-name`

**Cross-Platform Setup**:
1. Maintain skills in Claude Code format
2. Create conversion scripts
3. Test on all platforms
4. Document platform differences

---

**End of Document**
