# Terraphim Claude Skills

Best practice engineering skills for open source Rust/WebAssembly development. A public plugin marketplace for Claude Code.

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

## Installation

### From GitHub (Recommended)

```bash
# Add the Terraphim marketplace
claude plugin marketplace add terraphim/terraphim-skills

# Install the engineering skills plugin
claude plugin install terraphim-engineering-skills@terraphim-skills
```

### From Local Clone

```bash
# Clone the repository
git clone https://github.com/terraphim/terraphim-skills.git

# Add as local marketplace
claude plugin marketplace add ./terraphim-skills

# Install the plugin
claude plugin install terraphim-engineering-skills@terraphim-skills
```

### Terraphim Agent (for Hooks)

The `terraphim-agent` binary enables Claude Code hooks for command replacement and git safety guards.

**Install from GitHub Releases (Recommended):**

```bash
# macOS ARM64 (Apple Silicon)
gh release download --repo terraphim/terraphim-ai \
  --pattern "terraphim-agent-aarch64-apple-darwin" --dir /tmp
chmod +x /tmp/terraphim-agent-aarch64-apple-darwin
mv /tmp/terraphim-agent-aarch64-apple-darwin ~/.cargo/bin/terraphim-agent

# macOS x86_64 (Intel)
gh release download --repo terraphim/terraphim-ai \
  --pattern "terraphim-agent-x86_64-apple-darwin" --dir /tmp
chmod +x /tmp/terraphim-agent-x86_64-apple-darwin
mv /tmp/terraphim-agent-x86_64-apple-darwin ~/.cargo/bin/terraphim-agent

# Linux x86_64
gh release download --repo terraphim/terraphim-ai \
  --pattern "terraphim-agent-x86_64-unknown-linux-gnu" --dir /tmp
chmod +x /tmp/terraphim-agent-x86_64-unknown-linux-gnu
mv /tmp/terraphim-agent-x86_64-unknown-linux-gnu ~/.cargo/bin/terraphim-agent
```

**Note:** The crates.io version (`cargo install terraphim_agent`) is outdated (v1.0.0) and missing `hook` and `guard` commands. Use GitHub releases for the latest features.

## User-Level Activation (Complete Setup)

Follow these steps to activate all terraphim skills and hooks at the user level (applies to all projects):

### Step 1: Install the Plugin

```bash
# Add the Terraphim marketplace
claude plugin marketplace add terraphim/terraphim-skills

# Install the engineering skills plugin
claude plugin install terraphim-engineering-skills@terraphim-skills
```

### Step 2: Install terraphim-agent

```bash
# macOS ARM64 (Apple Silicon)
gh release download --repo terraphim/terraphim-ai \
  --pattern "terraphim-agent-aarch64-apple-darwin" --dir /tmp
chmod +x /tmp/terraphim-agent-aarch64-apple-darwin
mv /tmp/terraphim-agent-aarch64-apple-darwin ~/.cargo/bin/terraphim-agent
```

### Step 3: Configure User-Level Hooks

