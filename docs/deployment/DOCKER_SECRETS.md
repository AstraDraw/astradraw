# Docker Secrets Support

AstraDraw supports Docker secrets for all sensitive configuration. This allows you to securely manage credentials without exposing them in environment variables or `.env` files.

## Overview

All sensitive environment variables support the `_FILE` suffix pattern. When you set `VARIABLE_NAME_FILE=/path/to/secret`, the backend reads the file contents instead of looking for `VARIABLE_NAME` directly.

This is the recommended approach for production deployments.

## Quick Start

### 1. Create Secrets Directory

```bash
cd deploy
mkdir -p secrets
```

### 2. Generate Required Secrets

```bash
# Database credentials
echo "excalidraw" > secrets/postgres_user
openssl rand -base64 32 > secrets/postgres_password
echo "excalidraw" > secrets/postgres_db

# JWT secret (required for authentication)
openssl rand -base64 32 > secrets/jwt_secret

# MinIO credentials
echo "minioadmin" > secrets/minio_access_key
openssl rand -base64 32 > secrets/minio_secret_key
```

### 3. Start Services

```bash
docker compose up -d
```

The backend automatically reads secrets from `/run/secrets/` (mounted from `./secrets/`).

## Supported Secrets

### Database Configuration

| Secret File | Environment Variable | Description |
|-------------|---------------------|-------------|
| `postgres_user` | `POSTGRES_USER_FILE` | PostgreSQL username |
| `postgres_password` | `POSTGRES_PASSWORD_FILE` | PostgreSQL password |
| `postgres_db` | `POSTGRES_DB_FILE` | PostgreSQL database name |
| `database_url` | `DATABASE_URL_FILE` | Full connection string (alternative) |

**Note:** You can use either individual credentials OR a full `DATABASE_URL`. Individual credentials are recommended for external PostgreSQL.

### Authentication

| Secret File | Environment Variable | Description |
|-------------|---------------------|-------------|
| `jwt_secret` | `JWT_SECRET_FILE` | JWT signing key (required) |
| `admin_password` | `ADMIN_PASSWORD_FILE` | Default admin password |
| `superadmin_emails` | `SUPERADMIN_EMAILS_FILE` | Comma-separated super admin emails |

### OIDC/OAuth

| Secret File | Environment Variable | Description |
|-------------|---------------------|-------------|
| `oidc_client_secret` | `OIDC_CLIENT_SECRET_FILE` | OIDC client secret |
| `oidc_issuer_url` | `OIDC_ISSUER_URL_FILE` | OIDC issuer URL |
| `oidc_client_id` | `OIDC_CLIENT_ID_FILE` | OIDC client ID |

### Storage (S3/MinIO)

| Secret File | Environment Variable | Description |
|-------------|---------------------|-------------|
| `minio_access_key` | `S3_ACCESS_KEY_FILE` | S3/MinIO access key |
| `minio_secret_key` | `S3_SECRET_KEY_FILE` | S3/MinIO secret key |

### Collaboration (Auto-Collab Feature)

| Secret File | Environment Variable | Description |
|-------------|---------------------|-------------|
| `room_key_secret` | `ROOM_KEY_SECRET_FILE` | Room key encryption secret (optional) |

**Note:** `ROOM_KEY_SECRET` is **optional**. If not set, the system uses `JWT_SECRET` for room key encryption. You only need a separate `ROOM_KEY_SECRET` if you want to rotate `JWT_SECRET` without invalidating existing collaboration rooms.

**Key Generation:**
```bash
# Generate room_key_secret (any length, will be hashed with SHA-256)
openssl rand -base64 32 > secrets/room_key_secret
```

> ⚠️ **Important:** This secret encrypts room keys stored in the database. It can be any length string. The actual room keys (used for end-to-end encryption) are automatically generated as 22-character strings (16 bytes base64url) to meet AES-128-GCM requirements.

### External Services (Backend)

| Secret File | Environment Variable | Description |
|-------------|---------------------|-------------|
| `kinescope_api_key` | `KINESCOPE_API_KEY_FILE` | Kinescope API key (Talktrack) |
| `kinescope_project_id` | `KINESCOPE_PROJECT_ID_FILE` | Kinescope project ID |

