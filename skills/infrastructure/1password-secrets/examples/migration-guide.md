# Migration Guide: From Plaintext Secrets to 1Password

**Purpose:** Step-by-step guide to migrate existing projects from plaintext secrets to secure 1Password management.

**Time Required:** 30-60 minutes (depending on number of secrets)

**Prerequisites:**
- 1Password account with vault access
- 1Password CLI (`op`) installed
- Git repository with `.env` file containing secrets
- Access to services that use the secrets

---

## Phase 1: Preparation (10 minutes)

### Step 1: Install and Configure 1Password CLI

```bash
# macOS
brew install 1password-cli

# Linux
curl -sSfO https://downloads.1password.com/linux/tar/stable/x86_64/1password-cli-latest.tar.gz
tar -xf 1password-cli-latest.tar.gz
sudo mv op /usr/local/bin/

# Verify installation
op --version
```

### Step 2: Sign In to 1Password

```bash
op signin

# Follow prompts to authenticate
# You may need your Secret Key and Master Password

# Verify sign-in
op whoami
```

### Step 3: Create or Select Vault

```bash
# List existing vaults
op vault list

# Create new vault for project (optional)
op vault create "MyProject"

# Recommended: Use separate vaults for different environments
op vault create "MyProject-Dev"
op vault create "MyProject-Production"
```

### Step 4: Backup Current Secrets

```bash
# Backup your current .env file (IMPORTANT!)
cp .env .env.backup.$(date +%Y%m%d-%H%M%S)

# Verify backup
ls -la .env.backup.*
```

---

## Phase 2: Detection and Analysis (5 minutes)

### Step 5: Scan for Secrets

Using the 1Password Secret Management Skill:

```markdown
You: "Scan my .env file for secrets"

Assistant will:
1. Detect all secrets
2. Classify by type (API keys, tokens, passwords, etc.)
3. Provide confidence scores
4. List findings without displaying secret values
```

Example output:
```
Found 12 secrets in .env:
  Line 3: GITHUB_CLIENT_SECRET (github_oauth_secret, HIGH confidence)
  Line 7: JWT_SECRET (jwt_secret, HIGH confidence)
  Line 12: DB_PASSWORD (database_password, HIGH confidence)
  Line 18: STRIPE_API_KEY (api_key, HIGH confidence)
  Line 22: AWS_SECRET_ACCESS_KEY (aws_secret_key, HIGH confidence)
  ... (7 more)

⚠️  Recommendation: Migrate all HIGH confidence secrets to 1Password
```

### Step 6: Review Findings

**Action Items:**
1. Verify all detected secrets are actually sensitive
2. Note any false positives (non-secrets detected as secrets)
3. Check for missed secrets (false negatives)
4. Document which secrets are for which services

---

## Phase 3: Create 1Password Items (15-20 minutes)

### Step 7: Organize Secrets in 1Password

**Recommended Structure:**

```
Vault: MyProject-Production
├── Item: GitHub-OAuth
│   ├── Field: client_id
│   └── Field: client_secret
├── Item: JWT-Config
│   ├── Field: secret
│   └── Field: expires_in
├── Item: Database
│   ├── Field: host
│   ├── Field: port
│   ├── Field: name
│   ├── Field: user
│   └── Field: password
├── Item: Stripe
│   └── Field: api_key
└── Item: AWS
    ├── Field: access_key_id
    └── Field: secret_access_key
```

### Step 8: Create 1Password Items

**Method 1: Using op CLI (Recommended)**

```bash
# GitHub OAuth
op item create \
  --category=Login \
  --title="GitHub-OAuth" \
  --vault="MyProject-Production" \
  'client_id[password]=<paste-your-client-id>' \
  'client_secret[password]=<paste-your-client-secret>'

# JWT Configuration
op item create \
  --category=Password \
  --title="JWT-Config" \
  --vault="MyProject-Production" \
  'secret[password]=<paste-your-jwt-secret>'

# Database
op item create \
  --category=Database \
  --title="Database" \
  --vault="MyProject-Production" \
  'hostname=localhost' \
  'port=5432' \
  'database=myapp_production' \
  'username=postgres' \
  'password[password]=<paste-your-db-password>'

# Stripe
op item create \
  --category=API_Credential \
  --title="Stripe" \
  --vault="MyProject-Production" \
  'api_key[password]=<paste-your-stripe-key>'

# AWS
op item create \
  --category=API_Credential \
  --title="AWS" \
  --vault="MyProject-Production" \
  'access_key_id[password]=<paste-your-access-key>' \
  'secret_access_key[password]=<paste-your-secret-key>'
```

