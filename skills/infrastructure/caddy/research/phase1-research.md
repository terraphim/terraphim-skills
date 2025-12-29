# Research Document: Claude Agent Skill for Caddy Server Management

**Date:** 2025-12-29
**Phase:** 1 - Disciplined Research
**Author:** Claude Code (Disciplined Research Skill)

## 1. Problem Restatement and Scope

### Problem Statement

The user needs a comprehensive Claude agent skill to manage Caddy web server configurations across multiple environments (local development and production servers). Currently, there are 28+ Caddyfiles spread across local laptop and bigbox server, with varying complexity (12-324 lines) and different use cases (authentication, reverse proxy, WebSocket, security headers, Docker deployments).

### Scope

**IN SCOPE:**
- Finding and cataloging all Caddyfiles (local and remote via SSH)
- Validating Caddyfile syntax
- Formatting Caddyfiles
- Managing Caddy server lifecycle (start, stop, reload)
- Viewing and analyzing logs
- Common configuration patterns (reverse proxy, authentication, TLS, WebSocket)
- Security best practices
- Docker deployment workflows
- Troubleshooting common issues
- Integration with monitoring tools

**OUT OF SCOPE:**
- Building custom Caddy binaries from source
- Deep Caddy plugin development (beyond using existing modules)
- Infrastructure-as-code automation (Terraform, Ansible)
- Network-level configuration (firewall rules, DNS management beyond Cloudflare)
- Automated backup/restore of Caddyfile versions (but can guide manual processes)

## 2. User & Business Outcomes

### User-Visible Outcomes

1. **Rapid Discovery**: Quickly find all Caddyfiles across local and remote systems
2. **Configuration Validation**: Validate syntax before deployment to prevent downtime
3. **Safe Deployments**: Graceful reloads without service interruption
4. **Troubleshooting Support**: Analyze logs and debug configuration issues
5. **Security Compliance**: Apply security best practices consistently
6. **Pattern Reuse**: Copy proven patterns for common use cases
7. **Multi-Environment Management**: Handle development, staging, and production configs

### Business Outcomes

1. **Reduced Downtime**: Prevent configuration errors from reaching production
2. **Faster Deployment**: Streamline Caddyfile changes with validation
3. **Improved Security Posture**: Consistent application of security headers and authentication
4. **Knowledge Preservation**: Documented patterns and workflows
5. **Reduced Cognitive Load**: Single skill for all Caddy operations

## 3. System Elements and Dependencies

### 3.1 Caddyfile Inventory

**Local Environment** (14 Caddyfiles):
- charm-impact infrastructure: 6 variants (_docker, _localauth, _minimal, .production, .atomic-only.production)
- charm-impact-llm infrastructure: 4 variants
- klarian/pumping_toolbox_dashboard: 3 variants
- truthforge: 1 config

**Remote Environment - bigbox** (14+ production Caddyfiles):
- `/home/alex/caddy_terraphim/conf/`: Primary production configs (324-line auth config, multiple variants)
- `/home/alex/infrastructure/atomic-server-turso/`: Atomic server configs (112-line enhanced, production, simple)
- `/home/alex/infrastructure/terraphim-private-cloud*/`: Cloud infrastructure configs
- Multiple backup files (`.backup.*` pattern - excluded from analysis)

### 3.2 Caddy Deployment Patterns

| Pattern | Location | Use Case | Lines | Key Features |
|---------|----------|----------|-------|--------------|
| Minimal | Local projects | Development | 12-32 | Basic reverse proxy, on-demand TLS |
| Docker | Docker Compose | Containerized apps | 25-31 | host.docker.internal, env vars |
| Auth | bigbox production | Production with authentication | 96-324 | OAuth, JWT, Basic Auth, role-based access |
| Enhanced | bigbox production | Full-featured production | 112-167 | WebSocket, security headers, logging, health checks |
| Firecracker | atomic-server-turso | VM isolation | 51 | Specialized for Firecracker VMs |

### 3.3 Dependencies and Integrations

