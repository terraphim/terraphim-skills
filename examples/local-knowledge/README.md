# Local Knowledge Search Example

This example demonstrates how to search your personal notes using Terraphim's role-based search system.

## Prerequisites

1. **Build terraphim-agent** with REPL features:
   ```bash
   cd /path/to/terraphim-ai
   cargo build -p terraphim_agent --features repl-full --release
   ```

2. **Configure roles** (or use the provided config):
   ```bash
   # Copy the local knowledge config
   cp terraphim_server/default/local_knowledge_engineer_config.json \
      terraphim_server/default/terraphim_config.json
   ```

3. **Generate knowledge graph** (optional, for semantic search):
   ```bash
   ./scripts/generate-notes-kg.sh
   ```

## Quick Start

### Interactive REPL

```bash
# Start the REPL
./target/release/terraphim-agent

# In REPL:
/role list                              # See available roles
/role select rust-engineer              # Switch to Rust role
/search "async iterator" --limit 5      # Search your notes
```

### Using the Search Script

```bash
cd terraphim-claude-skills/examples/local-knowledge
./search-notes.sh "rust async"
./search-notes.sh --role frontend-engineer "useState"
./search-notes.sh --stats
```

## Example Searches

### Rust Development
```bash
/role select rust-engineer
/search "async iterator patterns"
/search "error handling Result"
/search "wasm compilation"
```

### Frontend Development
```bash
/role select frontend-engineer
/search "React useState useEffect"
/search "TypeScript generics"
```

### General Knowledge
```bash
/role select terraphim-engineer
/search "atomic data server"
/search "knowledge graph"
```

## Understanding Results

Search results include:
- **Title**: Document title
- **Path/URL**: Source location
- **Body**: Content excerpt
- **Rank**: Relevance score (lower is better)

Example output:
```
[1] rust-matching-iterators.md
    Path: /Users/alex/synced/expanded_docs/rust-matching-iterators.md
    Async iterator over AWS S3 pagination using State enum...
    Rank: 1

[2] rust-python-extension.md
    Path: /Users/alex/synced/expanded_docs/rust-python-extension.md
    PyO3/Maturin async patterns for Python extensions...
    Rank: 2
```

## Customizing

### Adding Your Own Notes

1. Place markdown files in a directory
2. Update `local_knowledge_engineer_config.json`:
   ```json
   {
     "haystacks": [
       {
         "location": "/path/to/your/notes",
         "service": "Ripgrep"
       }
     ]
   }
   ```

### Creating Role-Specific Knowledge Graphs

Run the generator with custom filters:
```bash
./scripts/generate-notes-kg.sh \
  --source ~/notes \
  --output docs/src/kg/my_kg \
  --filter "*.md"
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No results | Check haystack path in config |
| Slow search | Reduce --limit or use more specific query |
| KG not loading | Verify path format in config |
| Role not found | Check role name spelling in config |

## Related Documentation

- [Local Knowledge Skill](../../skills/local-knowledge/SKILL.md)
- [Terraphim TUI Documentation](https://docs.terraphim.ai/tui/)
