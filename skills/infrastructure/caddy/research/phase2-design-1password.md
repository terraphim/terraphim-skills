# Design & Implementation Plan: 1Password Secret Management Skill

**Date:** 2025-12-29
**Phase:** 2 - Disciplined Design
**Depends On:** Phase 1 Research (completed)

## 1. Summary of Target Behavior

A comprehensive Claude Code skill that provides secure secret management using 1Password CLI (`op`). The skill will:

1. **Detect plaintext secrets** in environment files, configs, and codebases
2. **Generate templates** converting `.env` files to `.env.template` with `op://` references
3. **Inject secrets** using `op inject` for one-time secret substitution
4. **Run commands** using `op run --no-masking` for process execution with secrets
5. **Audit configurations** to ensure no plaintext secrets exist
6. **Provide patterns** for safe secret handling across different tools (systemd, Docker, shell)

The skill enforces the user's CLAUDE.md mandate: "never overwrite .env files, use op inject if required or op run --no-masking to start services."

## 2. Key Invariants and Acceptance Criteria

### Invariants

**INV-1: Secret Safety**
- NEVER display plaintext secret values in output
- NEVER write plaintext secrets to files
- ALWAYS use `op://vault/item/field` references in templates

**INV-2: Non-Destructive**
- NEVER overwrite existing `.env` files
- ALWAYS create new files (`.env.template`, `.env.op`)
- ALWAYS backup before any modifications

**INV-3: Validation**
- ALWAYS verify `op` CLI is installed before operations
- ALWAYS validate `op://` reference syntax
- ALWAYS check 1Password session is active

**INV-4: Auditability**
- ALWAYS log what secrets were detected/converted
- ALWAYS show before/after comparisons (with secrets masked)
- ALWAYS provide rollback guidance

### Acceptance Criteria

**AC-1: Secret Detection**
- Given a file path, detect common secret patterns (API keys, tokens, passwords, certificates)
- Report location (file:line) and secret type
- Provide confidence score (high/medium/low)

**AC-2: Template Generation**
- Given `.env` file, generate `.env.template` with `op://` references
- Preserve non-secret variables unchanged
- Suggest 1Password vault/item/field structure
- Provide guidance on creating 1Password items

**AC-3: Secret Injection**
- Given `.env.template`, inject secrets using `op inject`
- Output to specified location or stdout
- Support multiple input files
- Handle missing secrets gracefully (error with clear message)

**AC-4: Command Execution**
- Given a command, execute with `op run --no-masking`
- Support systemd service starts
- Support Docker Compose
- Support arbitrary shell commands
- Preserve exit codes and output

**AC-5: Audit Mode**
- Scan directory tree for plaintext secrets
- Report all findings with severity
- Suggest remediation for each finding
- Export results as JSON or markdown

**AC-6: Systemd Integration**
- Generate systemd service file using 1Password
- Support `EnvironmentFile` with template injection
- Support `ExecStart` with `op run` wrapper
- Validate service file syntax

## 3. High-Level Design and Boundaries

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              1Password Secret Management Skill               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Secret     │  │   Template   │  │   Command    │      │
│  │   Detector   │  │   Generator  │  │   Runner     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │             │
│         └──────────────────┴──────────────────┘             │
│                        │                                    │
│              ┌─────────▼─────────┐                          │
│              │   op CLI Wrapper  │                          │
│              └───────────────────┘                          │
│                        │                                    │
└────────────────────────┼────────────────────────────────────┘
                         │
                         ▼
                ┌─────────────────┐
                │  1Password CLI  │
                │  (op command)   │
                └─────────────────┘
```

### Component Responsibilities

**Secret Detector**
- Scan files for secret patterns using regex
- Classify secrets by type (API key, token, password, certificate, private key)
- Calculate confidence scores
- Output structured findings

**Template Generator**
- Parse environment files (`.env`, `.yaml`, `.json`, systemd `EnvironmentFile`)
- Identify secret vs non-secret variables
- Generate `op://` references with suggested structure
- Preserve comments and formatting
- Create migration guide

**Command Runner**
- Wrap commands with `op run --no-masking`
- Handle systemd service operations
- Support Docker Compose operations
- Preserve command output and exit codes
- Provide error context when secrets are missing

**op CLI Wrapper**
- Check `op` installation and version
- Validate 1Password session (signed in)
- Execute `op inject`, `op run`, `op read` commands
- Handle errors gracefully
- Never log secret values

### Boundaries

**IN SCOPE:**
- Environment file formats: `.env`, `.yaml`, `.json`, systemd `EnvironmentFile`
- Command execution: systemd, Docker Compose, shell commands
- Secret detection: common patterns (keys, tokens, passwords, certificates)
- Template generation: `op://` reference syntax
- Audit reports: markdown and JSON formats