### Frontend Environment Variables (NO `_FILE` support)

The following variables are **frontend-only** and do NOT support Docker secrets:

| Environment Variable | Description |
|---------------------|-------------|
| `VITE_APP_GIPHY_API_KEY` | GIPHY API key for Stickers & GIFs |

**Why?** Frontend environment variables are injected at build/runtime via Vite and `window.__ENV__`. They don't have access to the backend's `getSecret()` utility.

To use GIPHY, pass the API key directly:
```yaml
app:
  environment:
    - VITE_APP_GIPHY_API_KEY=${GIPHY_API_KEY}
```

## External PostgreSQL

To use an external PostgreSQL server instead of the built-in container:

### 1. Create Secrets

```bash
echo "your_db_user" > secrets/postgres_user
echo "your_db_password" > secrets/postgres_password
echo "your_db_name" > secrets/postgres_db
```

### 2. Configure Host and Port

Add to `deploy/.env`:

```bash
POSTGRES_HOST=10.10.120.50
POSTGRES_PORT=5678
```

### 3. Start Without Built-in PostgreSQL

```bash
docker compose up -d --scale postgres=0
```

### Alternative: Use DATABASE_URL

Instead of individual credentials, you can provide a full connection string:

```bash
echo "postgresql://user:password@host:5432/database?schema=public" > secrets/database_url
```

Then in `docker-compose.yml`, use:

```yaml
environment:
  - DATABASE_URL_FILE=/run/secrets/database_url
```

## How It Works

The backend uses a `getSecret()` utility function that:

1. Checks if `VARIABLE_NAME_FILE` environment variable exists
2. If yes, reads the file contents from that path
3. If no, falls back to `VARIABLE_NAME` environment variable
4. If neither exists, uses the default value (if provided)

```typescript
// Example usage in code
import { getSecret } from '../utils/secrets';

const jwtSecret = getSecret('JWT_SECRET', 'fallback-value');
// Checks JWT_SECRET_FILE first, then JWT_SECRET, then uses fallback
```

## Directory Structure

Recommended secrets directory structure:

```
deploy/
├── docker-compose.yml
├── .env                    # Non-sensitive config only
├── secrets/                # All secrets (gitignored)
│   ├── postgres_user
│   ├── postgres_password
│   ├── postgres_db
│   ├── jwt_secret
│   ├── minio_access_key
│   ├── minio_secret_key
│   ├── oidc_client_secret  # If using OIDC
│   ├── superadmin_emails   # Optional
│   ├── admin_password      # Optional
│   ├── room_key_secret     # Optional (defaults to jwt_secret)
│   ├── kinescope_api_key   # If using Talktrack
│   └── kinescope_project_id
└── logs/
```

## Security Best Practices

### 1. File Permissions

Restrict access to secrets:

```bash
chmod 600 secrets/*
chmod 700 secrets/
```

### 2. Git Ignore

Ensure secrets are never committed (already in `.gitignore`):

```gitignore
deploy/secrets/
```

### 3. Backup Secrets Securely

Back up your secrets directory separately from the codebase, using encrypted storage.

### 4. Rotate Secrets Regularly

For production, rotate secrets periodically:

```bash
# Generate new JWT secret
openssl rand -base64 32 > secrets/jwt_secret

# Restart services
docker compose restart api
```

**Note:** Rotating `JWT_SECRET` will invalidate all existing user sessions.

### 5. Use Strong Passwords

Always use cryptographically secure random values:

```bash
# For passwords/secrets
openssl rand -base64 32

# For shorter tokens
openssl rand -hex 16
```

## Docker Compose Configuration

The `docker-compose.yml` mounts secrets and sets `_FILE` environment variables:

```yaml
services:
  api:
    environment:
      # PostgreSQL via secrets
      - POSTGRES_HOST=${POSTGRES_HOST:-postgres}
      - POSTGRES_PORT=${POSTGRES_PORT:-5432}
      - POSTGRES_USER_FILE=/run/secrets/postgres_user
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
      - POSTGRES_DB_FILE=/run/secrets/postgres_db
      
      # JWT via secret
      - JWT_SECRET_FILE=/run/secrets/jwt_secret
      
      # S3/MinIO via secrets
      - S3_ACCESS_KEY_FILE=/run/secrets/minio_access_key
      - S3_SECRET_KEY_FILE=/run/secrets/minio_secret_key
    volumes:
      - ./secrets:/run/secrets:ro
```