**Method 2: Using 1Password App**

1. Open 1Password application
2. Select vault ("MyProject-Production")
3. Click "New Item"
4. Choose appropriate category (Login, Password, API Credential)
5. Enter item name and fields
6. Save

### Step 9: Verify Items Created

```bash
# List all items in vault
op item list --vault="MyProject-Production"

# Verify specific item exists
op item get "GitHub-OAuth" --vault="MyProject-Production"

# Test reading a field
op read "op://MyProject-Production/GitHub-OAuth/client_secret"
# Should output the secret value
```

---

## Phase 4: Generate Template (5 minutes)

### Step 10: Generate .env.template

Using the 1Password Secret Management Skill:

```markdown
You: "Generate 1Password template from my .env file"

Assistant will:
1. Read your .env file
2. Detect all secrets
3. Create .env.template with op:// references
4. Preserve non-secret variables
5. Show migration summary
```

Example output:
```
Created: .env.template

Converted 12 secrets:
  GITHUB_CLIENT_SECRET → op://MyProject-Production/GitHub-OAuth/client_secret
  JWT_SECRET → op://MyProject-Production/JWT-Config/secret
  DB_PASSWORD → op://MyProject-Production/Database/password
  STRIPE_API_KEY → op://MyProject-Production/Stripe/api_key
  AWS_SECRET_ACCESS_KEY → op://MyProject-Production/AWS/secret_access_key
  ... (7 more)

Non-secret variables preserved:
  NODE_ENV=production
  PORT=3000
  LOG_LEVEL=info
  ... (5 more)
```

### Step 11: Review .env.template

**Verify:**
```bash
# Check template was created
ls -la .env.template

# Review contents
cat .env.template

# Ensure op:// references match 1Password items
# Ensure non-secret values are unchanged
```

**Example .env.template:**
```env
# GitHub OAuth
GITHUB_CLIENT_ID=Iv1.a1b2c3d4e5f6g7h8
GITHUB_CLIENT_SECRET=op://MyProject-Production/GitHub-OAuth/client_secret

# JWT
JWT_SECRET=op://MyProject-Production/JWT-Config/secret
JWT_EXPIRES_IN=7d

# Database
DB_HOST=localhost
DB_PORT=5432
DB_PASSWORD=op://MyProject-Production/Database/password

# Non-secrets
NODE_ENV=production
PORT=3000
```

---

## Phase 5: Testing (10-15 minutes)

### Step 12: Test Secret Injection

```bash
# Test injection to temporary file
op inject -i .env.template -o /tmp/test.env

# Verify secrets were injected correctly
cat /tmp/test.env
# Should show actual secret values, not op:// references

# Clean up
rm /tmp/test.env
```

### Step 13: Test with Application

**Method 1: Local Development with Injection**

```bash
# Inject to .env.local
op inject -i .env.template -o .env.local

# Start your application (it will read .env.local)
npm start
# OR
python app.py
# OR
./myapp

# Verify application starts successfully
# Test functionality that uses secrets (API calls, database, etc.)
```

**Method 2: Using op run (Recommended)**

```bash
# Run application directly with op run
op run --no-masking -- npm start

# OR
op run --no-masking -- python app.py

# OR
op run --no-masking -- ./myapp

# Verify application works correctly
```

### Step 14: Test Systemd Integration (if applicable)

```bash
# Update systemd service file
sudo systemctl edit myapp

# Add op run wrapper:
[Service]
ExecStart=/usr/bin/op run --no-masking -- /usr/bin/myapp

# Reload and test
sudo systemctl daemon-reload
sudo systemctl restart myapp
sudo systemctl status myapp

# Check logs
sudo journalctl -u myapp -n 50
```

### Step 15: Test Docker Integration (if applicable)

```bash
# Test with Docker Compose
op run --no-masking -- docker-compose up -d

# Check containers are running
docker-compose ps

# Check logs
docker-compose logs -f

# Test application endpoints
curl http://localhost:3000/health
```

---

## Phase 6: Deployment (10 minutes)

### Step 16: Update .gitignore

```bash
# Add to .gitignore
cat >> .gitignore << 'EOF'

# Environment files with secrets (DO NOT COMMIT)
.env
.env.local
.env.*.local
*.env
.env.backup.*

# Allow templates (SAFE TO COMMIT)
!.env.template
!.env.*.template

# 1Password service tokens
service-token
*.service-token
EOF

# Verify .gitignore updated
cat .gitignore
```