Create/update `~/.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "Skill(terraphim-engineering-skills:disciplined-research)",
      "Skill(terraphim-engineering-skills:disciplined-design)",
      "Skill(terraphim-engineering-skills:disciplined-implementation)",
      "Skill(terraphim-engineering-skills:disciplined-specification)",
      "Skill(terraphim-engineering-skills:disciplined-verification)",
      "Skill(terraphim-engineering-skills:disciplined-validation)",
      "Skill(terraphim-engineering-skills:architecture)",
      "Skill(terraphim-engineering-skills:implementation)",
      "Skill(terraphim-engineering-skills:testing)",
      "Skill(terraphim-engineering-skills:debugging)",
      "Skill(terraphim-engineering-skills:code-review)",
      "Skill(terraphim-engineering-skills:security-audit)",
      "Skill(terraphim-engineering-skills:documentation)",
      "Skill(terraphim-engineering-skills:devops)",
      "Skill(terraphim-engineering-skills:terraphim-hooks)",
      "Skill(terraphim-engineering-skills:git-safety-guard)",
      "Skill(terraphim-engineering-skills:session-search)",
      "Skill(terraphim-engineering-skills:local-knowledge)",
      "Skill(terraphim-engineering-skills:quality-gate)",
      "Skill(terraphim-engineering-skills:rust-development)",
      "Skill(terraphim-engineering-skills:rust-performance)",
      "Bash(terraphim-agent:*)"
    ]
  },
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

### Step 4: Install Hook Scripts

**Option A: Use the install script (Recommended)**

```bash
# From the terraphim-claude-skills repository
cd examples/hooks
./install.sh
```

This automatically:
- Copies hook scripts to `~/.claude/hooks/`
- Creates knowledge graph directory
- Adds sample replacement rules (npm->bun, Claude Code->Terraphim AI)

**Option B: Manual installation**

Create `~/.claude/hooks/pre_tool_use.sh`:

```bash
#!/bin/bash
# Terraphim PreToolUse hook - git-safety-guard + knowledge graph replacement
# Replaces text in ALL bash commands: git commit, gh pr create, etc.
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ "$TOOL_NAME" != "Bash" ] && exit 0
[ -z "$COMMAND" ] && exit 0

AGENT=""
command -v terraphim-agent >/dev/null 2>&1 && AGENT="terraphim-agent"
[ -z "$AGENT" ] && [ -x "$HOME/.cargo/bin/terraphim-agent" ] && AGENT="$HOME/.cargo/bin/terraphim-agent"
[ -z "$AGENT" ] && exit 0

# Step 1: Block destructive commands (git reset --hard, rm -rf, etc.)
GUARD_RESULT=$($AGENT guard --json <<< "$COMMAND" 2>/dev/null || echo '{"decision":"allow"}')
if echo "$GUARD_RESULT" | jq -e '.decision == "block"' >/dev/null 2>&1; then
    REASON=$(echo "$GUARD_RESULT" | jq -r '.reason // "Blocked by git-safety-guard"')
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"BLOCKED: $REASON"}}
EOF
    exit 0
fi

# Step 2: Knowledge graph replacement for ALL commands
cd ~/.config/terraphim 2>/dev/null || exit 0
$AGENT graph --role "Terraphim Engineer" >/dev/null 2>&1 || true
NEW_COMMAND=$(echo "$COMMAND" | $AGENT replace --role "Terraphim Engineer" 2>/dev/null || echo "$COMMAND")

if [ "$NEW_COMMAND" != "$COMMAND" ] && [ -n "$NEW_COMMAND" ]; then
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":$(echo "$NEW_COMMAND" | jq -Rs .)}}}
EOF
    exit 0
fi

# Step 3: Fallback handler
$AGENT hook --hook-type pre-tool-use --json <<< "$INPUT" 2>/dev/null
```

Make it executable:
```bash
mkdir -p ~/.claude/hooks
chmod +x ~/.claude/hooks/pre_tool_use.sh
```

Create `~/.claude/hooks/post_tool_use.sh`:

```bash
#!/bin/bash
# Terraphim PostToolUse hook - processes tool results
INPUT=$(cat)
AGENT=""
command -v terraphim-agent >/dev/null 2>&1 && AGENT="terraphim-agent"
[ -z "$AGENT" ] && [ -x "$HOME/.cargo/bin/terraphim-agent" ] && AGENT="$HOME/.cargo/bin/terraphim-agent"
[ -z "$AGENT" ] && exit 0
$AGENT hook --hook-type post-tool-use --json <<< "$INPUT" 2>/dev/null || exit 0
```

Make it executable:
```bash
chmod +x ~/.claude/hooks/post_tool_use.sh
```

### Step 5: Set Up Knowledge Graph

Create replacement rules:

```bash
mkdir -p ~/.config/terraphim/docs/src/kg

# npm -> bun replacement
cat > ~/.config/terraphim/docs/src/kg/"bun install.md" << 'EOF'
# bun install

