# SSO / OIDC Configuration Guide

This guide explains how to configure Single Sign-On (SSO) for AstraDraw using OIDC providers like Authentik, Keycloak, or any standard OIDC-compliant identity provider.

## Overview

AstraDraw supports OIDC (OpenID Connect) for authentication. When configured, users can log in using your organization's identity provider instead of local credentials.

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│   User Browser  │──────│   AstraDraw     │──────│  OIDC Provider  │
│                 │      │ draw.example.com│      │auth.example.com │
└─────────────────┘      └─────────────────┘      └─────────────────┘
        │                        │                        │
        │  1. Click "Login"      │                        │
        │───────────────────────>│                        │
        │                        │  2. Redirect to OIDC   │
        │<───────────────────────│───────────────────────>│
        │                        │                        │
        │  3. User authenticates │                        │
        │<───────────────────────────────────────────────>│
        │                        │                        │
        │  4. Callback with code │                        │
        │───────────────────────>│  5. Exchange code      │
        │                        │───────────────────────>│
        │                        │  6. Get user info      │
        │                        │<───────────────────────│
        │  7. Set JWT cookie     │                        │
        │<───────────────────────│                        │
```

## Example Setup

| Component | URL |
|-----------|-----|
| AstraDraw | `https://draw.example.com` |
| OIDC Provider (Authentik) | `https://auth.example.com` |
| Callback URL | `https://draw.example.com/api/v2/auth/callback` |

## Authentik Configuration

### Step 1: Create an Application

1. Log in to Authentik Admin (`https://auth.example.com/if/admin/`)
2. Go to **Applications** → **Applications**
3. Click **Create**
4. Fill in:
   - **Name**: `AstraDraw`
   - **Slug**: `astradraw`
   - **Provider**: (create in next step)

### Step 2: Create an OAuth2/OpenID Provider

1. Go to **Applications** → **Providers**
2. Click **Create**
3. Select **OAuth2/OpenID Provider**
4. Fill in:

| Field | Value |
|-------|-------|
| Name | `AstraDraw` |
| Authentication flow | `default-authentication-flow` |
| Authorization flow | `default-provider-authorization-implicit-consent` |
| Client type | `Confidential` |
| Client ID | (auto-generated, copy this) |
| Client Secret | (auto-generated, copy this) |
| Redirect URIs | `https://draw.example.com/api/v2/auth/callback` |
| Signing Key | `authentik Self-signed Certificate` |

5. Under **Advanced protocol settings**:
   - **Subject mode**: `Based on the User's Email`
   - **Include claims in id_token**: ✅ Enabled
   - **Scopes**: Select `email`, `openid`, `profile`

6. Click **Create**

### Step 3: Assign Provider to Application

1. Go back to **Applications** → **Applications**
2. Edit the `AstraDraw` application
3. Set **Provider** to the provider you just created
4. Click **Update**

### Step 4: Note the URLs

After creating the provider, Authentik shows the OIDC URLs:

| URL Type | Value |
|----------|-------|
| OpenID Configuration URL | `https://auth.example.com/application/o/astradraw/.well-known/openid-configuration` |
| Issuer | `https://auth.example.com/application/o/astradraw/` |
| Authorize URL | `https://auth.example.com/application/o/authorize/` |
| Token URL | `https://auth.example.com/application/o/token/` |
| Userinfo URL | `https://auth.example.com/application/o/userinfo/` |

**Important:** The **Issuer URL** is what you'll use for `OIDC_ISSUER_URL`.

## AstraDraw Configuration

### Option 1: Using Docker Secrets (Recommended)

Create secret files:

```bash
cd deploy/secrets

# OIDC configuration
echo "https://auth.example.com/application/o/astradraw/" > oidc_issuer_url
echo "your-client-id-from-authentik" > oidc_client_id
echo "your-client-secret-from-authentik" > oidc_client_secret
```

Update `docker-compose.yml` to use secrets:

```yaml
api:
  environment:
    # REQUIRED: App URL for redirects after login
    - APP_URL=https://draw.example.com
    
    # OIDC via Docker secrets
    - OIDC_ISSUER_URL_FILE=/run/secrets/oidc_issuer_url
    - OIDC_CLIENT_ID_FILE=/run/secrets/oidc_client_id
    - OIDC_CLIENT_SECRET_FILE=/run/secrets/oidc_client_secret
    - OIDC_CALLBACK_URL=https://draw.example.com/api/v2/auth/callback
```

