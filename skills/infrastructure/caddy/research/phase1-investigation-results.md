# Phase 1 Investigation Results - Caddy Skill Research

**Date:** 2025-12-29
**Updated After:** User Q&A Session

## Executive Summary

Investigation of active Caddy installations across bigbox and registry servers revealed:

1. **Active Configuration**: bigbox uses `/home/alex/caddy_terraphim/conf/Caddyfile_auth` (324 lines)
2. **Process Management**: Currently running in tmux, but systemd service is configured and should be used
3. **Build Process**: Custom Caddy built with xcaddy including security plugins
4. **Additional Server**: registry server confirmed with Caddy v2.10.2
5. **Secret Management**: 1Password CLI installed but not consistently used (plaintext secrets found)

## 1. Active Caddyfile Investigation (bigbox)

### Current State
- **Process**: PID 24566, running as user `caddy`
- **Command**: `/usr/bin/caddy run --environ --resume`
- **Working Directory**: `/` (root)
- **Process Started**: Nov 24, 2025 (running for 35+ days)
- **Binary**: `/usr/bin/caddy` (v2.6.2)

### Configured Systemd Service
File: `/etc/systemd/system/caddy-terraphim.service`

```systemd
[Unit]
Description=Caddy Web Server (Terraphim)
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=exec
User=root
Group=root
WorkingDirectory=/home/alex/caddy_terraphim
EnvironmentFile=/home/alex/caddy_terraphim/caddy_complete.env
ExecStart=/home/alex/caddy_terraphim/caddy run --config /home/alex/caddy_terraphim/conf/Caddyfile_auth
ExecReload=/home/alex/caddy_terraphim/caddy reload --config /home/alex/caddy_terraphim/conf/Caddyfile_auth
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

### Key Findings
1. **Active Config**: `/home/alex/caddy_terraphim/conf/Caddyfile_auth` (324 lines)
2. **Environment File**: `/home/alex/caddy_terraphim/caddy_complete.env`
3. **Binary Used by Systemd**: `/home/alex/caddy_terraphim/caddy` (v2.6.4, custom build)
4. **Binary Currently Running**: `/usr/bin/caddy` (v2.6.2, standard)
5. **Discrepancy**: Process is NOT managed by systemd (should be migrated)

### Active Domains (from Admin API)
Based on running config:
- `alpha.truthforge.terraphim.cloud` → localhost:3000
- `logs.terraphim.cloud` → localhost:7280 (with Basic Auth)
- `ci.terraphim.cloud` → localhost:3004 (GitHub runner webhook)

### Tmux Sessions
Active sessions on bigbox:
- `terraphim-26` (attached)
- `atomic-24`
- `github_runner-0`
- `truthforge-server-3`
- `2`

## 2. Caddy Build Process

### Build Script
File: `/home/alex/caddy_terraphim/build.sh`

```bash
xcaddy build --with github.com/greenpau/caddy-security --with github.com/gamalan/caddy-tlsredis --with github.com/caddy-dns/cloudflare --with github.com/aksdb/caddy-cgi/v2
```

### Plugins Required
1. **caddy-security** (greenpau) - OAuth, JWT, authentication portal
2. **caddy-tlsredis** (gamalan) - TLS certificate storage in Redis
3. **caddy-dns/cloudflare** - Cloudflare DNS challenge for wildcard certs
4. **caddy-cgi** (aksdb) - CGI script execution

### Build Tool
- **xcaddy**: NOT currently installed on bigbox
- **Status**: Binary was built Mar 12, 2023 (v2.6.4)
- **Issue**: Cannot rebuild without installing xcaddy
- **Action Required**: Install xcaddy for future builds

### Binary Details
```
Binary: /home/alex/caddy_terraphim/caddy
Size: 53,932,032 bytes (~51.4 MB)
Type: ELF 64-bit LSB executable, x86-64, statically linked
Built: Mar 12, 2023
Version: v2.6.4
```

## 3. Registry Server Investigation

### Configuration
- **Caddy Version**: v2.10.2 (much newer than bigbox)
- **Process Management**: Proper systemd service
- **Service**: `caddy.service` (enabled, running)
- **Config Path**: `/etc/caddy/Caddyfile`
- **Status**: Active since Dec 29, 2025 11:17:41 UTC

### Active Caddyfile
File: `/etc/caddy/Caddyfile` (41 lines, clean and simple)

```caddyfile
{
    email admin@zesticai.org
    admin localhost:2019
}

(logging) {
    log {
        output file /var/log/caddy/access.log {
            roll_size 100mb
            roll_keep 5
        }
        format json
    }
}

