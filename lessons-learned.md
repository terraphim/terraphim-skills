# Lessons Learned

## 2026-01-17: Blocking --no-verify in PreToolUse Hooks

### Discovery: Regex Pattern Matching vs Commit Message Content
- **Issue:** Initial regex blocked commits where commit MESSAGE contained "--no-verify" as text
- **Example:** `git commit -m "block --no-verify"` was incorrectly blocked
- **Root cause:** Regex matched anywhere in the command string, including quoted message content
- **Solution:** Strip quoted strings BEFORE running pattern match:
  ```bash
  CMD_NO_QUOTES=$(echo "$COMMAND" | sed 's/"[^"]*"//g' | sed "s/'[^']*'//g")
  ```

### Discovery: HEREDOC Expansion Timing
- **Issue:** When using HEREDOC for commit messages, shell expands before hook sees it
- **Example:** `git commit -m "$(cat <<'EOF'\ntext\nEOF)"` becomes a single string
- **Challenge:** The expanded text isn't properly quoted in the final command
- **Workaround:** Avoid mentioning blocked patterns literally in commit messages
- **Better approach:** Use alternative phrasing like "hook bypass flags"

### Discovery: Two-Stage Hook Processing
- **Pattern:** Guard check should run BEFORE replacement transformation
- **Flow:**
  ```
  1. Parse JSON input
  2. Guard check (block if dangerous) -> EXIT if blocked
  3. Replacement transformation (text substitution)
  4. Return modified JSON
  ```
- **Benefit:** Blocked commands never reach replacement stage, reducing complexity

### Best Practice: Testing Hook Changes
When modifying hook scripts, test in this order:
1. **Test blocked patterns are blocked:**
   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"git commit --no-verify"}}' | ~/.claude/hooks/pre_tool_use.sh
   # Should return deny decision
   ```

2. **Test allowed patterns pass through:**
   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"test\""}}' | ~/.claude/hooks/pre_tool_use.sh
   # Should return original or replacement
   ```

