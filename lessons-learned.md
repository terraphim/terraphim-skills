# Lessons Learned

## 2025-12-30: Claude Code Plugin Marketplace Structure

### Discovery: marketplace.json Location
- **Initial assumption:** marketplace.json should be at repository root
- **Reality:** Claude Code expects marketplace.json inside `.claude-plugin/` directory
- **Evidence:** Error message explicitly showed path `.claude-plugin/marketplace.json`

### Discovery: Marketplace Directory Naming
When adding a marketplace via `claude plugin marketplace add owner/repo`:
- Claude Code creates directory: `~/.claude/plugins/marketplaces/{owner}-{repo}/`
- For `terraphim/terraphim-skills` this becomes `terraphim-terraphim-skills`
- The `name` field in marketplace.json does NOT determine the directory name
- This can cause confusion if marketplace was previously added differently

### Pitfall: Documentation vs Reality
- The claude-code-guide agent provided information suggesting marketplace.json at root
- Always verify with actual error messages and behavior over documentation

### Best Practice: Plugin Validation
- Always run `claude plugin validate .` before attempting installation
- Validation passing does not guarantee marketplace discovery will work
- Marketplace discovery has separate requirements from plugin validation

### Debugging Approach That Worked
1. Check exact error message path
2. Inspect `~/.claude/plugins/marketplaces/` to see existing installations
3. Compare expected vs actual directory structures
4. Trace the naming convention (owner-repo format)

### Recommendation for Future
When creating a Claude Code plugin marketplace:
1. Name your GitHub repo to match desired marketplace name
2. Or accept that marketplace directory will be `{owner}-{repo}` format
3. Consider using local path installation during development:
   ```bash
   claude plugin marketplace add /path/to/local/plugin
   ```