Install dependencies using Bun package manager.

synonyms:: npm install, yarn install, pnpm install, npm i
EOF

# npx -> bunx replacement
cat > ~/.config/terraphim/docs/src/kg/bunx.md << 'EOF'
# bunx

Execute packages using Bun.

synonyms:: npx, pnpx, yarn dlx
EOF

# Claude Code -> Terraphim AI replacement (for git commits, PRs, etc.)
cat > ~/.config/terraphim/docs/src/kg/terraphim_ai.md << 'EOF'
# Terraphim AI

Terraphim AI - Knowledge graph powered development.

synonyms:: Claude Code, Claude Opus 4.5
EOF
```

**Note:** Replacements work on ALL bash commands including:
- `git commit -m "..."` - commit messages
- `gh pr create --body "..."` - PR descriptions
- `gh issue create --body "..."` - issue descriptions
- Any command containing the synonym text

### Step 6: Verify Installation

```bash
# Test guard command
echo "git reset --hard" | terraphim-agent guard --json
# Expected: {"decision":"block","reason":"git reset --hard destroys uncommitted changes..."}

# Test replacement (from config directory)
cd ~/.config/terraphim && echo "npm install react" | terraphim-agent replace
# Expected: bun install react

# Test hook script
echo '{"tool_name":"Bash","tool_input":{"command":"git checkout -- file.txt"}}' | ~/.claude/hooks/pre_tool_use.sh
# Expected: BLOCKED message
```

## Skills Overview (27 Skills)

### Core Development

| Skill | Description |
|-------|-------------|
| `architecture` | System architecture design, ADRs, API planning. Never writes code. |
| `implementation` | Production-ready code with tests. Zero linting violations. |
| `testing` | Comprehensive tests: unit, integration, property-based, benchmarks. |
| `debugging` | Systematic root cause analysis. All debug code removed before report. |

### Terraphim Integration

| Skill | Description |
|-------|-------------|
| `terraphim-hooks` | Knowledge graph-based text replacement with Claude Code and Git hooks. |
| `session-search` | Search AI coding session history with concept enrichment. |
| `local-knowledge` | Search personal notes via role-based haystacks (Rust, Frontend, Architecture). |

### Rust Expertise

| Skill | Description |
|-------|-------------|
| `rust-development` | Idiomatic Rust: ownership, async, traits, error handling. |
| `rust-performance` | Profiling, benchmarking, SIMD, memory optimization. |

### Desktop UI

| Skill | Description |
|-------|-------------|
| `gpui-components` | GPUI desktop UI components following Zed editor patterns. |

### Code Quality

| Skill | Description |
|-------|-------------|
| `code-review` | Thorough review for bugs, security, performance. Actionable feedback. |
| `security-audit` | Vulnerability assessment, unsafe code review, OWASP compliance. |

### Verification & Validation (Right Side of V)

| Skill | Description |
|-------|-------------|
| `quality-gate` | Orchestrates verification/validation for a PR. Produces a go/no-go report with evidence. |
| `requirements-traceability` | Requirements → design → code → tests → evidence traceability matrix and gap analysis. |
| `acceptance-testing` | User acceptance testing (UAT) plans and end-to-end acceptance scenarios. |
| `visual-testing` | Visual regression testing strategy and implementation guidance for UI changes. |

### Documentation & DevOps

| Skill | Description |
|-------|-------------|
| `documentation` | API docs, README, CONTRIBUTING. Strict quality standards. |
| `md-book` | Build and manage md-book documentation sites. |
| `devops` | CI/CD pipelines, Docker, Cloudflare deployment, GitHub Actions. |

### Open Source

| Skill | Description |
|-------|-------------|
| `open-source-contribution` | Quality PRs, good issues, project conventions. |
| `community-engagement` | Welcoming contributors, release notes, community health. |

### Disciplined Development (V-Model Workflow)

| Skill | Description |
|-------|-------------|
| `disciplined-research` | Phase 1: Deep problem understanding. Produces research document. |
| `disciplined-design` | Phase 2: Implementation planning. Specifies files, APIs, tests. |
| `disciplined-specification` | Phase 2.5: Deep interview. Refines spec with edge cases, tradeoffs. |
| `disciplined-implementation` | Phase 3: Execute plan step by step with tests. |
| `disciplined-verification` | Phase 4: Unit + integration testing with traceability. Defects loop back. |
| `disciplined-validation` | Phase 5: System test + UAT. Stakeholder interviews and sign-off. |

## Disciplined Development Workflow (V-Model)

For complex features, use the full V-model approach with defect loop-back:

```
LEFT SIDE (Development)                      RIGHT SIDE (Verification)
-----------------------                      -------------------------

