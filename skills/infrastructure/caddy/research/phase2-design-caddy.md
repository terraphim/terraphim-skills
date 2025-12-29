# Design & Implementation Plan: Caddy Server Management Skill

**Date:** 2025-12-29
**Phase:** 2 - Disciplined Design
**Depends On:** Phase 1 Research (completed), 1Password Secret Management Skill (designed)

## 1. Summary of Target Behavior

A comprehensive Claude Code skill that manages Caddy web server across multiple environments (local development, bigbox production, registry production). The skill will:

1. **Discover Caddyfiles** across 3 servers using fast search (mdfind locally, find on remote)
2. **Validate syntax** before deployment to prevent downtime
3. **Format Caddyfiles** for consistency
4. **Manage lifecycle** via systemd (start, stop, reload, status)
5. **Migrate bigbox** from tmux to systemd management
6. **Build custom Caddy** using xcaddy with required plugins
7. **Analyze logs** for errors and troubleshooting
8. **Extract snippets** to reduce duplication (DRY principle)
9. **Integrate secrets** via 1Password skill
10. **Provide patterns** for common use cases (reverse proxy, auth, WebSocket, TLS)

The skill enforces zero-downtime reloads, mandatory validation, and 1Password integration for all secrets.

## 2. Key Invariants and Acceptance Criteria

### Invariants

**INV-1: Zero-Downtime Operations**
- ALWAYS use `caddy reload` instead of restart
- ALWAYS validate configuration before reload
- ALWAYS check service status after reload
- NEVER kill running Caddy process without graceful shutdown

**INV-2: Validation-First**
- ALWAYS validate Caddyfile syntax before deployment
- ALWAYS use `caddy validate` command
- ALWAYS show validation errors clearly
- NEVER deploy invalid configuration

**INV-3: Secret Safety (via 1Password Skill)**
- ALWAYS use 1Password skill for secret management
- NEVER display plaintext secrets in Caddyfile output
- ALWAYS detect secrets in configurations
- ALWAYS recommend 1Password migration for plaintext secrets

**INV-4: Multi-Server Awareness**
- ALWAYS detect which server context (local, bigbox, registry)
- ALWAYS use appropriate SSH for remote operations
- ALWAYS respect server-specific paths and binaries
- NEVER assume local commands work on remote servers

**INV-5: Backup-First**
- ALWAYS backup Caddyfile before modifications
- ALWAYS provide rollback instructions
- ALWAYS use timestamped backups
- NEVER lose working configurations

### Acceptance Criteria

**AC-1: Caddyfile Discovery**
- Given a server name (local, bigbox, registry), find all Caddyfiles in <5 seconds
- Return file paths sorted by relevance (active configs first)
- Exclude backup files (*.backup.*)
- Support glob patterns for filtering

**AC-2: Configuration Validation**
- Given a Caddyfile path, validate syntax using `caddy validate`
- Report errors with line numbers
- Check for common issues (missing blocks, invalid directives)
- Verify environment variables are defined (or use 1Password)

**AC-3: Safe Deployment**
- Given a validated Caddyfile, reload gracefully
- Verify service is running before reload
- Check service status after reload
- Rollback on failure

**AC-4: Custom Build Management**
- Install xcaddy if not present
- Build Caddy with required plugins (security, cloudflare, cgi, tlsredis)
- Verify build success
- Install binary to appropriate location

**AC-5: Systemd Migration (bigbox)**
- Stop tmux-based Caddy process
- Configure systemd service with 1Password integration
- Start systemd service
- Verify migration success
- Provide rollback to tmux if needed

**AC-6: Log Analysis**
- Parse JSON logs for errors
- Show recent activity (last N entries)
- Filter by domain or endpoint
- Detect common issues (cert failures, upstream errors)

**AC-7: Snippet Extraction**
- Given multiple Caddyfiles, identify common patterns
- Extract to snippet files
- Generate import statements
- Verify snippets work

**AC-8: Pattern Library**
- Provide ready-to-use patterns for:
  - Reverse proxy with health checks
  - OAuth/JWT authentication
  - WebSocket support
  - Security headers
  - Static file serving with caching
  - CORS configuration

## 3. High-Level Design and Boundaries

### Architecture

