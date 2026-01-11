# Xero OAuth 2.0 Flow Reference

## Authorization Code Flow Diagram

```
+--------+                               +---------------+
|        |--(A)- Authorization Request ->|   Resource    |
|        |                               |    Owner      |
|        |<-(B)-- Authorization Grant ---|               |
|        |                               +---------------+
|        |
|        |                               +---------------+
|        |--(C)-- Authorization Grant -->| Authorization |
| Client |                               |     Server    |
|        |<-(D)----- Access Token -------|               |
|        |                               +---------------+
|        |
|        |                               +---------------+
|        |--(E)----- Access Token ------>|    Resource   |
|        |                               |     Server    |
|        |<-(F)--- Protected Resource ---|               |
+--------+                               +---------------+
```

## Step-by-Step Implementation

### Step 1: Generate Authorization URL

Build the authorization URL with required parameters:

```
Base URL: https://login.xero.com/identity/connect/authorize

Parameters:
- response_type: code
- client_id: Your application's client ID
- redirect_uri: Your registered callback URL
- scope: Space-separated list of scopes
- state: Random string for CSRF protection
```

Example URL:
```
https://login.xero.com/identity/connect/authorize?
  response_type=code&
  client_id=ABC123...&
  redirect_uri=https://example.com/callback&
  scope=openid profile email offline_access accounting.transactions accounting.contacts&
  state=xyz789
```

### Step 2: Handle Authorization Callback

User is redirected to your callback URL with:
- `code`: Authorization code (valid for 30 seconds)
- `state`: Must match your original state

Example callback:
```
https://example.com/callback?code=AUTH_CODE_HERE&state=xyz789
```

### Step 3: Exchange Code for Tokens

```http
POST https://identity.xero.com/connect/token
Content-Type: application/x-www-form-urlencoded
Authorization: Basic base64(client_id:client_secret)

grant_type=authorization_code&
code=AUTH_CODE_HERE&
redirect_uri=https://example.com/callback
```

Response:
```json
{
  "id_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6...",
  "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6...",
  "expires_in": 1800,
  "token_type": "Bearer",
  "refresh_token": "abc123...",
  "scope": "openid profile email offline_access accounting.transactions"
}
```

### Step 4: Get Connected Tenants

```http
GET https://api.xero.com/connections
Authorization: Bearer ACCESS_TOKEN
```

Response:
```json
[
  {
    "id": "connection-uuid",
    "tenantId": "tenant-uuid",
    "tenantType": "ORGANISATION",
    "tenantName": "Demo Company (US)",
    "createdDateUtc": "2026-01-10T00:00:00.0000000Z",
    "updatedDateUtc": "2026-01-10T00:00:00.0000000Z"
  }
]
```

### Step 5: Make API Calls

```http
GET https://api.xero.com/api.xro/2.0/Invoices
Authorization: Bearer ACCESS_TOKEN
xero-tenant-id: TENANT_ID
Accept: application/json
```

### Step 6: Refresh Access Token

Access tokens expire after 30 minutes. Refresh before expiry:

```http
POST https://identity.xero.com/connect/token
Content-Type: application/x-www-form-urlencoded
Authorization: Basic base64(client_id:client_secret)

grant_type=refresh_token&
refresh_token=CURRENT_REFRESH_TOKEN
```

Response includes new access_token and refresh_token.

## Scope Reference

### OpenID Connect Scopes

| Scope | Description |
|-------|-------------|
| `openid` | Required for OpenID Connect |
| `profile` | User's name |
| `email` | User's email |
| `offline_access` | Get refresh tokens |

### Accounting API Scopes

| Scope | Description |
|-------|-------------|
| `accounting.transactions` | Read/write invoices, bills, bank transactions |
| `accounting.transactions.read` | Read-only transactions |
| `accounting.contacts` | Read/write contacts |
| `accounting.contacts.read` | Read-only contacts |
| `accounting.settings` | Read/write organization settings |
| `accounting.settings.read` | Read-only settings |
| `accounting.reports.read` | Read financial reports |
| `accounting.attachments` | Manage attachments |
| `accounting.attachments.read` | Read-only attachments |

### Other API Scopes

| Scope | Description |
|-------|-------------|
| `files` | Files API access |
| `files.read` | Read-only files |
| `assets` | Assets API access |
| `assets.read` | Read-only assets |
| `projects` | Projects API access |
| `projects.read` | Read-only projects |
| `payroll.employees` | Payroll employees |
| `payroll.employees.read` | Read-only payroll |

## Token Lifetimes

| Token Type | Lifetime | Notes |
|------------|----------|-------|
| Authorization Code | 30 seconds | Single use |
| Access Token | 30 minutes | Use for API calls |
| Refresh Token | Until revoked | Secure storage required |
| ID Token | 30 minutes | Contains user info |

## Error Responses

### Token Request Errors

```json
{
  "error": "invalid_grant",
  "error_description": "The authorization code has expired"
}
```

Common errors:
- `invalid_grant`: Code expired or already used
- `invalid_client`: Bad client credentials
- `invalid_scope`: Requested scope not authorized
- `unauthorized_client`: Client not authorized for grant type

### API Errors

```json
{
  "Type": "OAuth2",
  "Title": "Unauthorized",
  "Detail": "The access token has expired"
}
```

## PKCE Extension (Public Clients)

For mobile/SPA apps without client secrets:

### Step 1: Generate Code Verifier

```python
import secrets
import base64
import hashlib

code_verifier = secrets.token_urlsafe(64)[:128]

# Generate code_challenge
code_challenge = base64.urlsafe_b64encode(
    hashlib.sha256(code_verifier.encode()).digest()
).rstrip(b'=').decode()
```

### Step 2: Include in Authorization Request

```
https://login.xero.com/identity/connect/authorize?
  response_type=code&
  client_id=ABC123&
  redirect_uri=https://example.com/callback&
  scope=openid offline_access accounting.transactions&
  state=xyz789&
  code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&
  code_challenge_method=S256
```

### Step 3: Include Verifier in Token Request

```http
POST https://identity.xero.com/connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&
code=AUTH_CODE&
redirect_uri=https://example.com/callback&
client_id=ABC123&
code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
```

## Disconnect and Revoke

### Remove Connection

Delete a specific organization connection:

```http
DELETE https://api.xero.com/connections/{connection_id}
Authorization: Bearer ACCESS_TOKEN
```

### Revoke All Tokens

Revoke all tokens for the user:

```http
POST https://identity.xero.com/connect/revocation
Content-Type: application/x-www-form-urlencoded
Authorization: Basic base64(client_id:client_secret)

token=REFRESH_TOKEN
```

## Security Checklist

- [ ] Store client secret securely (never in client-side code)
- [ ] Validate state parameter matches on callback
- [ ] Use HTTPS for all redirect URIs in production
- [ ] Implement token refresh before expiry
- [ ] Store refresh tokens encrypted
- [ ] Handle token revocation gracefully
- [ ] Request minimum required scopes
- [ ] Implement PKCE for public clients