Phase 1: Research         <===============>  Phase 5: Validation
  • Problem understanding                      • System testing (NFRs)
  • Constraints & risks                        • UAT with stakeholders
  • Success criteria                           • Formal sign-off
         |                                            ^
         v                                            |
Phase 2: Design           <===============>          |
  • File changes                                      |
  • API signatures                                    |
  • Test strategy                                     |
         |                                            |
         v                                            |
Phase 2.5: Specification  <===============>  Phase 4: Verification
  • Deep interview                             • Unit testing
  • Edge cases                                 • Integration testing
  • Tradeoffs                                  • Traceability matrix
         |                                            ^
         v                                            |
Phase 3: Implementation   ==================>        |
  • Test first                                       |
  • Small commits                                    |
  • Quality checks          ----------------------->-+

                    DEFECT LOOP-BACK
              <========================
              Defects trace back to the
              originating left-side phase
```

**Flow:**
1. Development proceeds DOWN the left side (Phases 1-3)
2. Testing proceeds UP the right side (Phases 4-5)
3. Defects loop BACK to the originating left-side phase
4. After fix, re-enter right side at appropriate level

**When to use:**
- Complex features touching multiple systems
- Unclear requirements needing investigation
- High-risk changes requiring careful planning
- Refactoring with many dependencies
- Features requiring formal acceptance and sign-off

## Technology Stack

These skills are optimized for the following stack:

**Languages & Runtimes:**
- Rust (primary language)
- TypeScript (tooling, frontend)
- WebAssembly (portable execution)

**Infrastructure:**
- Cloudflare Workers (edge computing)
- Fluvio (event streaming)
- Redis (caching, feature stores)
- SQLite/ReDB (embedded storage)

**Development:**
- GitHub Actions (CI/CD)
- Docker (containerization)
- Criterion (benchmarking)
- Proptest (property testing)

## How to Use Skills

Skills are invoked automatically by Claude Code when relevant, or you can request them explicitly. After installation, skills appear in Claude Code's available skills list and can be triggered through natural conversation.

### Automatic Invocation

Claude Code automatically selects appropriate skills based on your request:

```
You: "I need to add a caching layer to our API"
Claude: [Automatically uses architecture skill]
        → Creates ADR with design decisions
        → Defines API changes and data flow
        → Documents trade-offs and alternatives
```

### Explicit Skill Requests

You can explicitly request a skill by mentioning it:

```
You: "Use the security-audit skill to review this authentication code"
Claude: [Uses security-audit skill]
        → Checks for OWASP vulnerabilities
        → Reviews unsafe code blocks
        → Validates input handling
        → Provides remediation steps
```

### Skill Invocation via Slash Command

If configured, invoke skills directly:

```
/skill rust-performance
```

## Usage Examples by Category

### Architecture & Design

```
You: "Design a plugin system for our application"
Claude: [architecture skill]

Output:
- ADR document with context and decision
- Module structure diagram
- Public API definitions
- Extension point documentation
```

```
You: "We need to refactor the database layer"
Claude: [disciplined-research skill]

Output:
- Current state analysis
- Constraint identification
- Risk assessment
- Research document for approval
```

### Code Implementation

```
You: "Implement the caching layer from the approved design"
Claude: [implementation skill]

