---
description: "Docker deployment patterns for AstraDraw"
globs: ["docker-compose*.yml", "Dockerfile", ".env*"]
alwaysApply: false
---

# Docker Deployment Patterns

## Docker Compose Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Main production config with GHCR images |
| `docker-compose.override.yml` | Local builds (gitignored, auto-merged) |
| `docker-compose.override.yml.disabled` | Template for local builds |

## Services

```yaml
services:
  traefik:    # Reverse proxy (ports 80, 443)
  app:        # Frontend (ghcr.io/astrateam-net/astradraw-app)
  api:        # Backend (ghcr.io/astrateam-net/astradraw-storage)
  room:       # WebSocket (excalidraw/excalidraw-room)
  postgres:   # Database
  minio:      # Object storage
  dex:        # OIDC provider for testing (profile: oidc)
  pgadmin:    # Database admin (profile: admin)
```

## Image Versioning

When releasing new versions:

1. Update `CHANGELOG.md` in the respective repo
2. Tag and push:
   ```bash
   # Frontend
   cd frontend
   git tag v0.18.0-beta0.XX
   git push origin main --tags

   # Backend
   cd backend
   git tag v0.5.X
   git push origin main --tags
   ```
3. Update `docker-compose.yml` with new image versions:
   ```yaml
   app:
     image: ghcr.io/astrateam-net/astradraw-app:0.18.0-beta0.XX
   api:
     image: ghcr.io/astrateam-net/astradraw-storage:0.5.X
   ```

## Local Development Builds

To build locally instead of using GHCR images:

```bash
# Enable local builds
cp docker-compose.override.yml.disabled docker-compose.override.yml

# Build and start
docker compose up -d --build
```

The override file changes:
```yaml
app:
  build:
    context: ./frontend
    dockerfile: Dockerfile
api:
  build:
    context: ./backend
    dockerfile: Dockerfile
```

## Environment Variables

Key variables in `.env`:

```bash
APP_DOMAIN=localhost          # Or your domain
APP_PROTOCOL=https            # http or https
POSTGRES_USER=excalidraw
POSTGRES_PASSWORD=<secure>
POSTGRES_DB=excalidraw

# Optional OIDC
OIDC_ISSUER_URL=https://auth.example.com/...
OIDC_CLIENT_ID=astradraw
OIDC_CLIENT_SECRET=<secret>
OIDC_INTERNAL_URL=http://dex:5556/dex  # For Docker networking

# Optional features
GIPHY_API_KEY=<key>
KINESCOPE_API_KEY=<key>
KINESCOPE_PROJECT_ID=<id>
```

## Docker Secrets

Sensitive values use the `_FILE` suffix pattern:

```yaml
environment:
  - S3_ACCESS_KEY_FILE=/run/secrets/minio_access_key
volumes:
  - ./secrets:/run/secrets:ro
```

Create secrets:
```bash
mkdir -p secrets
echo "minioadmin" > secrets/minio_access_key
openssl rand -base64 32 > secrets/minio_secret_key
```

## Traefik Routing

Routes are defined via Docker labels:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.my-service.rule=Host(`${APP_DOMAIN}`) && PathPrefix(`/api/v2`)"
  - "traefik.http.routers.my-service.entrypoints=websecure"
  - "traefik.http.routers.my-service.tls=true"
  - "traefik.http.services.my-service.loadbalancer.server.port=8080"
```

## Testing with Dex (OIDC)

```bash
# Start with OIDC profile
docker compose --profile oidc up -d

# Test users (in dex-config.yaml):
# admin@example.com / admin123
# user@example.com / user123
```

## Fresh Start

To reset all data:

```bash
docker compose down -v
docker volume rm astradraw_postgres_data astradraw_minio_data
docker compose up -d
```