```
┌──────────────────────────────────────────────────────────────┐
│               Caddy Server Management Skill                   │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌───────────────┐  ┌────────────┐  ┌──────────────────┐   │
│  │   Discovery   │  │ Validation │  │    Lifecycle     │   │
│  │    Engine     │  │   Engine   │  │    Manager       │   │
│  └───────────────┘  └────────────┘  └──────────────────┘   │
│         │                   │                  │             │
│  ┌───────────────┐  ┌────────────┐  ┌──────────────────┐   │
│  │  Build        │  │ Log        │  │   Snippet        │   │
│  │  Manager      │  │ Analyzer   │  │   Extractor      │   │
│  └───────────────┘  └────────────┘  └──────────────────┘   │
│         │                   │                  │             │
│         └───────────────────┴──────────────────┘             │
│                        │                                     │
│              ┌─────────▼──────────┐                          │
│              │  Server Context    │                          │
│              │  (local/ssh)       │                          │
│              └────────────────────┘                          │
│                        │                                     │
└────────────────────────┼─────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
   ┌─────────┐    ┌─────────┐    ┌─────────┐
   │  Local  │    │ bigbox  │    │registry │
   │ (macOS) │    │(systemd)│    │(systemd)│
   └─────────┘    └─────────┘    └─────────┘
```

### Component Responsibilities

**Discovery Engine**
- Find Caddyfiles using fast search (mdfind/find)
- Detect active configuration (check systemd service)
- Filter by pattern (environment, variant)
- Return sorted results (active first, then by modification time)

**Validation Engine**
- Execute `caddy validate --config <path>`
- Parse validation errors
- Check for common mistakes (syntax, directives, blocks)
- Verify environment variables (coordinate with 1Password skill)
- Report issues clearly

**Lifecycle Manager**
- Check Caddy service status (systemd)
- Start/stop/reload services
- Verify operations succeeded
- Handle tmux-based processes (for migration)
- Provide rollback on failure

**Build Manager**
- Check for xcaddy installation
- Install xcaddy if needed
- Execute build with required plugins
- Verify build artifacts
- Install binary to target location

**Log Analyzer**
- Read JSON log files
- Parse access logs (requests, status codes, response times)
- Parse error logs (errors, warnings)
- Filter by time range, domain, status code
- Detect patterns (repeated errors, slow endpoints)

**Snippet Extractor**
- Parse multiple Caddyfiles
- Identify repeated blocks (security headers, logging, TLS config)
- Extract to snippet files (snippets/name.caddy)
- Generate import statements
- Verify extracted snippets are valid

**Server Context**
- Detect current environment (local, bigbox, registry)
- Provide appropriate command wrappers (local vs SSH)
- Handle path differences (/usr/bin/caddy vs /home/alex/caddy_terraphim/caddy)
- Respect server-specific configurations

### Boundaries

**IN SCOPE:**
- Finding and managing Caddyfiles (3 servers)
- Syntax validation and formatting
- Systemd service management
- Custom builds with xcaddy
- Log analysis (JSON format)
- Snippet extraction (common patterns)
- Migration from tmux to systemd (bigbox only)
- Integration with 1Password skill

**OUT OF SCOPE:**
- Automated certificate management (Caddy handles this)
- DNS record management (Cloudflare API)
- Network configuration (firewall rules)
- Infrastructure as code (Terraform/Ansible)
- Custom Caddy plugin development
- Database migrations
- Frontend application deployment

### Dependencies

**Hard Dependencies:**
- 1Password Secret Management Skill (for secret handling)
- Caddy binary (v2.6+ on servers)
- systemd (for service management)
- SSH access to bigbox and registry

**Soft Dependencies:**
- xcaddy (for custom builds, can be installed)
- Go toolchain (for xcaddy)
- jq (for JSON log parsing, usually available)

## 4. File/Module-Level Change Plan

| File Path | Action | Responsibility | Dependencies |
|-----------|--------|----------------|--------------|
| `~/.claude/skills/caddy.md` | Create | Main skill documentation and workflows | 1Password skill |
| `~/.docs/caddy-skill/servers.json` | Create | Server configuration (paths, SSH, binaries) | None |
| `~/.docs/caddy-skill/patterns/` | Create | Caddyfile pattern library | None |
| `~/.docs/caddy-skill/snippets/` | Create | Extracted common snippets | None |
| `~/.docs/caddy-skill/migration-plan-bigbox.md` | Create | Systemd migration guide for bigbox | None |