**Core Dependencies:**
- Caddy v2.6.2 (installed on bigbox)
- Caddy modules: authentication, security, reverse_proxy, file_server, tls
- caddy-security plugin (for OAuth, JWT, authorization policies)

**External Integrations:**
- **Cloudflare DNS**: For wildcard TLS certificates (DNS challenge)
- **GitHub OAuth**: Authentication provider
- **Let's Encrypt**: Automatic HTTPS certificates
- **Docker**: Container orchestration
- **tmux**: Process management (5 active sessions on bigbox)
- **systemd**: Service management (not currently used - Caddy runs via tmux)
- **JSON logs**: Integration with monitoring tools

**Backend Services:**
- Atomic Server (ports 8081, 8090)
- TruthForge (port 3000, 8090)
- CharmApp (port 5173)
- GitHub Runner webhook (port 3004)
- Firecracker VMs (managed via API)

### 3.4 File System Structure

```
Local:
/Users/alex/projects/
  ├── zestic-ai/charm/charm-impact/infrastructure/
  ├── zestic-ai/charm-impact-llm/infrastructure/
  ├── zestic-ai/truthforge/
  └── klarian/pumping_toolbox_dashboard/infrastructure/

Remote (bigbox):
/home/alex/
  ├── caddy_terraphim/
  │   ├── conf/ (Caddyfiles)
  │   ├── log/ (access/error logs)
  │   └── caddy (binary)
  ├── infrastructure/
  │   ├── atomic-server-turso/
  │   ├── terraphim-private-cloud*/
  │   └── ...
  └── .local/caddy/ (users.json for local auth)
```

### 3.5 Configuration Patterns Observed

**Authentication Patterns:**
1. **OAuth (GitHub)**: oauth identity provider github {env.GITHUB_CLIENT_ID}
2. **Local Identity Store**: JSON file with bcrypt hashed passwords
3. **JWT Tokens**: Bearer token validation with shared secret
4. **Basic Auth**: bcrypt hashed credentials in Caddyfile
5. **Multi-Authentication Routes**: Different auth methods for same endpoint (Bearer vs Cookie vs Basic)

**Security Headers Pattern:**
- HSTS (Strict-Transport-Security)
- CSP (Content-Security-Policy) with WebSocket support
- X-Content-Type-Options, X-Frame-Options, X-XSS-Protection
- Referrer-Policy, Permissions-Policy
- Server header removal

**Logging Patterns:**
1. **JSON Format**: For machine parsing (used in production)
2. **Common Log Format**: For fail2ban compatibility
3. **Transform Format**: Custom formatting for goaccess
4. **File Rotation**: roll_size, roll_keep, roll_keep_for

**TLS Patterns:**
1. **Automatic HTTPS**: Let's Encrypt (default)
2. **Cloudflare DNS Challenge**: For wildcard certificates
3. **On-Demand TLS**: For development
4. **Multiple Domains**: Wildcard configs (*.terraphim.cloud)

**Reverse Proxy Patterns:**
1. **Health Checks**: health_interval, health_timeout
2. **Header Forwarding**: X-Real-IP, X-Forwarded-For, X-Forwarded-Proto
3. **WebSocket Support**: Connection Upgrade headers
4. **Timeouts**: read_timeout, write_timeout, dial_timeout

### 3.6 Operational Workflows

**Current Deployment Process:**
1. Edit Caddyfile in conf directory
2. Validate syntax (sometimes skipped - RISK)
3. Find Caddy process (running in tmux)
4. Reload configuration
5. Check logs for errors
6. Monitor via custom scripts (monitor-webhook.sh, webhook-status.sh)

**Monitoring Stack:**
- Custom bash scripts for health checks
- JSON logs parsed with jq
- journalctl for service logs (when using systemd)
- curl commands for API health checks
- Webhook monitoring for GitHub runners

## 4. Constraints and Their Implications

### 4.1 Technical Constraints

