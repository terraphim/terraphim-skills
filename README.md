# Terraphim Claude Skills

Best practice engineering skills for open source Rust/WebAssembly development. A public plugin marketplace for Claude Code.

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

## Installation

### From GitHub (Recommended)

```bash
# Add the Terraphim marketplace
claude plugin marketplace add terraphim/terraphim-claude-skills

# Install the engineering skills plugin
claude plugin install terraphim-engineering-skills@terraphim-ai
```

### From Local Clone

```bash
# Clone the repository
git clone https://github.com/terraphim/terraphim-claude-skills.git

# Add as local marketplace
claude plugin marketplace add ./terraphim-claude-skills

# Install the plugin
claude plugin install terraphim-engineering-skills@terraphim-ai
```

## Skills Overview (15 Skills)

### Core Development

| Skill | Description |
|-------|-------------|
| `architecture` | System architecture design, ADRs, API planning. Never writes code. |
| `implementation` | Production-ready code with tests. Zero linting violations. |
| `testing` | Comprehensive tests: unit, integration, property-based, benchmarks. |
| `debugging` | Systematic root cause analysis. All debug code removed before report. |

### Rust Expertise

| Skill | Description |
|-------|-------------|
| `rust-development` | Idiomatic Rust: ownership, async, traits, error handling. |
| `rust-performance` | Profiling, benchmarking, SIMD, memory optimization. |

### Code Quality

| Skill | Description |
|-------|-------------|
| `code-review` | Thorough review for bugs, security, performance. Actionable feedback. |
| `security-audit` | Vulnerability assessment, unsafe code review, OWASP compliance. |

### Documentation & DevOps

| Skill | Description |
|-------|-------------|
| `documentation` | API docs, README, CONTRIBUTING. Strict quality standards. |
| `devops` | CI/CD pipelines, Docker, Cloudflare deployment, GitHub Actions. |

### Open Source

| Skill | Description |
|-------|-------------|
| `open-source-contribution` | Quality PRs, good issues, project conventions. |
| `community-engagement` | Welcoming contributors, release notes, community health. |

### Disciplined Development (3-Phase Workflow)

| Skill | Description |
|-------|-------------|
| `disciplined-research` | Phase 1: Deep problem understanding. Produces research document. |
| `disciplined-design` | Phase 2: Implementation planning. Specifies files, APIs, tests. |
| `disciplined-implementation` | Phase 3: Execute plan step by step with tests. |

## Disciplined Development Workflow

For complex features, use the three-phase approach:

```
Phase 1: Research          Phase 2: Design           Phase 3: Implementation
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│disciplined-     │  →    │disciplined-     │   →   │disciplined-     │
│research         │       │design           │       │implementation   │
│                 │       │                 │       │                 │
│ • Problem scope │       │ • File changes  │       │ • Test first    │
│ • System mapping│       │ • API signatures│       │ • Small commits │
│ • Constraints   │       │ • Test strategy │       │ • Quality checks│
│ • Risks/unknowns│       │ • Step sequence │       │ • PR ready      │
└────────┬────────┘       └────────┬────────┘       └────────┬────────┘
         │                         │                         │
         ▼                         ▼                         ▼
   Research Document         Implementation Plan       Working Code
   (Human approval)          (Human approval)        (Human approval)
```

**When to use:**
- Complex features touching multiple systems
- Unclear requirements needing investigation
- High-risk changes requiring careful planning
- Refactoring with many dependencies

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

## Usage Examples

### Architecture Design
```
User: "Design an API for our notification system"
Claude: Uses architecture skill to create ADR and API design
```

### Rust Code Review
```
User: "Review this async implementation"
Claude: Uses rust-development skill to check ownership, error handling, idioms
```

### Security Audit
```
User: "Check this code for vulnerabilities"
Claude: Uses security-audit skill to identify issues and suggest fixes
```

### Disciplined Development
```
# Phase 1
User: "We need to add real-time notifications"
Claude: Uses disciplined-research to map systems and identify risks

# Phase 2 (after approval)
User: "Research approved, design the solution"
Claude: Uses disciplined-design to create implementation plan

# Phase 3 (after approval)
User: "Plan approved, implement step 1"
Claude: Uses disciplined-implementation to execute with tests
```

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

- [Terraphim AI](https://github.com/terraphim/terraphim-ai) - Knowledge graph system
- [Claude Code](https://claude.ai/code) - AI-powered development

## Support

- **Issues**: [GitHub Issues](https://github.com/terraphim/terraphim-claude-skills/issues)
- **Discussions**: [GitHub Discussions](https://github.com/terraphim/terraphim-claude-skills/discussions)