### Skill File Structure

```markdown
~/.claude/skills/caddy.md
├── Overview and Purpose
├── Prerequisites
├── Server Configuration
│   ├── Local (macOS)
│   ├── bigbox (production)
│   └── registry (production)
├── Workflow 1: Discover Caddyfiles
├── Workflow 2: Validate Configuration
├── Workflow 3: Format Caddyfile
├── Workflow 4: Deploy Changes (reload)
├── Workflow 5: Build Custom Caddy
├── Workflow 6: Analyze Logs
├── Workflow 7: Extract Snippets
├── Workflow 8: Migrate to Systemd (bigbox)
├── Pattern Library
│   ├── Reverse Proxy
│   ├── Authentication (OAuth, JWT, Basic)
│   ├── WebSocket Support
│   ├── Security Headers
│   ├── Static File Serving
│   └── CORS Configuration
├── Troubleshooting
├── Common Issues and Solutions
└── Integration with 1Password
```

### Server Configuration File

`~/.docs/caddy-skill/servers.json`:
```json
{
  "local": {
    "name": "local",
    "ssh": null,
    "caddy_binary": "/usr/local/bin/caddy",
    "search_paths": [
      "/Users/alex/projects/"
    ],
    "search_command": "mdfind -name Caddyfile",
    "systemd": false
  },
  "bigbox": {
    "name": "bigbox",
    "ssh": "bigbox",
    "caddy_binary": "/home/alex/caddy_terraphim/caddy",
    "config_path": "/home/alex/caddy_terraphim/conf/Caddyfile_auth",
    "systemd_service": "caddy-terraphim",
    "log_path": "/home/alex/caddy_terraphim/log/",
    "search_paths": [
      "/home/alex/caddy_terraphim/",
      "/home/alex/infrastructure/"
    ],
    "systemd": true,
    "migration_needed": true
  },
  "registry": {
    "name": "registry",
    "ssh": "registry",
    "caddy_binary": "/usr/bin/caddy",
    "config_path": "/etc/caddy/Caddyfile",
    "systemd_service": "caddy",
    "log_path": "/var/log/caddy/",
    "search_paths": [
      "/etc/caddy/",
      "/home/alex/infrastructure/"
    ],
    "systemd": true
  }
}
```

### Tool Usage

| Tool | Usage | Example |
|------|-------|---------|
| Bash | Execute caddy commands, SSH operations | `ssh bigbox "caddy validate"` |
| Read | Read Caddyfiles for validation | Read Caddyfile to check syntax |
| Write | Create snippet files, configs | Write extracted snippets |
| Edit | Modify Caddyfiles with backups | Edit config with safety checks |
| Grep | Search for patterns in configs | `grep -r "reverse_proxy" .` |
| Glob | Find Caddyfiles quickly | `**/Caddyfile*` |

## 5. Step-by-Step Implementation Sequence

### Phase A: Foundation (Steps 1-3)

#### Step 1: Create Server Configuration
**Purpose:** Define server-specific settings
**Deployable:** Yes (configuration only)

1. Create `/Users/alex/.docs/caddy-skill/servers.json`
2. Define configuration for local, bigbox, registry
3. Include paths, binaries, SSH details
4. Document configuration schema

#### Step 2: Create Skill File with Discovery Workflow
**Purpose:** Find Caddyfiles across servers
**Deployable:** Yes (read-only operations)

1. Create `~/.claude/skills/caddy.md`
2. Document prerequisites (Caddy installed, SSH configured)
3. Implement "Workflow 1: Discover Caddyfiles":
   - Accept server name (local|bigbox|registry) or "all"
   - Use fast search (mdfind locally, find remotely)
   - Filter out backup files
   - Detect active configuration
   - Sort results (active first)
   - Display with metadata (lines, modified date)

**Example interaction:**
```
User: "Find all Caddyfiles on bigbox"
Skill:
1. Reads servers.json config
2. Executes: ssh bigbox "find /home/alex -name 'Caddyfile*' ! -name '*.backup.*'"
3. Outputs sorted list:
   ✓ /home/alex/caddy_terraphim/conf/Caddyfile_auth (ACTIVE, 324 lines)
   /home/alex/infrastructure/atomic-server-turso/Caddyfile.enhanced (112 lines)
   ...
```

#### Step 3: Implement Validation Workflow
**Purpose:** Validate Caddyfile syntax before deployment
**Deployable:** Yes (read-only operations)