### Option 2: Using Environment Variables

Add to `deploy/.env`:

```bash
# OIDC Configuration
OIDC_ISSUER_URL=https://auth.example.com/application/o/astradraw/
OIDC_CLIENT_ID=your-client-id-from-authentik
OIDC_CLIENT_SECRET=your-client-secret-from-authentik
```

The callback URL is automatically built from `APP_PROTOCOL` and `APP_DOMAIN`:

```bash
APP_DOMAIN=draw.example.com
APP_PROTOCOL=https
# Results in: OIDC_CALLBACK_URL=https://draw.example.com/api/v2/auth/callback
```

### Option 3: Internal URL for Docker Networking

If your OIDC provider is in the same Docker network (e.g., running Authentik in Docker), you may need to use an internal URL for OIDC discovery to avoid SSL/routing issues:

```bash
# External URL (what users see in browser)
OIDC_ISSUER_URL=https://auth.example.com/application/o/astradraw/

# Internal URL (for Docker-to-Docker communication)
OIDC_INTERNAL_URL=http://authentik-server:9000/application/o/astradraw/
```

The backend uses `OIDC_INTERNAL_URL` for discovery but validates tokens against `OIDC_ISSUER_URL`.

## Required Environment Variables

The following environment variables **must be set** for SSO to work:

| Variable | Description | Example |
|----------|-------------|---------|
| `APP_URL` | **Required.** Full URL of your AstraDraw instance. Used for redirects after login. | `https://draw.example.com` |
| `OIDC_ISSUER_URL` | OIDC provider's issuer URL | `https://auth.example.com/application/o/astradraw/` |
| `OIDC_CLIENT_ID` | Client ID from your OIDC provider | `mOWFfhX2RFM7MSFPqJeMTnxzBd205Hq14lqCE3EU` |
| `OIDC_CLIENT_SECRET` | Client secret from your OIDC provider | (secret value) |
| `OIDC_CALLBACK_URL` | Callback URL (must match OIDC provider config) | `https://draw.example.com/api/v2/auth/callback` |

Optional:

| Variable | Description | Example |
|----------|-------------|---------|
| `OIDC_INTERNAL_URL` | Internal URL for Docker-to-Docker communication | `http://authentik-server:9000/application/o/astradraw/` |
| `ENABLE_LOCAL_AUTH` | Enable local username/password login | `true` or `false` |
| `SUPERADMIN_EMAILS` | Comma-separated list of super admin emails | `admin@example.com` |

## Complete Example Configuration

### deploy/.env

```bash
# Domain Configuration
APP_DOMAIN=draw.example.com
APP_PROTOCOL=https

# OIDC Configuration (Authentik)
OIDC_ISSUER_URL=https://auth.example.com/application/o/astradraw/
OIDC_CLIENT_ID=m0WFfhX2RFM7MSFPqJeMTnxzBd205Hq141qCE3EU
OIDC_CLIENT_SECRET=your-secret-here

# Optional: Internal URL if Authentik is in Docker
# OIDC_INTERNAL_URL=http://authentik-server:9000/application/o/astradraw/

# Disable local auth when using SSO (optional)
ENABLE_LOCAL_AUTH=false

# Super admins (these users get admin privileges)
SUPERADMIN_EMAILS=admin@example.com,it-admin@example.com
```

### deploy/secrets/ (Alternative)

```bash
# Create secrets
echo "https://auth.example.com/application/o/astradraw/" > secrets/oidc_issuer_url
echo "m0WFfhX2RFM7MSFPqJeMTnxzBd205Hq141qCE3EU" > secrets/oidc_client_id
echo "your-secret-here" > secrets/oidc_client_secret
echo "admin@example.com,it-admin@example.com" > secrets/superadmin_emails
```

## Keycloak Configuration

If using Keycloak instead of Authentik:

### Step 1: Create a Client

1. Go to your realm → **Clients** → **Create client**
2. Fill in:
   - **Client ID**: `astradraw`
   - **Client Protocol**: `openid-connect`
3. Click **Next**
4. Configure:
   - **Client authentication**: `On`
   - **Authorization**: `Off`
   - **Authentication flow**: Check `Standard flow`