3. **Test edge cases (blocked text in message):**
   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"mention --no-verify\""}}' | ~/.claude/hooks/pre_tool_use.sh
   # Should pass through (it's in the message, not a flag)
   ```

### Pitfall: The Hook Tests Itself
- **Irony:** The hook will block you from committing changes that mention "--no-verify"
- **Symptom:** Commit fails with "BLOCKED: --no-verify bypasses git hooks"
- **Workaround:** Use euphemisms in commit messages ("hook bypass flags" instead of "--no-verify")
- **Lesson:** Be careful with guard patterns that match documentation strings

### Debugging Approach That Worked
1. Initial regex too aggressive (matched message content)
2. Added sed to strip quoted strings before pattern match
3. Tested with echo piping JSON through hook script
4. Verified both blocked and allowed cases work correctly
5. Used simpler commit message to avoid self-blocking

### Recommendation: Separate Guard and Replace Scripts
- Current pre_tool_use.sh does two things: guard + replace
- Consider splitting into:
  - `~/.claude/hooks/git_guard.sh` - blocks dangerous commands
  - `~/.claude/hooks/text_replace.sh` - transforms text via knowledge graph
- Would make testing and maintenance easier

---

## 2026-01-14: Troubleshooting Silent Hook Failures

### Discovery: Fail-Open Design Hides Missing Dependencies
- **Issue:** terraphim hook wasn't working but no errors were shown
- **Root cause:** `terraphim-agent` binary was not installed at `~/.cargo/bin/terraphim-agent`
- **Hook behavior:** Silently exits with success (line 40: `[ -z "$AGENT" ] && exit 0`)
- **User experience:** Commands execute normally, but text replacement doesn't happen
- **Lesson:** Fail-open design is great for reliability but terrible for debugging

### Discovery: Installation Requires Two Steps
- **Step 1:** Install the binary from GitHub releases
- **Step 2:** Build the knowledge graph with `terraphim-agent graph --role "Terraphim Engineer"`
- **Common mistake:** Installing binary but forgetting to build knowledge graph
- **Result:** Hook runs but replacements don't happen because thesaurus is missing
- **Pattern:**
  ```bash
  # Install
  gh release download --repo terraphim/terraphim-ai \
    --pattern "terraphim-agent-aarch64-apple-darwin" --dir /tmp
  mv /tmp/terraphim-agent-aarch64-apple-darwin ~/.cargo/bin/terraphim-agent
  chmod +x ~/.cargo/bin/terraphim-agent

  # REQUIRED: Build knowledge graph
  cd ~/.config/terraphim
  terraphim-agent graph --role "Terraphim Engineer"
  ```

### Discovery: Hook Testing Requires Exact JSON Format
- **Issue:** Can't just run hook script directly - needs proper JSON input
- **Solution:** Simulate Claude Code's JSON format:
  ```bash
  echo '{"tool_name":"Bash","tool_input":{"command":"echo Claude Code"}}' | \
    ~/.claude/hooks/pre_tool_use.sh
  ```
- **Tip:** Use `2>/dev/null` to suppress stderr warnings in production
- **Tip:** Use `jq .` to pretty-print JSON output for debugging

### Discovery: terraphim-agent Stderr Warnings Are Normal
- When running `terraphim-agent replace`, multiple WARN messages appear:
  - `embedded_config.json: read failed NotFound`
  - `thesaurus_*.json: read failed NotFound`
- These are logged to stderr and don't affect functionality
- Hook script uses `2>/dev/null` to hide them from users
- JSON output on stdout is always correct despite warnings

### Best Practice: Diagnostic Checklist for Silent Hook Failures
When hooks aren't working, check in this order:
1. **Binary exists:**
   ```bash
   which terraphim-agent
   [ -x "$HOME/.cargo/bin/terraphim-agent" ] && echo "Found" || echo "Missing"
   ```

2. **Binary works:**
   ```bash
   ~/.cargo/bin/terraphim-agent --version
   ```

3. **Knowledge graph exists:**
   ```bash
   ls -la ~/.config/terraphim/docs/src/kg/
   ```

4. **Knowledge graph built:**
   ```bash
   cd ~/.config/terraphim
   ~/.cargo/bin/terraphim-agent graph --role "Terraphim Engineer"
   ```

5. **Replacement works:**
   ```bash
   cd ~/.config/terraphim
   echo "Claude Code" | ~/.cargo/bin/terraphim-agent replace --role "Terraphim Engineer"
   ```

6. **Hook works:**
   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"echo Claude Code"}}' | \
     ~/.claude/hooks/pre_tool_use.sh 2>/dev/null
   ```

### Pitfall: Version Mismatch Between Binary and Documentation
- Previous handover mentioned v1.4.7 from GitHub releases
- This session installed v1.3.0 (latest available release)
- Always check `gh release list --repo terraphim/terraphim-ai` for actual versions
- Don't assume documentation version numbers are current

### Debugging Approach That Worked
1. User reported "hook not triggered" (but didn't specify error)
2. Read hook script to understand logic flow
3. Identified fail-open exit at line 40: `[ -z "$AGENT" ] && exit 0`
4. Checked if binary exists: `which terraphim-agent` (not found)
5. Installed binary from GitHub releases
6. Built knowledge graph (required step often forgotten)
7. Tested each component separately (replace, guard, hook)
8. Verified end-to-end with full JSON input simulation

### Recommendation for Future: Improve Hook Observability
**Problem:** Silent failures make troubleshooting require deep technical knowledge

**Potential solutions:**
1. Add debug mode that logs missing dependencies to a file
2. Create health check command: `terraphim-agent health --check-hooks`
3. Hook could log to `~/.claude/hooks/pre_tool_use.log` when agent missing
4. Claude Code could show hook status in UI (installed vs active vs failing)

---

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