1. Add "Workflow 2: Validate Configuration"
2. Read target Caddyfile
3. Execute `caddy validate --config <path>` (local or SSH)
4. Parse validation output
5. Check for environment variables (coordinate with 1Password skill if needed)
6. Report results clearly:
   - ✓ Valid configuration
   - ✗ Syntax error at line X
   - ⚠ Missing environment variable

**Safety checks:**
- Verify Caddy binary exists
- Handle validation errors gracefully
- Never modify files during validation

### Phase B: Core Operations (Steps 4-6)

#### Step 4: Implement Format Workflow
**Purpose:** Format Caddyfile for consistency
**Deployable:** Yes (creates backup first)

1. Add "Workflow 3: Format Caddyfile"
2. Create timestamped backup
3. Execute `caddy fmt --overwrite <path>`
4. Verify formatting succeeded
5. Show diff (before/after)
6. Provide rollback instructions

**Safety checks:**
- Always backup before formatting
- Validate after formatting
- Never format active config without confirmation

#### Step 5: Implement Deployment Workflow
**Purpose:** Deploy configuration changes safely
**Deployable:** Yes (production operation)

1. Add "Workflow 4: Deploy Changes"
2. Pre-deployment checks:
   - Validate configuration
   - Check service is running
   - Detect if secrets need 1Password migration
3. Execute graceful reload:
   - `systemctl reload <service>` (or `caddy reload` directly)
4. Post-deployment verification:
   - Check service status
   - Check logs for errors
   - Verify endpoints respond
5. Rollback on failure:
   - Restore backup
   - Reload previous config
   - Report issue

**Example interaction:**
```
User: "Deploy Caddyfile changes to bigbox"
Skill:
1. Validates configuration ✓
2. Detects plaintext secrets ⚠ (suggests 1Password migration)
3. Creates backup
4. Executes: ssh bigbox "systemctl reload caddy-terraphim"
5. Verifies status ✓
6. Checks logs ✓
7. Reports: Deployed successfully, 0 requests dropped
```

#### Step 6: Implement Status Checking
**Purpose:** Check Caddy service health
**Deployable:** Yes (read-only)

1. Add "Workflow: Check Status"
2. Execute `systemctl status <service>`
3. Parse output:
   - Running/stopped/failed
   - Uptime
   - Memory usage
   - Recent logs
4. Check listening ports
5. Test health endpoints if defined

### Phase C: Advanced Features (Steps 7-10)

#### Step 7: Implement Build Workflow
**Purpose:** Build custom Caddy with plugins
**Deployable:** Yes (creates binary)

1. Add "Workflow 5: Build Custom Caddy"
2. Check if xcaddy is installed
3. If not, guide installation:
   ```bash
   go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
   ```
4. Execute build:
   ```bash
   xcaddy build \
     --with github.com/greenpau/caddy-security \
     --with github.com/gamalan/caddy-tlsredis \
     --with github.com/caddy-dns/cloudflare \
     --with github.com/aksdb/caddy-cgi/v2
   ```
5. Verify build output
6. Optionally install to target location
7. Provide version info

**Safety checks:**
- Backup existing binary
- Verify Go toolchain available
- Test built binary with `--version`
- Don't replace active binary without confirmation

#### Step 8: Implement Log Analysis
**Purpose:** Analyze JSON logs for troubleshooting
**Deployable:** Yes (read-only)

1. Add "Workflow 6: Analyze Logs"
2. Support multiple log types:
   - Access logs (requests, status codes)
   - Error logs
3. Use jq for JSON parsing
4. Provide filters:
   - Time range (last N minutes/hours)
   - Domain/endpoint
   - Status code (errors only, 500s, etc.)
   - Search term
5. Show summary:
   - Total requests
   - Error rate
   - Top endpoints
   - Slow requests
6. Detect common issues:
   - Upstream connection failures
   - Certificate errors
   - Rate limit hits

**Example interaction:**
```
User: "Show errors from bigbox logs in last hour"
Skill:
1. Reads log path from servers.json
2. Executes: ssh bigbox "tail -n 1000 /home/alex/caddy_terraphim/log/*.log | jq 'select(.level==\"ERROR\")'"
3. Outputs:
   Found 3 errors:
   - 14:23:45 alpha.truthforge: upstream connection refused (localhost:3000)
   - 14:25:12 ci.terraphim: certificate validation failed
   - 14:30:01 logs.terraphim: authentication failed (basic auth)
```

