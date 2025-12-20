---
description: "Docker deployment patterns for AstraDraw"
globs: ["deploy/**/*.yml", "deploy/**/*.yaml", "deploy/.env*"]
alwaysApply: false
---

# Docker Deployment Patterns

## Deploy Folder Structure

All deployment and testing files are in `deploy/`:

```
deploy/
├── docker-compose.yml              # Main config (GHCR images)
├── docker-compose.override.yml     # Local builds (gitignored)
├── docker-compose.override.yml.disabled  # Template for local builds
├── .env                            # Environment variables (gitignored)
├── env.example                     # Environment template
├── dex-config.yaml                 # OIDC test provider config
├── traefik-dynamic.yml             # Traefik TLS config
├── certs/                          # SSL certificates (gitignored)
│   ├── server.crt
│   └── server.key
├── secrets/                        # Docker secrets (gitignored)
│   ├── minio_access_key
│   └── minio_secret_key
└── libraries/                      # Excalidraw shape libraries
    └── *.excalidrawlib
```

## Running the Application

```bash
# Navigate to deploy folder first
cd deploy

# Copy and configure environment
cp env.example .env
# Edit .env with your settings

# Start with production images
docker compose up -d

# Start with local builds (requires frontend/, backend/ repos)
cp docker-compose.override.yml.disabled docker-compose.override.yml
docker compose up -d --build

# View logs
docker compose logs -f api
docker compose logs -f app
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| traefik | traefik:v3.0 | 80, 443 | Reverse proxy |
| app | ghcr.io/astrateam-net/astradraw-app | 80 | Frontend |
| api | ghcr.io/astrateam-net/astradraw-api | 8080 | Backend API |
| room | ghcr.io/astrateam-net/astradraw-room | 80 | WebSocket |
| postgres | postgres:16-alpine | 5432 | Database |
| minio | minio/minio | 9000/9001 | Object storage |
| dex | ghcr.io/dexidp/dex (profile: oidc) | 5556 | OIDC testing |
| pgadmin | dpage/pgadmin4 (profile: admin) | 80 | DB admin |

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
3. Update `deploy/docker-compose.yml` with new image versions:
   ```yaml
   app:
     image: ghcr.io/astrateam-net/astradraw-app:0.18.0-beta0.XX
   api:
     image: ghcr.io/astrateam-net/astradraw-api:0.5.X
   ```

## Local Development Builds

The override file uses paths relative to `deploy/`:

```yaml
services:
  app:
    build:
      context: ../frontend    # Goes up to project root, then into frontend/
  api:
    build:
      context: ../backend
```

## Environment Variables

Key variables in `deploy/.env`:

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

## Testing with Dex (OIDC)

```bash
cd deploy

# Start with OIDC profile
docker compose --profile oidc up -d

# Test users (in dex-config.yaml):
# admin@example.com / admin123
# user@example.com / user123
```

## Fresh Start

To reset all data:

```bash
cd deploy
docker compose down -v
docker volume rm astradraw_postgres_data astradraw_minio_data
docker compose up -d
```

## Creating Certificates

For local HTTPS testing:

```bash
cd deploy
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/server.key -out certs/server.crt \
  -subj "/CN=localhost"
```

## Creating Secrets

```bash
cd deploy
mkdir -p secrets
echo "minioadmin" > secrets/minio_access_key
openssl rand -base64 32 > secrets/minio_secret_key
```
