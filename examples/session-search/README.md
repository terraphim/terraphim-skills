# Semantic Search over Claude Code Sessions

This example demonstrates how to use Terraphim's knowledge graph-enriched semantic search to find relevant past work in your Claude Code session history.

## Prerequisites

1. **Build terraphim-agent with session support:**
   ```bash
   cd /path/to/terraphim-ai
   cargo build -p terraphim_agent --features repl-full --release
   ```

2. **Ensure Claude Code sessions exist:**
   ```bash
   ls ~/.claude/projects/
   ```

## Quick Start

### 1. Interactive REPL

Launch the REPL and use session commands:

```bash
./terraphim-agent

# In REPL:
/sessions sources          # See available sources
/sessions import           # Import all sessions
/sessions search "rust"    # Search for "rust"
```

### 2. Using the Example Script

```bash
# Make executable
chmod +x search-sessions.sh

# Search for a topic
./search-sessions.sh "error handling"

# Search with concept enrichment
./search-sessions.sh --concepts "async rust"

# Export results
./search-sessions.sh --export "database" results.md
```

### 3. Programmatic Search (Rust)

See `search_example.rs` for a complete Rust example.

## Session Search Capabilities

### Full-Text Search

Search across all message content, titles, and project paths:

```
/sessions search "authentication JWT"
```

### Concept-Based Search

Use knowledge graph concepts for semantic matching:

```
/sessions concepts "error handling"
```

This finds sessions that discuss error handling patterns, even if they don't contain the exact phrase.

### Related Sessions

Find sessions similar to a known session:

```
/sessions related abc123-def456 --min 3
```

### Timeline View

See your session history organized by time:

```
/sessions timeline --group week --limit 10
```

## Knowledge Graph Enrichment

Sessions are enriched with concepts from the knowledge graph (`docs/src/kg/`). This enables:

1. **Semantic Matching**: Find "error handling" when session says "Result<T, E>"
2. **Concept Clustering**: Group related sessions by shared concepts
3. **Pattern Discovery**: Identify common patterns across projects

### How It Works

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Claude Code    │     │   Terraphim      │     │  Knowledge      │
│  Sessions       │ ──▶ │   Sessions       │ ◀── │  Graph          │
│  (~/.claude/)   │     │   Service        │     │  (docs/src/kg/) │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌──────────────────┐
                        │  Enriched        │
                        │  Search Results  │
                        │  + Concepts      │
                        └──────────────────┘
```

## Example Workflows

### Find Previous Implementation

"How did I implement caching last time?"

```bash
/sessions import
/sessions search "caching"
/sessions show <session-id>
```

### Discover Patterns Across Projects

"What debugging approaches have I used?"

```bash
/sessions concepts "debugging"
/sessions timeline --group month
```

### Export for Documentation

"Export my authentication work for the team"

```bash
/sessions search "authentication"
/sessions export --format markdown --output auth-sessions.md
```

### Find Related Work

"What else did I work on around the time of this session?"

```bash
/sessions related <session-id>
/sessions timeline
```

## Data Model

### Session Structure

```rust
Session {
    id: "uuid",
    source: "claude-code",
    title: Option<String>,
    messages: Vec<Message>,
    metadata: SessionMetadata {
        project_path: "/path/to/project",
        started_at: DateTime,
        ended_at: DateTime,
        agent_types: ["architect", "developer"],
    }
}
```

### Enriched Session

```rust
EnrichedSession {
    session: Session,
    concepts: Vec<ConceptMatch> {
        term: "error handling",
        occurrences: [(message_idx, offset, length)],
        confidence: 0.95,
    }
}
```

## Supported Sources

| Source | Location | Status |
|--------|----------|--------|
| Claude Code | `~/.claude/projects/` | Native |
| Cursor | `~/.cursor/` | Via CLA |
| Aider | `.aider.chat.history.md` | Via CLA |
| OpenCode | `~/.opencode/` | Via CLA |

## Troubleshooting

### No sessions found

```bash
# Check if sessions directory exists
ls -la ~/.claude/projects/

# Check for available sources
/sessions sources
```

### Import fails

```bash
# Check permissions
chmod -R u+r ~/.claude/projects/

# Import with debug logging
RUST_LOG=debug terraphim-agent
/sessions import
```

### Concept search returns nothing

```bash
# Verify knowledge graph files exist
ls docs/src/kg/

# Enrich sessions first
/sessions enrich
```

## Related Skills

- [terraphim-hooks](../../skills/terraphim-hooks/SKILL.md) - Text replacement hooks
- [session-search](../../skills/session-search/SKILL.md) - Full skill documentation