#### Step 9: Implement Snippet Extraction
**Purpose:** Extract common patterns to snippets (DRY)
**Deployable:** Yes (creates new files)

1. Add "Workflow 7: Extract Snippets"
2. Analyze multiple Caddyfiles
3. Identify repeated blocks:
   - Security headers
   - Logging configuration
   - TLS settings
   - Reverse proxy patterns
4. Extract to snippet files:
   - `snippets/security-headers.caddy`
   - `snippets/json-logging.caddy`
   - `snippets/reverse-proxy-base.caddy`
5. Generate import statements
6. Validate snippets work
7. Show refactoring suggestions

**Example:**
```
Original (repeated in 5 files):
header {
  Strict-Transport-Security "max-age=31536000"
  X-Content-Type-Options "nosniff"
  ...
}

After extraction:
(security-headers) {
  header {
    Strict-Transport-Security "max-age=31536000"
    X-Content-Type-Options "nosniff"
    ...
  }
}

Usage:
site.com {
  import security-headers
  reverse_proxy backend:3000
}
```

#### Step 10: Implement Systemd Migration (bigbox)
**Purpose:** Migrate bigbox from tmux to systemd
**Deployable:** Yes (production operation, high risk)

1. Add "Workflow 8: Migrate to Systemd"
2. Pre-migration checks:
   - Verify systemd service file exists
   - Validate Caddyfile
   - Migrate secrets to 1Password (via 1Password skill)
   - Backup current state
3. Migration steps:
   - Find tmux session with Caddy
   - Stop tmux-based Caddy gracefully
   - Update systemd service to use 1Password:
     ```systemd
     ExecStart=/usr/bin/op run --no-masking -- /home/alex/caddy_terraphim/caddy run --config /home/alex/caddy_terraphim/conf/Caddyfile_auth
     ```
   - Start systemd service
   - Enable for auto-start
4. Post-migration verification:
   - Service is running
   - Endpoints respond
   - Logs are clean
   - No requests dropped
5. Provide rollback instructions (restart tmux)

**Safety measures:**
- Document every step
- Provide rollback script
- Test in low-traffic window
- Keep tmux session available for quick rollback

### Phase D: Documentation and Patterns (Steps 11-12)

#### Step 11: Create Pattern Library
**Purpose:** Provide ready-to-use Caddyfile patterns
**Deployable:** Yes (documentation)

1. Create `/Users/alex/.docs/caddy-skill/patterns/`
2. Add patterns:
   - `reverse-proxy-health-check.caddy`
   - `oauth-github.caddy`
   - `jwt-validation.caddy`
   - `websocket-support.caddy`
   - `security-headers.caddy`
   - `static-files-caching.caddy`
   - `cors-configuration.caddy`
   - `rate-limiting.caddy`
3. Each pattern includes:
   - Use case description
   - Full working example
   - Required plugins/modules
   - Environment variables needed
   - Testing instructions

#### Step 12: Add Troubleshooting Guide
**Purpose:** Document common issues and solutions
**Deployable:** Yes (documentation)

1. Add "Troubleshooting" section
2. Common issues:
   - Port already in use
   - Certificate renewal failures
   - Upstream connection refused
   - Validation errors
   - Systemd service won't start
   - Secrets not found (1Password)
3. For each issue:
   - Symptoms
   - How to detect
   - How to fix
   - Prevention

## 6. Testing & Verification Strategy

| Acceptance Criteria | Test Type | Test Approach |
|---------------------|-----------|---------------|
| AC-1: Discovery | Integration | Find Caddyfiles on all 3 servers, verify results |
| AC-2: Validation | Integration | Validate valid and invalid configs, check error reporting |
| AC-3: Deployment | Integration | Deploy test config to registry, verify reload |
| AC-4: Custom Build | Integration | Build Caddy on bigbox, verify plugins |
| AC-5: Systemd Migration | Manual | Test migration in non-production first |
| AC-6: Log Analysis | Integration | Parse test logs, verify filtering |
| AC-7: Snippet Extraction | Integration | Extract from test configs, verify imports work |
| AC-8: Pattern Library | Manual | Test each pattern in isolation |

### Test Plan