**Constraint 1: Multiple Environments**
- **Implication**: Skill must handle both local (macOS) and remote (Linux/SSH) operations
- **Why it matters**: Different commands (mdfind vs find), different paths, SSH overhead
- **Shapes solution**: Need environment detection, SSH-aware commands

**Constraint 2: No systemd Management**
- **Implication**: Caddy runs in tmux, not as systemd service
- **Why it matters**: Cannot use systemctl commands, must interact with tmux sessions
- **Shapes solution**: Skill must understand tmux management, process signals

**Constraint 3: Caddy v2.6.2 (slightly outdated)**
- **Implication**: Some newer features may not be available
- **Why it matters**: Documentation should target v2.6.x compatibility
- **Shapes solution**: Test patterns against v2.6.2, note version-specific features

**Constraint 4: Custom Caddy Build with Security Plugin**
- **Implication**: Not standard Caddy binary, includes caddy-security module
- **Why it matters**: Authentication/authorization features depend on this plugin
- **Shapes solution**: Skill must document plugin requirements, provide installation guidance

**Constraint 5: Production Secrets in Environment Variables**
- **Implication**: Caddyfiles reference {env.VAR_NAME}
- **Why it matters**: Cannot validate configs without environment context
- **Shapes solution**: Skill must handle partial validation, environment variable management

### 4.2 Operational Constraints

**Constraint 6: Zero-Downtime Requirement**
- **Implication**: Must use graceful reloads, not restarts
- **Why it matters**: Production services cannot tolerate downtime
- **Shapes solution**: Prioritize `caddy reload` over `caddy restart`

**Constraint 7: Multiple Active Configurations**
- **Implication**: 28+ Caddyfiles across environments, unclear which is "active"
- **Why it matters**: Easy to edit wrong file
- **Shapes solution**: Skill must identify active config before operations

**Constraint 8: Log Volume**
- **Implication**: JSON logs can be large (100MB+ files)
- **Why it matters**: Parsing entire logs is slow
- **Shapes solution**: Use tail, head, jq filters for targeted analysis

### 4.3 Security Constraints

**Constraint 9: Sensitive Data in Configs**
- **Implication**: API keys, JWT secrets, bcrypt hashes present
- **Why it matters**: Caddyfiles should not be committed without sanitization
- **Shapes solution**: Skill must warn about secrets, recommend environment variables

**Constraint 10: SSH Access Required**
- **Implication**: Remote operations require SSH key authentication
- **Why it matters**: Cannot automate without proper SSH setup
- **Shapes solution**: Document SSH requirements, test connectivity first

**Constraint 11: Cloudflare API Tokens**
- **Implication**: TLS DNS challenge requires valid Cloudflare tokens
- **Why it matters**: Token rotation can break certificate renewal
- **Shapes solution**: Guide token validation, troubleshooting

### 4.4 User Experience Constraints

**Constraint 12: CLI Tool Context**
- **Implication**: Skill runs within Claude Code CLI
- **Why it matters**: Available tools are Bash, Read, Write, Edit, Grep, Glob
- **Shapes solution**: Cannot use interactive UIs, must use CLI-friendly patterns

**Constraint 13: User Preferences (from CLAUDE.md)**
- No timeout command on macOS
- Use IDE diagnostics for errors
- Track tasks in GitHub issues
- Commit every change
- Use tmux for background tasks
- **Shapes solution**: Respect these patterns in skill workflows

## 5. Risks, Unknowns, and Assumptions

### 5.1 Unknowns

**UNKNOWN 1**: Which Caddyfile is currently active on bigbox?
- **De-risk**: Check running Caddy process, inspect /proc or admin API
- **Impact**: Could edit wrong file

**UNKNOWN 2**: What is the full environment variable set for production?
- **De-risk**: Read .env files, check tmux session environment
- **Impact**: Cannot fully validate configs

**UNKNOWN 3**: Are there other Caddy instances running beyond bigbox?
- **De-risk**: Ask user about additional servers
- **Impact**: Incomplete coverage

**UNKNOWN 4**: What is the disaster recovery process?
- **De-risk**: Check for backup configs, version control
- **Impact**: Could lose configurations