Output:
- Production-ready Rust code
- Unit tests for all functions
- Integration tests
- Zero clippy warnings
```

```
You: "This function is too slow, optimize it"
Claude: [rust-performance skill]

Output:
- Profiling analysis
- Benchmark comparisons
- Optimized implementation
- Performance metrics
```

### Code Quality

```
You: "Review this PR for issues"
Claude: [code-review skill]

Output:
- Critical issues (security, correctness)
- Important issues (performance, errors)
- Suggestions (style, simplification)
- Specific line-by-line feedback
```

```
You: "Audit this module for security vulnerabilities"
Claude: [security-audit skill]

Output:
- Vulnerability findings by severity
- Unsafe code review
- Input validation check
- Remediation recommendations
```

### Testing & Debugging

```
You: "Write comprehensive tests for this module"
Claude: [testing skill]

Output:
- Unit tests with edge cases
- Property-based tests
- Integration tests
- Benchmark setup
```

```
You: "This function sometimes returns wrong results"
Claude: [debugging skill]

Output:
- Systematic investigation
- Root cause analysis
- Fix with verification
- Regression test
```

### Documentation & DevOps

```
You: "Document this public API"
Claude: [documentation skill]

Output:
- Rustdoc comments with examples
- Module-level documentation
- README updates
- Doc tests that compile
```

```
You: "Set up CI/CD for this project"
Claude: [devops skill]

Output:
- GitHub Actions workflows
- Docker configuration
- Release automation
- Deployment scripts
```

### Open Source Workflow

```
You: "Help me contribute to this open source project"
Claude: [open-source-contribution skill]

Output:
- PR with proper format
- Commit message conventions
- Test additions
- Documentation updates
```

```
You: "Write release notes for v2.0"
Claude: [community-engagement skill]

Output:
- Changelog entries
- Migration guide
- Contributor credits
- Breaking change documentation
```

### Terraphim Hooks Integration

**Quick Install:**

```bash
# From the terraphim-claude-skills repository
cd examples/hooks && ./install.sh
```

**User-Level Hooks Configuration:**

Add to `~/.claude/settings.local.json` for global hooks across all projects:

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

**What the hooks do:**

1. **Git Safety Guard** - Blocks destructive commands like `git reset --hard`, `rm -rf /`, `git push --force`
2. **Knowledge Graph Replacement** - Replaces text in ALL bash commands:
   - `git commit -m "Generated with [Claude Code]"` -> `"Generated with [Terraphim AI]"`
   - `gh pr create --body "Claude Code"` -> `--body "Terraphim AI"`
   - `npm install` -> `bun install`

**Knowledge Graph Setup:**

Create replacement rules in `~/.config/terraphim/docs/src/kg/`:

```bash
mkdir -p ~/.config/terraphim/docs/src/kg

# Example: npm -> bun
cat > ~/.config/terraphim/docs/src/kg/"bun install.md" << 'EOF'
# bun install

Install dependencies using Bun package manager.

synonyms:: npm install, yarn install, pnpm install, npm i
EOF

# Example: Claude Code -> Terraphim AI
cat > ~/.config/terraphim/docs/src/kg/terraphim_ai.md << 'EOF'
# Terraphim AI

Terraphim AI - Knowledge graph powered development.

synonyms:: Claude Code, Claude Opus 4.5
EOF
```

**Usage Examples:**

```
You: "Set up Terraphim hooks to replace npm with bun"
Claude: [terraphim-hooks skill]

Output:
- Knowledge graph markdown files in docs/src/kg/
- PreToolUse hook configuration
- Git prepare-commit-msg hook
- Installation and testing commands
```

```
You: "I want all Claude Code attributions in commits replaced with Terraphim AI"
Claude: [terraphim-hooks skill]

Output:
- Knowledge graph file docs/src/kg/terraphim_ai.md
- Git hook scripts/hooks/prepare-commit-msg
- Hook installation instructions
- Test commands to verify replacement
```

```
You: "Find my previous work on database migrations"
Claude: [session-search skill]