**OUT OF SCOPE:**
- Creating 1Password vaults/items (user must do this)
- Password strength analysis
- Secret rotation automation
- Integration with other secret managers (Vault, AWS Secrets Manager)
- Encryption/decryption operations

## 4. File/Module-Level Change Plan

| File Path | Action | Responsibility | Dependencies |
|-----------|--------|----------------|--------------|
| `~/.claude/skills/1password-secrets.md` | Create | Main skill documentation and workflows | None |
| `~/.docs/1password-skill/secret-patterns.json` | Create | Secret detection patterns database | None |
| `~/.docs/1password-skill/examples/` | Create | Example templates and conversions | None |

### Skill File Structure

```markdown
~/.claude/skills/1password-secrets.md
├── Overview and Purpose
├── Prerequisites (op CLI installation)
├── Workflow 1: Detect Secrets
├── Workflow 2: Generate Template
├── Workflow 3: Inject Secrets
├── Workflow 4: Run Commands with Secrets
├── Workflow 5: Audit Codebase
├── Workflow 6: Systemd Integration
├── Common Patterns
├── Troubleshooting
└── Security Best Practices
```

### Tool Usage

**Tools Available:**
- `Bash`: Execute `op` CLI commands, grep patterns
- `Read`: Read files to scan for secrets
- `Write`: Create template files
- `Edit`: Modify configuration files (with backup)
- `Grep`: Search for secret patterns
- `Glob`: Find files to scan

**Tool Responsibilities:**

| Tool | Usage | Example |
|------|-------|---------|
| Bash | Execute `op` commands | `op inject -i template -o output` |
| Read | Read files for scanning | Read `.env` file line by line |
| Write | Create template files | Write `.env.template` |
| Grep | Search for secret patterns | `grep -r "API_KEY=" .` |
| Glob | Find env files | `**/*.env` |

## 5. Step-by-Step Implementation Sequence

### Step 1: Create Secret Pattern Database
**Purpose:** Define regex patterns for detecting common secrets
**Deployable:** Yes (documentation only)

1. Create `/Users/alex/.docs/1password-skill/secret-patterns.json`
2. Define patterns for:
   - API keys (AWS, GitHub, Stripe, etc.)
   - OAuth secrets/tokens
   - JWT secrets
   - Database passwords
   - Private keys (PEM, RSA)
   - Certificate data
   - Basic auth credentials

### Step 2: Create Skill File with Detection Workflow
**Purpose:** Implement secret detection functionality
**Deployable:** Yes (read-only operations)

1. Create `~/.claude/skills/1password-secrets.md`
2. Document skill purpose and prerequisites
3. Implement "Workflow 1: Detect Secrets" section:
   - Check `op` CLI is installed (`which op`)
   - Read target file
   - Apply regex patterns
   - Report findings with file:line:type
   - Never display secret values

**Example interaction:**
```
User: "Scan /path/to/.env for secrets"
Skill:
1. Reads file
2. Applies patterns
3. Outputs:
   Found 3 secrets:
   - .env:1 GITHUB_SECRET (high confidence)
   - .env:5 JWT_KEY (high confidence)
   - .env:12 API_TOKEN (medium confidence)
```

