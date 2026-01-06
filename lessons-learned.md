# Lessons Learned

## 2026-01-06: User-Level Hooks Configuration

### Discovery: crates.io vs GitHub Releases Version Gap
- **Issue:** `cargo install terraphim_agent` installs v1.0.0 which lacks `hook` and `guard` commands
- **Solution:** Install from GitHub releases (v1.4.7+) which has all features
- **Pattern:**
  ```bash
  gh release download --repo terraphim/terraphim-ai \
    --pattern "terraphim-agent-aarch64-apple-darwin" --dir /tmp
  mv /tmp/terraphim-agent-aarch64-apple-darwin ~/.cargo/bin/terraphim-agent
  ```

### Discovery: Claude Code Hook Permission Prompt Timing
- **Issue:** Permission prompt shows ORIGINAL command before PreToolUse hook runs
- **Reality:** The hook transformation happens AFTER approval but BEFORE execution
- **Example:** Prompt shows "Claude Code" but commit will have "Terraphim AI"
- **User experience:** Can be confusing - user sees original, gets transformed result

### Discovery: Combined Guard + Replacement Hook Pattern
- **Best practice:** Run guard check FIRST, then replacement
- **Pattern:**
  ```bash
  # Step 1: Guard - block if destructive
  GUARD_RESULT=$($AGENT guard --json <<< "$COMMAND" 2>/dev/null)
  if blocked; then deny; fi

  # Step 2: Replacement - only if guard passed
  $AGENT hook --hook-type pre-tool-use --json <<< "$INPUT"
  ```

### Discovery: User-Level vs Project-Level Settings
- **User-level:** `~/.claude/settings.local.json` - applies to ALL projects
- **Project-level:** `.claude/settings.local.json` - applies to specific project
- **Recommendation:** Put hooks at user-level for consistent behavior

### Discovery: Skill Permissions in settings.local.json
- **Issue:** Skills may require explicit permission to run without prompts
- **Solution:** Add `Skill(plugin-name:skill-name)` to permissions allow list
- **Pattern:**
  ```json
  {
    "permissions": {
      "allow": [
        "Skill(terraphim-engineering-skills:disciplined-research)",
        "Bash(terraphim-agent:*)"
      ]
    }
  }
  ```

### Best Practice: Fail-Open Hook Semantics
- Always use `|| exit 0` or `|| echo '{"decision":"allow"}'` in hooks
- If terraphim-agent is unavailable, command should pass through
- Never block user workflow due to hook infrastructure issues

### Debugging Approach: Test Hook Components Separately
1. Test `terraphim-agent guard --json` directly with command string
2. Test `terraphim-agent hook --hook-type pre-tool-use --json` with full JSON input
3. Test hook script with `echo '{"tool_name":"Bash",...}' | ~/.claude/hooks/pre_tool_use.sh`
4. Only then rely on Claude Code integration

---

## 2026-01-03: Terraphim Hooks Setup

### Discovery: Knowledge Graph Term Format
- **Issue:** Using underscores in filenames (e.g., `bun_install.md`) produces underscored output
- **Solution:** Use spaces in filenames (e.g., `"bun install.md"`) for proper output
- **File naming:** The filename (without .md extension) becomes the replacement text, NOT the heading

### Discovery: terraphim-agent Requires Working Directory
- **Issue:** `terraphim-agent` looks for `docs/src/kg/` relative to current working directory
- **Solution:** Change to `~/.config/terraphim` before running, or create symlinks
- **Hook pattern:**
  ```bash
  cd ~/.config/terraphim 2>/dev/null || exit 0
  terraphim-agent hook --hook-type pre-tool-use --json <<< "$INPUT" 2>/dev/null
  ```

### Discovery: Git Hook Path Resolution
- **Issue:** Git hooks receive relative paths that break after `cd` to another directory
- **Solution:** Convert to absolute path before changing directories:
  ```bash
  COMMIT_MSG_FILE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  ```

### Bug: terraphim-agent Case and Over-Replacement
- **Issue #394:** terraphim-agent lowercases all replacement output regardless of heading case
- **Issue #394:** Replaces text inside URLs and compound terms aggressively
- **Workaround:** Be specific with synonyms (only exact matches you want replaced)
- **Status:** Bug filed at https://github.com/terraphim/terraphim-ai/issues/394

### Best Practice: Installing Released Binaries
```bash
# Download specific platform binary from GitHub releases
gh release download v1.3.0 --repo terraphim/terraphim-ai \
  --pattern "terraphim-agent-aarch64-apple-darwin" --dir /tmp
chmod +x /tmp/terraphim-agent-aarch64-apple-darwin
mv /tmp/terraphim-agent-aarch64-apple-darwin ~/.cargo/bin/terraphim-agent
```

### Debugging Approach: Test Components Separately
1. Test `terraphim-agent replace` directly from config directory
2. Test hook script with echo input before integrating
3. Use `--json` flag for structured output debugging
4. Suppress stderr with `2>/dev/null` in production hooks

---

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