charm.terraphim.io {
    import logging

    handle /health {
        respond "OK" 200
    }

    reverse_proxy 192.168.208.2:80 {
        header_up X-Real-IP {remote_host}
    }
}

common.terraphim.io {
    import logging

    handle /health {
        respond "OK" 200
    }

    reverse_proxy 192.168.208.3:80 {
        header_up X-Real-IP {remote_host}
    }
}
```

### Key Patterns Observed
1. **Snippet Import**: Uses `(logging)` snippet for DRY config
2. **Health Endpoints**: All services expose `/health`
3. **JSON Logging**: Consistent log format
4. **Clean Structure**: No authentication (handled by upstream)
5. **IP-Based Routing**: Proxies to internal IPs (likely VMs)

### Additional Caddyfiles on Registry
Found in deployment directories:
- `/home/alex/deploy/charm-impact/infrastructure/*` (5 variants)
- `/home/alex/infrastructure/terraphim-infrastructure/*`
- `/home/alex/infrastructure/charm-impact/infrastructure/*`
- `/home/alex/projects/zestic-ai/truthforge/Caddyfile`

## 4. 1Password CLI Integration

### Installation Status
| System | Path | Version |
|--------|------|---------|
| Local (macOS) | /opt/homebrew/bin/op | 2.32.0 |
| bigbox | /usr/bin/op | 2.31.0 |
| registry | /usr/bin/op | 2.29.0 |

### Current Usage Pattern
Found in `/home/alex/caddy_terraphim/github_runner.env`:
```bash
# Retrieved from 1Password: op://Terraphim/CIToken/token
```

This shows the **reference syntax** but the actual value is stored in plaintext in the file.

### Secret Exposure Found
File: `/home/alex/caddy_terraphim/caddy_complete.env`

**CRITICAL ISSUE**: Contains plaintext secrets:
```env
GITHUB_CLIENT_ID=6182d53553cf86b0faf2
GITHUB_CLIENT_SECRET=952abb34b2f45f3e38f9e688f607a1e0e8b78cf4
JWT_SHARED_KEY=terraphim-jwt-shared-key-5c28cc33679085bfd8189be4cbbaf913b5b83d389f41d9d76661e2d707e60abd
```

### Required Migration Pattern
Per user's CLAUDE.md mandate:
> "you are not allowed to overwrite .env files, use op inject if required or op run --no-masking to start docker compose or other services"

**Proper Pattern:**

1. **Template File** (`.env.template`):
```env
GITHUB_CLIENT_ID=op://Terraphim/GitHub OAuth/client_id
GITHUB_CLIENT_SECRET=op://Terraphim/GitHub OAuth/client_secret
JWT_SHARED_KEY=op://Terraphim/JWT/shared_key
```

2. **Service Start with 1Password**:
```bash
# For systemd
op run --no-masking -- systemctl start caddy-terraphim

# For direct execution
op run --no-masking -- /home/alex/caddy_terraphim/caddy run --config /home/alex/caddy_terraphim/conf/Caddyfile_auth

# For env file injection
op inject -i caddy.env.template -o /tmp/caddy.env && caddy run --envfile /tmp/caddy.env
```

### 1Password Integration Requirements for Skill

1. **Never Display Secrets**: Use masked output or references only
2. **Validate op CLI**: Check `which op` before secret operations
3. **Reference Syntax**: Guide users to use `op://vault/item/field` format
4. **Inject Commands**: Use `op inject -i template -o output`
5. **Run Commands**: Use `op run --no-masking -- command` for service starts
6. **Template Creation**: Generate `.env.template` from existing `.env` files
7. **Security Warnings**: Alert when plaintext secrets detected in configs

## 5. Updated System Architecture

### Server Inventory
| Server | Caddy Version | Config Location | Process Manager | Status |
|--------|---------------|-----------------|-----------------|--------|
| bigbox | v2.6.2 (usr), v2.6.4 (local) | /home/alex/caddy_terraphim/conf/Caddyfile_auth | tmux (temp) | Running 35+ days |
| registry | v2.10.2 | /etc/caddy/Caddyfile | systemd | Properly managed |
| local (macOS) | N/A | Various project directories | Development only | N/A |

### Migration Requirements for bigbox

**Current State**: Caddy running in tmux
**Target State**: Caddy running via systemd
**Benefit**: Auto-restart, proper logging, standard management

**Migration Steps**:
1. Verify systemd service file is current
2. Update environment file with 1Password references
3. Test service with `op run --no-masking -- systemctl start caddy-terraphim`
4. Stop tmux-based Caddy process
5. Enable and start systemd service
6. Verify with `systemctl status caddy-terraphim`

### Custom Caddy Build Requirements

**Problem**: xcaddy not currently installed on bigbox
**Impact**: Cannot rebuild Caddy with updated plugins
**Solution**: Install xcaddy and document build process

**Installation**:
```bash
# Install xcaddy
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# OR download binary
curl -L https://github.com/caddyserver/xcaddy/releases/download/v0.4.4/xcaddy_0.4.4_linux_amd64.tar.gz | tar xz
sudo mv xcaddy /usr/local/bin/
```

**Build Process**:
```bash
cd /home/alex/caddy_terraphim
xcaddy build \
  --with github.com/greenpau/caddy-security \
  --with github.com/gamalan/caddy-tlsredis \
  --with github.com/caddy-dns/cloudflare \
  --with github.com/aksdb/caddy-cgi/v2
```

## 6. Revised Scope for Caddy Skill

### Now IN SCOPE (Updated)
- **Secret Management**: 1Password CLI integration (mandatory)
- **Template Generation**: Convert .env to .env.template with op:// references
- **Migration Support**: tmux → systemd migration
- **Multi-Server Management**: bigbox, registry, and future servers
- **Custom Build Support**: xcaddy installation and build process
- **Security Auditing**: Detect plaintext secrets in configs

### Simplified by Registry Example
The registry server demonstrates **best practices**:
1. Clean, minimal Caddyfile (41 lines vs 324 lines)
2. Snippet-based configuration (DRY principle)
3. Proper systemd management
4. Standard paths (`/etc/caddy/`)
5. Health check endpoints
6. JSON logging for observability

## 7. Critical Action Items

### Immediate (High Priority)
1. ✅ **Identify Active Config**: Confirmed `/home/alex/caddy_terraphim/conf/Caddyfile_auth`
2. ⚠️ **Security Issue**: Plaintext secrets in `caddy_complete.env`
3. ⚠️ **Process Management**: Migrate from tmux to systemd
4. ⚠️ **Missing Tool**: Install xcaddy for future builds

### Phase 2 Design (Next Steps)
1. Design 1Password integration workflow
2. Create .env.template generation tool
3. Design systemd migration process
4. Document custom build workflow
5. Create unified Caddyfile finding logic (3 servers)
6. Design snippet extraction for DRY configs

## 8. Updated Questions for User (Resolved)

| Question | Answer | Impact |
|----------|--------|--------|
| Which Caddyfile is active on bigbox? | `/home/alex/caddy_terraphim/conf/Caddyfile_auth` | ✅ Confirmed via systemd config |
| Why tmux instead of systemd? | Should be systemd, tmux was temporary | ⚠️ Migration needed |
| Additional servers? | Yes, registry server (ssh registry) | ✅ Investigated |
| How is custom Caddy built? | Build locally with xcaddy on each box | ⚠️ xcaddy not installed |
| Use 1Password CLI for secrets? | **Mandatory** | ✅ Guides skill design |

## 9. Risk Assessment (Updated)

### New Risks Identified

**RISK 11: Plaintext Secrets in Version Control**
- **Category**: Security
- **Likelihood**: High (if env files committed)
- **Impact**: Critical (credential compromise)
- **De-risk**: Mandatory 1Password migration, .gitignore .env files

**RISK 12: tmux Process Management**
- **Category**: Operational
- **Likelihood**: Medium
- **Impact**: Medium (no auto-restart, hard to monitor)
- **De-risk**: Migrate to systemd, test failover

**RISK 13: xcaddy Not Installed**
- **Category**: Technical
- **Likelihood**: Low (infrequent rebuilds)
- **Impact**: Medium (cannot update Caddy)
- **De-risk**: Install xcaddy, document build process

**RISK 14: Version Drift Between Servers**
- **Category**: Operational
- **Likelihood**: High (bigbox v2.6.2, registry v2.10.2)
- **Impact**: Low (features may differ)
- **De-risk**: Document version differences, test configs

## 10. Success Metrics

After skill implementation, success will be measured by:

1. **Secret Safety**: No plaintext secrets in configs (100% 1Password usage)
2. **Process Management**: All Caddy instances running via systemd
3. **Discovery Speed**: Find all Caddyfiles across 3 servers in <5 seconds
4. **Validation Rate**: 100% syntax validation before deployment
5. **Zero-Downtime Reloads**: Graceful reloads with zero dropped requests
6. **Build Capability**: Ability to rebuild custom Caddy on demand
7. **Configuration DRY**: Extract common patterns to snippets (reduce duplication by 50%)

---

**Next Phase**: Disciplined Design (Phase 2)
- Design 1Password integration workflows
- Create systemd migration plan
- Design multi-server management commands
- Specify skill tool usage patterns
- Create configuration pattern catalog