### Step 3: Implement Template Generation Workflow
**Purpose:** Convert files to 1Password templates
**Deployable:** Yes (creates new files, doesn't modify originals)

1. Add "Workflow 2: Generate Template" section
2. Read source file (e.g., `.env`)
3. For each line:
   - If secret detected: convert to `op://vault/item/field` reference
   - If non-secret: preserve as-is
   - If comment: preserve
4. Write to `.env.template`
5. Generate migration guide showing:
   - Required 1Password structure
   - Commands to create items
   - Verification steps

**Example interaction:**
```
User: "Generate template from /path/to/.env"
Skill:
1. Reads .env
2. Detects secrets
3. Creates .env.template with op:// refs
4. Shows migration guide:

   Create 1Password items:
   $ op item create --category=Login \
     --title="GitHub OAuth" \
     --vault="Terraphim" \
     client_id=<value> \
     client_secret=<value>
```

### Step 4: Implement Secret Injection Workflow
**Purpose:** Use `op inject` to populate templates
**Deployable:** Yes (read-only on 1Password)

1. Add "Workflow 3: Inject Secrets" section
2. Validate `op` session is active
3. Use `op inject -i input.template -o output.env`
4. Verify output file created
5. Remind user to add output to `.gitignore`

**Safety checks:**
- Never overwrite existing `.env` files
- Output to temp location or explicit path
- Validate template syntax before injection

### Step 5: Implement Command Runner Workflow
**Purpose:** Execute commands with secrets using `op run`
**Deployable:** Yes (execution context)

1. Add "Workflow 4: Run Commands with Secrets" section
2. Wrap command with `op run --no-masking -- <command>`
3. Support common patterns:
   - `op run --no-masking -- systemctl start service`
   - `op run --no-masking -- docker-compose up`
   - `op run --no-masking -- ./script.sh`
4. Preserve output and exit codes
5. Handle errors (missing secrets, auth failures)

### Step 6: Implement Audit Workflow
**Purpose:** Scan entire codebase for secrets
**Deployable:** Yes (read-only)

1. Add "Workflow 5: Audit Codebase" section
2. Use `Glob` to find all relevant files
3. Scan each file with detection patterns
4. Generate report:
   - Summary (total secrets found, by type)
   - Detailed findings (file:line:type:confidence)
   - Remediation suggestions
5. Export as markdown or JSON

### Step 7: Implement Systemd Integration Patterns
**Purpose:** Show how to use 1Password with systemd services
**Deployable:** Yes (documentation + examples)

1. Add "Workflow 6: Systemd Integration" section
2. Document two patterns:

   **Pattern A: EnvironmentFile with template**
   ```systemd
   [Service]
   ExecStartPre=/bin/sh -c 'op inject -i /path/to/service.env.template -o /tmp/service.env'
   EnvironmentFile=/tmp/service.env
   ExecStart=/path/to/service
   ```

   **Pattern B: ExecStart with op run**
   ```systemd
   [Service]
   ExecStart=/usr/bin/op run --no-masking -- /path/to/service
   ```

3. Provide systemd service generator
4. Validate service file syntax

### Step 8: Add Common Patterns and Best Practices
**Purpose:** Document proven patterns for various use cases
**Deployable:** Yes (documentation)

1. Add "Common Patterns" section:
   - Docker Compose with secrets
   - Shell scripts with secrets
   - Caddy with environment files
   - CI/CD integration
   - Development vs production patterns

2. Add "Security Best Practices":
   - Always use templates, never commit secrets
   - Use `.gitignore` for generated files
   - Regular audits with audit workflow
   - Principle of least privilege (1Password vaults)
   - Secret rotation guidance

### Step 9: Create Example Files
**Purpose:** Provide working examples users can reference
**Deployable:** Yes

1. Create `/Users/alex/.docs/1password-skill/examples/`
2. Add examples:
   - `example.env` (with fake secrets)
   - `example.env.template` (with op:// refs)
   - `example-systemd.service` (with 1Password integration)
   - `example-docker-compose.yml` (with secrets)
   - `migration-guide.md` (step-by-step)

### Step 10: Test All Workflows
**Purpose:** Verify skill works end-to-end
**Deployable:** Yes (testing phase)

1. Test detection with known secret files
2. Test template generation with various formats
3. Test injection with test vault/items
4. Test command execution
5. Test audit on sample codebase
6. Document any issues found

## 6. Testing & Verification Strategy

| Acceptance Criteria | Test Type | Test Approach |
|---------------------|-----------|---------------|
| AC-1: Secret Detection | Unit | Test regex patterns against known secret formats |
| AC-1: Secret Detection | Integration | Scan test files with various secret types |
| AC-2: Template Generation | Unit | Verify op:// reference syntax |
| AC-2: Template Generation | Integration | Convert test .env file, verify output |
| AC-3: Secret Injection | Integration | Inject test template, verify values |
| AC-4: Command Execution | Integration | Execute test command with op run |
| AC-5: Audit Mode | Integration | Audit test codebase, verify findings |
| AC-6: Systemd Integration | Manual | Generate service file, verify with systemd-analyze |

### Test Data

Create test suite in `/Users/alex/.docs/1password-skill/tests/`:

```
tests/
├── fixtures/
│   ├── test.env (with fake secrets)
│   ├── test-no-secrets.env
│   ├── test-mixed.env
│   └── test-systemd.service
├── expected/
│   ├── test.env.template (expected output)
│   └── audit-report.md
└── test-vault/ (1Password test items)
```

### Validation Checklist

- [ ] `op` CLI detection works on all systems (local, bigbox, registry)
- [ ] Secret patterns detect common formats (API keys, tokens, passwords)
- [ ] Template generation preserves non-secret values
- [ ] Template generation suggests correct 1Password structure
- [ ] Injection fails gracefully when secrets missing
- [ ] Injection never overwrites existing files
- [ ] Command runner preserves exit codes
- [ ] Audit reports all secret types
- [ ] Systemd integration works with both patterns
- [ ] No plaintext secrets ever displayed in output

## 7. Risk & Complexity Review

| Risk | Mitigation | Residual Risk |
|------|------------|---------------|
| **RISK-1: False Positives** Detecting non-secrets as secrets | Use confidence scores, allow user review before conversion | Low: User reviews before template generation |
| **RISK-2: False Negatives** Missing actual secrets | Comprehensive regex patterns, regular pattern updates | Medium: New secret formats may be missed |
| **RISK-3: Secret Exposure** Accidentally displaying plaintext secrets | Never display detected values, always mask output | Low: Code review ensures no logging |
| **RISK-4: File Overwrite** Accidentally overwriting original files | Always create new files (.template, .op), never modify originals | Very Low: Design prevents overwrites |
| **RISK-5: 1Password Session** Op session expires during operation | Check session before each operation, provide clear error | Low: User can re-authenticate |
| **RISK-6: Invalid op:// References** Generated references don't match 1Password structure | Validate reference syntax, provide clear examples | Medium: User must create items correctly |
| **RISK-7: Command Failure** Commands fail with op run wrapper | Preserve exit codes, show clear error messages | Low: Standard error handling |
| **RISK-8: Audit Performance** Scanning large codebases is slow | Use Grep tool for performance, limit recursion depth | Low: Acceptable for manual audits |
| **RISK-9: Complex File Formats** YAML/JSON parsing errors | Start with .env format only, add formats iteratively | Medium: Advanced formats may fail |
| **RISK-10: Systemd Permissions** Service can't access op CLI | Document required permissions, test patterns | Medium: Systemd context may lack op access |

### Complexity Assessment

**Low Complexity:**
- Secret detection (regex patterns)
- Template generation (.env format)
- Command wrapping (op run)

**Medium Complexity:**
- Audit workflow (directory traversal, reporting)
- Systemd integration (service file generation)
- Multi-format support (YAML, JSON)

**High Complexity:**
- False positive reduction (machine learning not in scope)
- Automatic 1Password item creation (out of scope)
- Secret rotation automation (out of scope)

### Simplification Opportunities

1. **Start with .env format only**: Add YAML/JSON later if needed
2. **Manual 1Password item creation**: Provide clear guide, don't automate
3. **Simple regex patterns**: Don't try to detect every possible secret format
4. **User confirmation**: Always show detected secrets (masked) before conversion

## 8. Open Questions / Decisions for Human Review

### Critical Questions

**Q1: Secret Pattern Scope**
Should the skill detect cloud-specific secrets (AWS, GCP, Azure) or focus on generic patterns (API_KEY, TOKEN, SECRET)?

**Recommendation:** Start generic, add cloud-specific patterns as separate module later.

**Q2: 1Password Vault Structure**
Should the skill enforce a specific vault/item/field naming convention, or let users choose?

**Recommendation:** Suggest convention in examples, but allow flexibility. Provide guide for creating consistent structure.

**Q3: Systemd Integration Pattern**
Pattern A (EnvironmentFile + op inject) or Pattern B (op run wrapper)?

**Recommendation:** Document both, recommend Pattern B (simpler, fewer files). User can choose based on needs.

**Q4: Audit Report Format**
Markdown for humans or JSON for automation, or both?

**Recommendation:** Both. Default to markdown for readability, provide `--json` flag for tooling integration.

**Q5: Existing Secrets Migration**
Should skill help migrate existing plaintext secrets to 1Password (with prompts for values)?

**Recommendation:** Out of scope for v1. Provide clear manual migration guide instead. Too risky to automate.

### Non-Critical Questions

**Q6: Integration with Git**
Should skill auto-update `.gitignore` to exclude generated files?

**Recommendation:** No. Provide checklist reminding user to add entries. Don't modify version control automatically.

**Q7: Secret Strength Validation**
Should skill warn about weak secrets (short passwords, simple tokens)?

**Recommendation:** Out of scope. 1Password already handles this. Keep skill focused on detection and management.

**Q8: Multiple Environment Support**
How to handle dev/staging/prod environments with different secrets?

**Recommendation:** Use separate 1Password vaults or item tags. Document pattern in "Common Patterns" section.

## Approval Checklist

Before proceeding to Phase 3 (Implementation), confirm:

- [ ] Scope is clear and achievable
- [ ] Tool usage (Bash, Read, Write) is appropriate
- [ ] Secret safety invariants are acceptable
- [ ] Risk mitigations are sufficient
- [ ] Testing strategy is comprehensive
- [ ] Documentation structure makes sense
- [ ] Open questions are resolved

**Do you approve this plan as-is, or would you like to adjust any part?**

---

**Next Phase:** Once approved, Phase 3 (Disciplined Implementation) will create the actual skill file following this design.