**UNKNOWN 5**: What monitoring/alerting exists beyond custom scripts?
- **De-risk**: Check for Prometheus, Grafana, other tools
- **Impact**: Skill could duplicate or conflict with existing monitoring

### 5.2 Assumptions

**ASSUMPTION 1**: User has SSH access to bigbox without password prompt
- **Verify**: Test SSH connection in skill initialization

**ASSUMPTION 2**: Caddy binary path is /usr/bin/caddy on bigbox
- **Verify**: Use `which caddy` to confirm

**ASSUMPTION 3**: User wants to manage Caddyfiles via CLI, not web UI
- **Verify**: Ask user about preference

**ASSUMPTION 4**: Caddyfiles follow naming convention (Caddyfile*)
- **Verify**: Pattern seems consistent, but confirm

**ASSUMPTION 5**: User has write permissions to Caddyfile directories
- **Verify**: Check file ownership before edits

**ASSUMPTION 6**: Backup files (*.backup.*) should be excluded from normal operations
- **Verify**: Confirmed by observation, but ask user

**ASSUMPTION 7**: JSON log format is preferred for production
- **Verify**: Observed in configs, aligns with monitoring scripts

### 5.3 Risks

**RISK 1: Configuration Syntax Errors Leading to Service Failure**
- **Category**: Technical
- **Likelihood**: Medium (if validation skipped)
- **Impact**: High (service downtime)
- **De-risk**: Make validation mandatory before deployment, provide rollback guidance

**RISK 2: Editing Active Production Config Without Backup**
- **Category**: Operational
- **Likelihood**: Medium
- **Impact**: High (difficult recovery)
- **De-risk**: Automatic backup before changes, version control integration

**RISK 3: SSH Connection Loss During Critical Operation**
- **Category**: Technical
- **Likelihood**: Low
- **Impact**: High (incomplete state)
- **De-risk**: Use tmux on remote side, idempotent operations

**RISK 4: Secret Exposure in Claude Code Context**
- **Category**: Security
- **Likelihood**: Low (depends on user practices)
- **Impact**: High (credential compromise)
- **De-risk**: Never display full secrets, recommend 1Password integration