5. Click **Next**
6. Set:
   - **Valid redirect URIs**: `https://draw.example.com/api/v2/auth/callback`
   - **Web origins**: `https://draw.example.com`
7. Click **Save**

### Step 2: Get Credentials

1. Go to **Clients** → `astradraw` → **Credentials**
2. Copy the **Client secret**

### Step 3: Configure AstraDraw

```bash
# Keycloak issuer URL format
OIDC_ISSUER_URL=https://auth.example.com/realms/your-realm
OIDC_CLIENT_ID=astradraw
OIDC_CLIENT_SECRET=your-client-secret
```

## Generic OIDC Provider

For any OIDC-compliant provider, you need:

| Required | Description |
|----------|-------------|
| Issuer URL | The OIDC issuer URL (has `.well-known/openid-configuration`) |
| Client ID | Your application's client ID |
| Client Secret | Your application's client secret |
| Redirect URI | `https://draw.example.com/api/v2/auth/callback` |
| Scopes | `openid email profile` |

Configure in AstraDraw:

```bash
OIDC_ISSUER_URL=https://your-provider.com/...
OIDC_CLIENT_ID=your-client-id
OIDC_CLIENT_SECRET=your-client-secret
```

## User Provisioning

### Automatic User Creation

When a user logs in via OIDC for the first time:

1. AstraDraw creates a new user account
2. Email and name are populated from OIDC claims
3. A default workspace is created for the user
4. If the email matches `SUPERADMIN_EMAILS`, they get super admin privileges

### User Linking

If a user already exists (e.g., from local auth):

1. AstraDraw first checks by OIDC ID (returning user)
2. Then checks by email (migration from local to SSO)
3. Creates new user if neither found

This allows smooth migration from local auth to SSO.

### Claims Mapping

AstraDraw expects these OIDC claims:

| Claim | Usage |
|-------|-------|
| `sub` | Unique user identifier (OIDC ID) |
| `email` | User's email address |
| `name` | Display name (falls back to `preferred_username`) |
| `picture` | Avatar URL (optional) |

## Disabling Local Authentication

Once SSO is working, you can disable local authentication:

```bash
# Disable local auth
ENABLE_LOCAL_AUTH=false

# Also disable registration
ENABLE_REGISTRATION=false
```

**Warning:** Make sure at least one admin can log in via SSO before disabling local auth!

## Troubleshooting

### "OIDC configuration missing"

Ensure all three are set:
- `OIDC_ISSUER_URL`
- `OIDC_CLIENT_ID`
- `OIDC_CLIENT_SECRET`

### "Invalid redirect URI"

The redirect URI in your OIDC provider must exactly match:
```
https://draw.example.com/api/v2/auth/callback
```

Check for:
- Trailing slashes
- HTTP vs HTTPS
- Correct domain

### Discovery fails in Docker

If the backend can't reach the OIDC provider:

1. Use `OIDC_INTERNAL_URL` for Docker-internal communication
2. Add the auth domain to `extra_hosts` in docker-compose.yml:
   ```yaml
   api:
     extra_hosts:
       - "auth.example.com:host-gateway"
   ```

### SSL Certificate Errors

For self-signed certificates in development:

1. The backend allows insecure requests for OIDC discovery
2. Users still need to accept the certificate in their browser

### Check OIDC Discovery

Test that the issuer URL is correct:

```bash
curl https://auth.example.com/application/o/astradraw/.well-known/openid-configuration
```

Should return JSON with `issuer`, `authorization_endpoint`, `token_endpoint`, etc.

### View Backend Logs

```bash
docker compose logs api | grep -i oidc
```

Look for:
- "Discovering OIDC provider at..."
- "User authenticated: user@example.com"
- Any error messages

## Security Considerations

1. **Always use HTTPS** in production
2. **Keep client secret secure** - use Docker secrets, not environment variables
3. **Validate redirect URIs** - use `strict:` prefix in Authentik
4. **Limit scopes** - only request `openid email profile`
5. **Use confidential client** - not public client
6. **Rotate secrets** periodically

## Related Documentation

- [Docker Secrets](DOCKER_SECRETS.md) - Secure credential management
- [Workspace & Auth](../features/WORKSPACE.md) - Authentication details
- [Architecture](../architecture/ARCHITECTURE.md) - System overview