Output:
- Session search results across Claude Code history
- Timeline of related sessions
- Concept-enriched matches
- Exportable session details
```

```
You: "Check my notes for async iterator patterns in Rust"
Claude: [local-knowledge skill]

Output:
- Search results from personal notes
- Role-based filtering (Rust Engineer)
- Knowledge graph term expansion
- File paths and content excerpts
```

### Disciplined Development (Complex Features)

For complex features, use the four-phase workflow:

**Phase 1: Research**
```
You: "We need to add real-time collaboration"
Claude: [disciplined-research skill]

Output: Research Document
- Problem statement and success criteria
- Current system analysis
- Constraints and dependencies
- Risks and open questions
-> Wait for human approval
```

**Phase 2: Design**
```
You: "Research approved, design the solution"
Claude: [disciplined-design skill]

Output: Implementation Plan
- File changes with purposes
- API signatures (types, functions)
- Test strategy
- Step-by-step sequence
-> Wait for human approval
```

**Phase 2.5: Specification Interview**
```
You: "Run the specification interview"
Claude: [disciplined-specification skill]

Process: Deep Interview
- Asks non-obvious questions about edge cases
- Probes failure modes and recovery
- Explores scale, security, accessibility
- Continues until answers converge

Output: Appended to Implementation Plan
- Decisions by dimension
- Deferred items documented
-> Proceed when complete
```

**Phase 3: Implementation**
```
You: "Plan approved, implement step 1"
Claude: [disciplined-implementation skill]

Output: Working Code
- Tests first for each step
- Implementation to pass tests
- Commit per step
- Progress reports
```

## Combining Skills

Skills work together naturally:

```
You: "Add user authentication to our API"

Claude workflow:
1. [architecture] → Design auth system, create ADR
2. [security-audit] → Review design for vulnerabilities
3. [implementation] → Write auth code with tests
4. [code-review] → Self-review before PR
5. [documentation] → Document the new endpoints
6. [devops] → Update CI for auth tests
7. [quality-gate] → Verify readiness (traceability, UAT/visual if needed) and produce evidence
```

## Best Practices

1. **Let skills work together** - Complex tasks benefit from multiple skills
2. **Be specific** - Clear requests get better results
3. **Use disciplined workflow for complexity** - Research → Design → Implement
4. **Request reviews** - Use quality-gate, code-review and security-audit before merging
5. **Document as you go** - Use documentation skill for public APIs

## Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork the repository**
2. **Create a skill** in `skills/<skill-name>/SKILL.md`
3. **Follow the existing format** with YAML frontmatter
4. **Keep skills focused** on a single capability
5. **Submit a PR** with clear description

### Skill Format

```yaml
---
name: skill-name
description: |
  Brief description of what this skill does.
  When to use it. What it produces.
license: Apache-2.0
---

[System prompt content]
```

## Validation

Before submitting changes:

```bash
# Validate plugin structure
claude plugin validate .
```

## License

Apache-2.0 - See [LICENSE](LICENSE) for details.

## Related Projects

| Repository | Platform | Installation |
|------------|----------|--------------|
| [terraphim/codex-skills](https://github.com/terraphim/codex-skills) | OpenAI Codex CLI | `~/.codex/skills/` |
| [terraphim/opencode-skills](https://github.com/terraphim/opencode-skills) | OpenCode | `~/.config/opencode/skill/` |
| [terraphim/terraphim-skills](https://github.com/terraphim/terraphim-skills) | Claude Code | Plugin marketplace |

See also:
- [Terraphim AI](https://github.com/terraphim/terraphim-ai) - Knowledge graph system
- [Claude Code](https://claude.ai/code) - AI-powered development

## Support

- **Issues**: [GitHub Issues](https://github.com/terraphim/terraphim-skills/issues)
- **Discussions**: [GitHub Discussions](https://github.com/terraphim/terraphim-skills/discussions)