### Step 17: Remove Old Secrets from Git History

**⚠️ CRITICAL:** If `.env` file was previously committed to Git:

```bash
# Option 1: If .env was recently committed (not pushed)
git reset HEAD~1  # Undo last commit
git add .gitignore .env.template
git commit -m "Add 1Password template, remove secrets"

# Option 2: If .env was pushed (requires force push - BE CAREFUL)
# Use BFG Repo-Cleaner or git-filter-repo
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch .env' \
  --prune-empty --tag-name-filter cat -- --all

# Force push (coordinate with team!)
git push origin --force --all
git push origin --force --tags
```

**Safer Option:** Rotate all secrets that were exposed in Git history.

### Step 18: Commit Template

```bash
# Stage template
git add .env.template .gitignore

# Commit
git commit -m "Add 1Password template for secure secret management

- Convert .env to .env.template with op:// references
- Update .gitignore to exclude secret files
- Secrets now managed in 1Password vault: MyProject-Production

Migration completed $(date +%Y-%m-%d)
"

# Push
git push origin main
```

### Step 19: Deploy to Production

**For Servers:**

```bash
# SSH to server
ssh production-server

# Pull latest code
cd /path/to/app
git pull

# Ensure op CLI is installed
which op || echo "Install op CLI first"

# Sign in to 1Password (one-time setup)
op signin

# Test op run
op run --no-masking -- /usr/bin/myapp --test

# Update systemd service (if applicable)
sudo systemctl edit myapp
# Add: ExecStart=/usr/bin/op run --no-masking -- /usr/bin/myapp

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart myapp
sudo systemctl status myapp
```

**For Docker:**

```bash
# Deploy with op run
op run --no-masking -- docker-compose up -d

# Verify
docker-compose ps
docker-compose logs -f
```

---

## Phase 7: Cleanup and Documentation (5 minutes)

### Step 20: Secure Old Secrets

```bash
# Move old .env file to secure location (DO NOT DELETE YET)
mkdir -p ~/.secrets-archive
mv .env.backup.* ~/.secrets-archive/
chmod 600 ~/.secrets-archive/*

# Set reminder to delete after 30 days (once migration verified)
echo "Delete ~/.secrets-archive after verifying migration" >> ~/TODO.txt
```

### Step 21: Update Team Documentation

**Create SECRETS.md:**

```bash
cat > SECRETS.md << 'EOF'
# Secret Management

This project uses 1Password for secure secret management.

## Setup for Developers

1. Install 1Password CLI: `brew install 1password-cli`
2. Sign in: `op signin`
3. Request access to vault: "MyProject-Production" (ask team lead)
4. Clone repo: `git clone ...`
5. Inject secrets: `op inject -i .env.template -o .env.local`
6. Start app: `op run --no-masking -- npm start`

## 1Password Structure

Vault: MyProject-Production
- GitHub-OAuth: OAuth credentials
- JWT-Config: JWT signing key
- Database: DB connection details
- Stripe: Payment API keys
- AWS: Cloud service credentials

## Emergency Access

If you need immediate access:
1. Contact DevOps team
2. Vault is shared with: @alice, @bob, @charlie
3. Emergency token stored in: [secure location]

## Secret Rotation

Secrets are rotated:
- Quarterly: API keys
- Annually: JWT secrets
- After incidents: All affected secrets

Last rotation: $(date +%Y-%m-%d)
Next rotation: [3 months from now]
EOF

git add SECRETS.md
git commit -m "Add secret management documentation"
git push
```

### Step 22: Verify Migration Completed

**Checklist:**

```bash
# Run this verification script
cat > verify-migration.sh << 'EOF'
#!/bin/bash
echo "=== Migration Verification Checklist ==="

# 1. Check .env.template exists
if [ -f .env.template ]; then
  echo "✓ .env.template exists"
else
  echo "✗ .env.template missing"
fi

# 2. Check old .env is archived/removed
if [ -f .env ]; then
  echo "⚠ .env still exists (should be archived)"
else
  echo "✓ .env removed"
fi

# 3. Check .gitignore updated
if grep -q ".env" .gitignore; then
  echo "✓ .gitignore updated"
else
  echo "✗ .gitignore missing .env"
fi

# 4. Check 1Password items exist
echo "Checking 1Password items..."
op item list --vault="MyProject-Production" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ 1Password vault accessible"
  ITEM_COUNT=$(op item list --vault="MyProject-Production" | wc -l)
  echo "  Found $ITEM_COUNT items in vault"
else
  echo "✗ Cannot access 1Password vault"
fi

# 5. Test injection
echo "Testing secret injection..."
op inject -i .env.template -o /tmp/test.env > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ Secret injection works"
  rm /tmp/test.env
else
  echo "✗ Secret injection failed"
fi

# 6. Check for committed secrets in Git
echo "Checking Git history for secrets..."
if git log --all --full-history -- .env | grep -q "commit"; then
  echo "⚠ .env found in Git history (consider rotating secrets)"
else
  echo "✓ No .env in Git history"
fi

echo "=== Verification Complete ==="
EOF

chmod +x verify-migration.sh
./verify-migration.sh
```