**Phase 1: Discovery and Validation (Low Risk)**
1. Test discovery on all servers
2. Test validation with various configs (valid, invalid, edge cases)
3. Verify error reporting is clear

**Phase 2: Core Operations (Medium Risk)**
1. Test formatting on test configs
2. Test deployment on registry server (lower risk)
3. Verify rollback works
4. Test status checking

**Phase 3: Advanced Features (Medium Risk)**
1. Build custom Caddy on bigbox
2. Analyze logs with various filters
3. Extract snippets from real configs
4. Verify patterns work

**Phase 4: Systemd Migration (High Risk)**
1. Test migration on test VM first
2. Document every step
3. Prepare rollback plan
4. Execute migration during low-traffic window
5. Monitor closely for 24 hours

### Validation Checklist

- [ ] Discovery finds all Caddyfiles in <5 seconds
- [ ] Validation catches syntax errors accurately
- [ ] Formatting preserves functionality (validate after format)
- [ ] Deployment is zero-downtime (verified with monitoring)
- [ ] Build produces working binary with all plugins
- [ ] Log analysis correctly parses JSON logs
- [ ] Snippet extraction creates valid, importable snippets
- [ ] Systemd migration succeeds without dropped requests
- [ ] Integration with 1Password skill works seamlessly
- [ ] All patterns in library are tested and working

## 7. Risk & Complexity Review

| Risk | Mitigation | Residual Risk |
|------|------------|---------------|
| **RISK-1: Service Downtime** Reload fails, service goes down | Always validate before reload, implement rollback, test in staging | Low: Graceful reload should prevent downtime |
| **RISK-2: Configuration Corruption** Edit corrupts active config | Always backup before changes, validate after changes, provide rollback | Very Low: Backups and validation prevent this |
| **RISK-3: SSH Connection Failure** Lost connection during critical operation | Use tmux on remote side, idempotent operations, can retry | Low: SSH generally reliable |
| **RISK-4: Version Incompatibility** Different Caddy versions have different syntax | Detect version, warn about compatibility, test configs per version | Medium: bigbox v2.6.2, registry v2.10.2 |
| **RISK-5: Missing Dependencies** xcaddy or Go not installed | Check before operations, guide installation, graceful failure | Low: Clear error messages |
| **RISK-6: Systemd Migration Failure** Migration leaves service down | Comprehensive rollback plan, test first, keep tmux available | Medium: High-risk operation |
| **RISK-7: Secret Exposure** Plaintext secrets shown in output | Never display secret values, coordinate with 1Password skill | Very Low: Design prevents exposure |
| **RISK-8: Log Parsing Errors** JSON logs have unexpected format | Graceful error handling, fallback to text parsing | Low: JSON format is standard |
| **RISK-9: Snippet Conflicts** Extracted snippets conflict with existing code | Validate snippets before extraction, allow user review | Low: Validation catches issues |
| **RISK-10: Permission Issues** Can't write to directories, can't reload service | Check permissions before operations, use sudo where needed | Medium: systemd operations may need root |
| **RISK-11: Concurrent Modifications** Multiple users editing same config | Not prevented by skill, document as limitation | Medium: User must coordinate |
| **RISK-12: Binary Mismatch** systemd config points to wrong binary | Detect discrepancy, warn user, guide fix | Low: Discovery catches this |

### Complexity Assessment

**Low Complexity:**
- Caddyfile discovery (file search)
- Syntax validation (call caddy validate)
- Status checking (systemctl status)
- Format operation (caddy fmt)

**Medium Complexity:**
- Safe deployment (validation + reload + verification)
- Log analysis (JSON parsing + filtering)
- Snippet extraction (pattern recognition)
- Custom build (xcaddy + plugins)

**High Complexity:**
- Systemd migration (multi-step, high risk)
- Multi-server management (SSH + context switching)
- Integration with 1Password skill (coordination)
- Rollback automation (state management)

### Simplification Opportunities

1. **Focus on systemd**: Registry example shows clean systemd management. Use as template for bigbox.
2. **Leverage registry patterns**: Registry's snippet-based config (41 lines) vs bigbox's monolith (324 lines). Extract common patterns.
3. **Use 1Password skill**: Delegate all secret operations to 1Password skill. Caddy skill just coordinates.
4. **Validate early and often**: Validation is cheap, downtime is expensive. Validate at every step.
5. **Atomic operations**: Each workflow should be complete, reversible, and verifiable.