**RISK 5: Caddy Module Dependencies Not Installed**
- **Category**: Technical
- **Likelihood**: Medium (custom build required)
- **Impact**: Medium (features don't work)
- **De-risk**: Check available modules, document installation process

**RISK 6: Certificate Renewal Failure (Let's Encrypt/Cloudflare)**
- **Category**: Operational
- **Likelihood**: Low
- **Impact**: High (HTTPS breaks)
- **De-risk**: Monitor certificate expiry, test renewal process

**RISK 7: Conflicting Port Bindings**
- **Category**: Technical
- **Likelihood**: Low
- **Impact**: Medium (service won't start)
- **De-risk**: Check port availability before starting Caddy

**RISK 8: Log Files Filling Disk**
- **Category**: Operational
- **Likelihood**: Medium (without rotation)
- **Impact**: Medium (service failure)
- **De-risk**: Verify log rotation is configured, monitor disk usage

**RISK 9: OAuth Token Expiration Breaking Authentication**
- **Category**: Security/Operational
- **Likelihood**: Medium
- **Impact**: High (users locked out)
- **De-risk**: Document token refresh process, monitoring

**RISK 10: Skill Recommending Patterns Incompatible with User's Setup**
- **Category**: Product/UX
- **Likelihood**: Medium
- **Impact**: Low (user confusion)
- **De-risk**: Provide multiple pattern options, context-aware recommendations

## 6. Context Complexity vs. Simplicity Opportunities

### 6.1 Sources of Complexity

1. **Multiple Configuration Variants**: 5-6 variants per project (_docker, _localauth, _minimal, .production, etc.)
   - **Implication**: Unclear which to use when, duplication of patterns

2. **Authentication Sprawl**: 4+ different auth methods (OAuth, JWT, Basic, Local)
   - **Implication**: Each has different setup, debugging, security considerations

3. **Environment-Specific Settings**: Different configs for local, Docker, production
   - **Implication**: Hard to see differences, easy to misconfigure

4. **Custom Monitoring Scripts**: Bash scripts for monitoring instead of standard tools
   - **Implication**: Non-standard troubleshooting, hard to maintain

5. **Mixed Process Management**: tmux vs systemd vs Docker
   - **Implication**: Different commands for same operations

6. **Backup File Clutter**: Many .backup.* files in atomic-server-turso
   - **Implication**: Hard to identify current config, risk of using old file

### 6.2 Simplification Opportunities

**Opportunity 1: Standardize Configuration Naming**
- **Strategy**: Use consistent naming convention across all projects
- **Example**: `Caddyfile.{environment}.{variant}` → `Caddyfile.dev.auth`, `Caddyfile.prod.minimal`
- **Benefit**: Immediately clear which config for which purpose

**Opportunity 2: Extract Common Patterns to Snippets**
- **Strategy**: Use Caddy's `import` directive for shared config blocks
- **Example**: Create `snippets/security-headers.caddy`, `snippets/logging.caddy`
- **Benefit**: Single source of truth for patterns, easier updates

**Opportunity 3: Environment Variable Template**
- **Strategy**: Create `.env.template` files alongside Caddyfiles
- **Example**: Document all required env vars with example values
- **Benefit**: Clear requirements, easier validation

**Opportunity 4: Symlink to Active Configuration**
- **Strategy**: Use symlink pattern: `Caddyfile.active -> Caddyfile.prod.auth`
- **Benefit**: Always clear which config is running

**Opportunity 5: Centralized Logging Configuration**
- **Strategy**: Use single log configuration block, import in all configs
- **Benefit**: Consistent logging format, easier monitoring

**Opportunity 6: Backup Automation**
- **Strategy**: Use Git for version control instead of manual .backup files
- **Example**: `git commit -am "Update Caddyfile" && caddy reload`
- **Benefit**: Proper history, easy rollback, no clutter

**Opportunity 7: Health Check Standardization**
- **Strategy**: All services expose `/health` endpoint with consistent format
- **Benefit**: Unified monitoring, simpler health checks

**Opportunity 8: Development vs Production Separation**
- **Strategy**: Clear separation by directory: `dev/` and `prod/` subdirectories
- **Benefit**: Impossible to accidentally edit production config

## 7. Questions for Human Reviewer

### Critical Questions (Must Answer)

1. **Active Configuration**: Which Caddyfile is currently running on bigbox? Is it `/home/alex/caddy_terraphim/conf/Caddyfile_auth` or another variant?
   - **Why it matters**: Need to know which file to validate/reload

2. **Systemd vs tmux**: Why is Caddy running in tmux instead of systemd? Is this intentional for development flexibility?
   - **Why it matters**: Affects how skill manages start/stop/reload operations

3. **Additional Servers**: Are there Caddy instances on servers other than bigbox? If so, which servers?
   - **Why it matters**: Determines full scope of skill

4. **Custom Build Process**: How is the custom Caddy binary (with security plugin) built? Is there a build script or Docker image?
   - **Why it matters**: Skill should guide plugin installation for new environments

5. **Secret Management**: Do you use 1Password CLI (`op`) for managing Caddy secrets? Noticed user's CLAUDE.md mentions it.
   - **Why it matters**: Skill should integrate with existing secret management

### High-Priority Questions (Should Answer)

6. **Backup Strategy**: Should skill auto-backup Caddyfiles before editing, or rely on Git?
   - **Why it matters**: Determines safety mechanisms

7. **Validation Frequency**: Should validation be mandatory before every deployment, or optional?
   - **Why it matters**: Balance between safety and speed

8. **Configuration Variants**: Are all the _docker, _minimal, _localauth variants actively used, or are some obsolete?
   - **Why it matters**: Could simplify by removing unused variants

9. **Monitoring Integration**: Should skill integrate with existing monitor-webhook.sh scripts, or operate independently?
   - **Why it matters**: Avoid duplication, ensure consistency

10. **SSH Key Management**: Is SSH key authentication already set up for bigbox, or does it require password/2FA?
    - **Why it matters**: Affects automation capabilities

## 8. Next Steps (Phase 2: Design)

After this research is approved, Phase 2 (Disciplined Design) will produce:

1. **Skill Architecture Document**:
   - Tool usage patterns (which Claude Code tools for which tasks)
   - Command templates for common operations
   - Error handling strategies

2. **Configuration Patterns Catalog**:
   - Curated examples for each use case
   - Decision tree for choosing patterns
   - Security checklist

3. **Workflow Specifications**:
   - Find Caddyfiles workflow (local + remote)
   - Validate & deploy workflow
   - Troubleshoot & analyze logs workflow
   - Create new config from template workflow

4. **Testing Strategy**:
   - How to test without disrupting production
   - Validation checklists
   - Rollback procedures

5. **Documentation Structure**:
   - Quick reference commands
   - Common troubleshooting scenarios
   - Integration guides (Docker, tmux, OAuth)

## Appendix: Caddyfile Catalog

### Local Caddyfiles
| Path | Lines | Purpose |
|------|-------|---------|
| charm-impact/infrastructure/Caddyfile.production | 167 | Production deployment |
| charm-impact/infrastructure/Caddyfile.atomic-only.production | 119 | Atomic server only |
| charm-impact/infrastructure/Caddyfile_localauth | 123 | Local auth development |
| charm-impact/infrastructure/Caddyfile_docker | 31 | Docker Compose |
| charm-impact/infrastructure/Caddyfile_minimal | 32 | Minimal dev setup |
| charm-impact/infrastructure/Caddyfile | 25 | Base config |
| charm-impact-llm/infrastructure/Caddyfile | 25 | LLM project base |
| charm-impact-llm/infrastructure/Caddyfile_docker | 31 | LLM Docker |
| charm-impact-llm/infrastructure/Caddyfile_localauth | 123 | LLM local auth |
| charm-impact-llm/infrastructure/Caddyfile_minimal | 32 | LLM minimal |
| truthforge/Caddyfile | 89 | TruthForge config |
| pumping_toolbox_dashboard/Caddyfile | 84 | Dashboard production |
| pumping_toolbox_dashboard/Caddyfile_docker | 31 | Dashboard Docker |
| pumping_toolbox_dashboard/Caddyfile_local | 25 | Dashboard local |

### Remote Caddyfiles (bigbox - Production)
| Path | Lines | Purpose |
|------|-------|---------|
| caddy_terraphim/conf/Caddyfile_auth | 324 | Primary production with full auth |
| caddy_terraphim/conf/Caddyfile_auth2 | 63 | Alternate auth config |
| caddy_terraphim/conf/Caddyfile | 15 | Base/minimal |
| caddy_terraphim/conf/Caddyfile_reverse | 11 | Simple reverse proxy |
| caddy_terraphim/conf/Caddyfile_truthforge_minimal | 30 | TruthForge minimal |
| caddy_terraphim/conf/Caddyfile_atomic_simple | 27 | Atomic server simple |
| infrastructure/atomic-server-turso/Caddyfile.enhanced | 112 | Enhanced production |
| infrastructure/atomic-server-turso/Caddyfile.production | 86 | Production config |
| infrastructure/atomic-server-turso/caddy/Caddyfile.production | 75 | Caddy subdir production |
| infrastructure/atomic-server-turso/caddy/Caddyfile-atomic-firecracker | 51 | Firecracker integration |
| infrastructure/atomic-server-turso/Caddyfile.simple | 12 | Simple config |
| infrastructure/terraphim-private-cloud/caddy/conf/Caddyfile_auth | 96 | Private cloud auth |
| infrastructure/terraphim-private-cloud-original/caddy/conf/Caddyfile_auth | 86 | Original cloud auth |
| infrastructure/terraphim-private-cloud-new/caddy/Caddyfile | 31 | New cloud config |

---

**End of Phase 1 Research Document**