---

## Phase 8: Monitor and Maintain (Ongoing)

### Step 23: Set Up Monitoring

```bash
# Add secret audit to cron (weekly)
crontab -e

# Add this line:
0 0 * * 0 cd /path/to/project && op run --no-masking -- ./audit-secrets.sh

# Create audit script
cat > audit-secrets.sh << 'EOF'
#!/bin/bash
# Audit for plaintext secrets

echo "=== Weekly Secret Audit ==="
echo "Date: $(date)"

# Scan for plaintext secrets
find . -name "*.env" -not -name "*.template" -type f > /tmp/secret-audit.txt

if [ -s /tmp/secret-audit.txt ]; then
  echo "⚠ WARNING: Found .env files that may contain secrets:"
  cat /tmp/secret-audit.txt
  echo "These files should not exist. Investigate immediately."
else
  echo "✓ No plaintext .env files found"
fi

# Check 1Password items still exist
op item list --vault="MyProject-Production" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ 1Password vault accessible"
else
  echo "✗ Cannot access 1Password vault - investigate!"
fi

rm /tmp/secret-audit.txt
echo "=== Audit Complete ==="
EOF

chmod +x audit-secrets.sh
```

### Step 24: Schedule Secret Rotation

```markdown
Create calendar reminders:

Quarterly (Every 3 months):
- Rotate API keys (GitHub, Stripe, SendGrid, etc.)
- Update in 1Password
- Restart services to pick up new secrets
- Test all integrations

Annually (Every 12 months):
- Rotate JWT secrets
- Rotate database passwords
- Rotate SSH keys
- Review and remove unused secrets

After Security Incidents:
- Immediate rotation of affected secrets
- Review access logs
- Update incident response documentation
```

---

## Troubleshooting

### Common Issues

**Issue 1: op inject fails with "item not found"**

```bash
# Solution: Verify item exists
op item list --vault="MyProject-Production"

# Check exact item name
op item get "GitHub-OAuth" --vault="MyProject-Production"

# Verify op:// reference syntax matches
cat .env.template | grep "op://"
```

**Issue 2: Application can't read secrets**

```bash
# Solution: Test injection manually
op inject -i .env.template

# Check if application is looking for .env or .env.local
ls -la .env*

# Ensure application loads .env.local or use op run
op run --no-masking -- ./myapp
```

**Issue 3: Systemd service fails to start**

```bash
# Solution: Check service logs
sudo journalctl -u myapp -n 50

# Verify op CLI accessible to systemd
sudo which op

# Test op run manually as service user
sudo -u myapp op run --no-masking -- /usr/bin/myapp --test

# Add PATH to service file if needed
[Service]
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
```

**Issue 4: Docker container can't access secrets**

```bash
# Solution: op run must be on host, not in container
# Wrong: docker run myapp "op inject..."
# Right: op run -- docker-compose up

op run --no-masking -- docker-compose up -d
```

---

## Success Criteria

Migration is complete when:

- [ ] All secrets stored in 1Password vault
- [ ] .env.template created with op:// references
- [ ] .env file archived and removed from project
- [ ] .gitignore updated to prevent future commits
- [ ] Git history cleaned (or secrets rotated)
- [ ] Application works with op run or injection
- [ ] Systemd service uses op run (if applicable)
- [ ] Docker deployment uses op run (if applicable)
- [ ] Team documentation updated
- [ ] Monitoring and audit scripts set up
- [ ] Secret rotation schedule created
- [ ] Verification script passes all checks

**Congratulations! Your secrets are now securely managed with 1Password.**

---

## Resources

- [1Password CLI Documentation](https://developer.1password.com/docs/cli/)
- [1Password Secret References](https://developer.1password.com/docs/cli/secrets-reference-syntax/)
- [Secret Management Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [Git Filter-Repo Tool](https://github.com/newren/git-filter-repo)

**Version:** 1.0.0
**Last Updated:** 2025-12-29