## 8. Open Questions / Decisions for Human Review

### Critical Questions

**Q1: Systemd Migration Timing**
When should the bigbox migration from tmux to systemd happen?

**Recommendation:** After Phase B (Core Operations) is tested and working. During low-traffic window. Have rollback plan ready.

**Q2: Binary Management**
Should skill automatically replace Caddy binaries after build, or require manual approval?

**Recommendation:** Never automatically replace active binary. Provide clear instructions for manual installation. Too risky to automate.

**Q3: Multi-User Coordination**
How to handle multiple users managing Caddy simultaneously?

**Recommendation:** Out of scope for skill. Document as limitation. Users must coordinate manually (use Git for version control).

**Q4: Snippet Organization**
Should extracted snippets be global (shared across servers) or server-specific?

**Recommendation:** Start server-specific to avoid conflicts. Can consolidate later if patterns are truly universal.

**Q5: Error Recovery Strategy**
When operations fail, should skill attempt automatic recovery or require human intervention?

**Recommendation:** Automatic rollback for deployment failures. Human intervention for build failures or migration issues. Clear error messages always.

### Non-Critical Questions

**Q6: Caddy Version Upgrade**
Should skill help upgrade Caddy versions?

**Recommendation:** Out of scope for v1. Document manual upgrade process. Version upgrades are high-risk, need careful planning.

**Q7: Configuration Testing**
Should skill provide a "test environment" or "dry-run" mode?

**Recommendation:** Nice to have. Validation is partial dry-run. Full testing requires separate environment (out of scope).

**Q8: Metrics Collection**
Should skill collect metrics (request rates, error rates) for analysis?

**Recommendation:** Leverage existing monitoring (monitor-webhook.sh). Don't duplicate. Skill can parse logs for ad-hoc analysis.

**Q9: Certificate Management**
Should skill help troubleshoot certificate issues?

**Recommendation:** Add to troubleshooting guide. Caddy handles certs automatically. Skill can check expiry dates, validate DNS for Let's Encrypt.

**Q10: Configuration Drift Detection**
Should skill detect when running config differs from file?

**Recommendation:** Yes. Check Admin API config vs file config. Warn if drift detected. Suggest reload.

## 9. Implementation Priority

### Must Have (MVP)
1. ✓ Caddyfile discovery (all servers)
2. ✓ Syntax validation
3. ✓ Safe deployment (reload)
4. ✓ Status checking
5. ✓ Integration with 1Password skill
6. ✓ Basic log analysis

### Should Have (v1.0)
7. ✓ Custom build support
8. ✓ Snippet extraction
9. ✓ Pattern library
10. ✓ Systemd migration (bigbox)
11. ✓ Troubleshooting guide

### Nice to Have (Future)
12. Configuration drift detection
13. Advanced log analysis (metrics, trends)
14. Automated testing of configs
15. Multi-server coordination
16. Version upgrade assistance

## 10. Success Metrics

After implementation, success will be measured by:

1. **Discovery Speed**: Find all Caddyfiles in <5 seconds
2. **Zero Downtime**: 100% of deployments have zero dropped requests
3. **Validation Rate**: 100% of deployments are validated first
4. **Secret Safety**: 0 plaintext secrets in configs (via 1Password)
5. **Systemd Migration**: bigbox successfully migrated and stable for 7 days
6. **Error Reduction**: 50% reduction in configuration errors
7. **Time Savings**: 80% reduction in time to deploy changes (validation + deployment automated)

## Approval Checklist

Before proceeding to Phase 3 (Implementation), confirm:

- [ ] Scope is clear and achievable
- [ ] Multi-server design handles SSH complexity
- [ ] Systemd migration plan is safe and reversible
- [ ] Integration with 1Password skill is well-defined
- [ ] Risk mitigations are sufficient
- [ ] Testing strategy covers critical paths
- [ ] Pattern library provides value
- [ ] Open questions are resolved
- [ ] Implementation priority makes sense

**Do you approve this plan as-is, or would you like to adjust any part?**

---

**Next Phase:** Once approved, Phase 3 (Disciplined Implementation) will create:
1. 1Password Secret Management Skill (first, since Caddy depends on it)
2. Caddy Server Management Skill (second, uses 1Password skill)

Both skills will follow these design plans precisely.