## Mixing Secrets and Environment Variables

You can mix both approaches. The `_FILE` suffix takes precedence:

```yaml
environment:
  # This will be ignored if JWT_SECRET_FILE is set
  - JWT_SECRET=${JWT_SECRET:-fallback}
  # This takes precedence
  - JWT_SECRET_FILE=/run/secrets/jwt_secret
```

## Troubleshooting

### Secret Not Loading

Check the logs for secret loading messages:

```bash
docker compose logs api | grep -i secret
```

You should see:

```
[Secrets] Loaded JWT_SECRET from file (JWT_SECRET_FILE)
[Secrets] Loaded POSTGRES_PASSWORD from file (POSTGRES_PASSWORD_FILE)
```

### File Not Found

If you see warnings like:

```
[Secrets] JWT_SECRET_FILE is set to /run/secrets/jwt_secret but file does not exist
```

Verify:
1. The file exists in `deploy/secrets/`
2. The secrets volume is mounted correctly
3. File permissions allow reading

### Database Connection Failed

If using external PostgreSQL:

1. Verify host is reachable from Docker:
   ```bash
   docker compose exec api ping -c 1 10.1.125.55
   ```

2. Check credentials:
   ```bash
   cat secrets/postgres_user
   cat secrets/postgres_password
   ```

3. Verify the database exists on the external server

### Permission Denied

If secrets can't be read:

```bash
# Fix permissions
chmod 644 secrets/*
chmod 755 secrets/
```

## Migration from Environment Variables

To migrate from `.env` to secrets:

1. Create secret files from current values:
   ```bash
   # Extract from .env
   grep POSTGRES_PASSWORD .env | cut -d= -f2 > secrets/postgres_password
   grep JWT_SECRET .env | cut -d= -f2 > secrets/jwt_secret
   ```

2. Remove sensitive values from `.env`

3. Restart services:
   ```bash
   docker compose down
   docker compose up -d
   ```

## Complete Example

### Minimal Production Setup

```bash
# 1. Create secrets
mkdir -p deploy/secrets
cd deploy/secrets

echo "excalidraw" > postgres_user
openssl rand -base64 32 > postgres_password
echo "excalidraw" > postgres_db
openssl rand -base64 32 > jwt_secret
echo "minioadmin" > minio_access_key
openssl rand -base64 32 > minio_secret_key
echo "admin@yourcompany.com" > superadmin_emails

# 2. Set permissions
chmod 600 *
cd ..

# 3. Configure .env (non-sensitive only)
cat > .env << EOF
APP_DOMAIN=draw.yourcompany.com
APP_PROTOCOL=https
STORAGE_BACKEND=s3
S3_BUCKET=excalidraw
EOF

# 4. Start
docker compose up -d
```

### With External PostgreSQL and OIDC

```bash
# Secrets
echo "db_user" > secrets/postgres_user
echo "db_password" > secrets/postgres_password
echo "astradraw" > secrets/postgres_db
openssl rand -base64 32 > secrets/jwt_secret
echo "your-oidc-client-secret" > secrets/oidc_client_secret

# .env
cat > .env << EOF
APP_DOMAIN=draw.yourcompany.com
APP_PROTOCOL=https

# External PostgreSQL
POSTGRES_HOST=db.yourcompany.com
POSTGRES_PORT=5432

# OIDC
OIDC_ISSUER_URL=https://auth.yourcompany.com/realms/main
OIDC_CLIENT_ID=astradraw
OIDC_INTERNAL_URL=http://keycloak:8080/realms/main
EOF

# Start without built-in postgres
docker compose up -d --scale postgres=0
```

## Related Documentation

- [Architecture Overview](../architecture/ARCHITECTURE.md) - System architecture
- [SSO / OIDC Setup](SSO_OIDC_SETUP.md) - Single Sign-On configuration
- [Workspace & Auth](../features/WORKSPACE.md) - Authentication details
- [Contributing](../../CONTRIBUTING.md) - Development setup

