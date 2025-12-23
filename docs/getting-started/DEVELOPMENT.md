# Development Guide

This guide explains how to set up and run AstraDraw for local development.

## Quick Start

```bash
# One command to start everything
just dev

# Access the app
open https://draw.local
```

That's it! The app is now running with full hot-reloading support.

## Development Modes

AstraDraw supports two development approaches:

| Mode | Command | Use Case |
|------|---------|----------|
| **Hybrid Dev** | `just dev` | Daily development with hot-reload |
| **Docker Dev** | `just up-dev` | Testing Docker images before release |

### Hybrid Development (Recommended)

**Use this for daily development.** It provides:

- ⚡ **Instant CSS updates** - Changes appear immediately in browser
- ⚡ **Instant React updates** - Components re-render without losing state
- ⚡ **Auto-restart backend** - TypeScript changes trigger automatic restart
- 🐳 **Real infrastructure** - PostgreSQL, MinIO, Traefik run in Docker

```
┌─────────────────────────────────────────────────────────────┐
│                    Hybrid Development                        │
├─────────────────────────────────────────────────────────────┤
│  Native (hot-reload):          Docker (infrastructure):     │
│  ├── Frontend (Vite)           ├── PostgreSQL               │
│  ├── Backend (NestJS)          ├── MinIO (S3)               │
│  └── Room Service              ├── Traefik (reverse proxy)  │
│                                └── Dex (OIDC)               │
└─────────────────────────────────────────────────────────────┘
```

### Docker Development

**Use this only when:**
- Testing Dockerfile changes
- Testing `docker-entrypoint.sh` changes
- Verifying Docker images work before release
- Debugging production-specific issues

```bash
# Build and run with local Docker images
just up-dev

# Or fresh start (removes data)
just fresh-dev
```

## Commands Reference

### Development Commands

| Command | Description |
|---------|-------------|
| `just dev` | Start hybrid dev environment (recommended) |
| `just dev-stop` | Stop all services |
| `just dev-status` | Check status of all services |
| `just dev-frontend` | Start only frontend (if running manually) |
| `just dev-backend` | Start only backend (if running manually) |
| `just dev-room` | Start only room service (if running manually) |

### Docker Commands

| Command | Description |
|---------|-------------|
| `just up-dev` | Start with locally-built Docker images |
| `just fresh-dev` | Fresh start with local images (removes data) |
| `just up` | Start with production images from GHCR |
| `just down` | Stop all Docker services |

### Utility Commands

| Command | Description |
|---------|-------------|
| `just install` | Install dependencies for all services |
| `just check-all` | Run linting/type checks on all services |
| `just fix-all` | Auto-fix formatting issues |
| `just db-studio` | Open Prisma Studio (database GUI) |

## Hot-Reloading Behavior

### Changes that apply INSTANTLY (no action needed)

| Change Type | What Happens |
|-------------|--------------|
| CSS/SCSS files | Browser updates immediately via Vite HMR |
| React components | Component re-renders, state is preserved |
| Frontend TypeScript | Compiles and updates via Vite HMR |

**Example workflow:**
1. Edit `frontend/excalidraw-app/components/Workspace/WorkspaceSidebar.scss`
2. Save the file
3. See changes immediately in browser ✨

### Changes that require BROWSER REFRESH

| Change Type | Reason |
|-------------|--------|
| Translation keys (en.json, ru-RU.json) | JSON files not in HMR scope |
| index.html changes | Static file not watched |
| env-config.js | Environment config |

### Changes that auto-restart the service

| Change Type | Service | Behavior |
|-------------|---------|----------|
| Backend TypeScript | Backend | NestJS watch mode auto-restarts |
| Room service TypeScript | Room | ts-node-dev auto-restarts |

**Note:** You'll see restart messages in the terminal when this happens.

### Changes that require manual action

| Change Type | Action Required |
|-------------|-----------------|
| Prisma schema | Run `cd backend && npx prisma migrate dev` |
| New npm packages | Run `just install`, then restart with `just dev` |
| Backend .env changes | Restart backend or full `just dev` |

## Initial Setup (First Time Only)

For new developers, run the full setup:

```bash
just setup
```

This will:
1. Check if `draw.local` is in your hosts file
2. Clone the frontend, backend, and room-service repos
3. Create the `.env` file from template
4. Generate secrets for MinIO
5. Generate SSL certificate for `draw.local`
6. Install all dependencies

## Prerequisites

### Required Software

- Node.js 18+ (recommended: use nvm)
- Docker Desktop
- Just command runner (`brew install just`)

### Host Configuration (Required!)

**⚠️ You must add `draw.local` to your hosts file BEFORE running setup.**

**macOS / Linux:**
```bash
sudo sh -c 'echo "127.0.0.1 draw.local" >> /etc/hosts'
```

**Windows (run as Administrator):**
```powershell
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 draw.local"
```

**Verify it works:**
```bash
ping draw.local
# Should show: PING draw.local (127.0.0.1)
```

### SSL Certificates

SSL certificates are generated automatically by `just setup` or manually with:

```bash
just generate-certs
```

This creates a self-signed certificate valid for:
- `draw.local`
- `localhost`
- `127.0.0.1`

**Browser Warning:** Your browser will show a security warning for self-signed certificates. This is expected for local development.

To accept the certificate:
1. Open https://draw.local in your browser
2. Click "Advanced" → "Proceed to draw.local (unsafe)"
3. The warning won't appear again for this certificate

**Regenerating certificates:** If you need to regenerate (e.g., expired or wrong domain):
```bash
rm deploy/certs/server.crt deploy/certs/server.key
just generate-certs
```

## Troubleshooting

### "Bad Gateway" at https://draw.local

Check if all services are running:
```bash
just dev-status
```

If services are down, restart:
```bash
just dev-stop
just dev
```

### Port already in use

Stop existing processes:
```bash
just dev-stop
```

Or manually kill specific ports:
```bash
lsof -ti:3000 | xargs kill -9  # Frontend
lsof -ti:8080 | xargs kill -9  # Backend
lsof -ti:3002 | xargs kill -9  # Room
```

### Database migration errors

If you see migration errors, try:
```bash
cd backend && npx prisma migrate deploy
```

For a fresh database:
```bash
just fresh-infra  # Warning: deletes all data
just dev
```

### CSS changes not appearing

1. Check browser dev tools for errors
2. Try hard refresh: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)
3. Check terminal for Vite errors

### Authentication not working

Ensure you're accessing via `https://draw.local`, not `localhost:3000`. Cookies are domain-specific.

## Architecture

```
Browser (https://draw.local)
         │
         ▼
┌─────────────────┐
│    Traefik      │  (Docker - port 443)
│  Reverse Proxy  │
└────────┬────────┘
         │
    ┌────┴────┬─────────────┐
    │         │             │
    ▼         ▼             ▼
┌───────┐ ┌───────┐   ┌──────────┐
│Frontend│ │Backend│   │  Room    │
│ :3000  │ │ :8080 │   │  :3002   │
│ (Vite) │ │(Nest) │   │(Socket)  │
└───────┘ └───┬───┘   └──────────┘
              │
    ┌─────────┴─────────┐
    │                   │
    ▼                   ▼
┌─────────┐       ┌─────────┐
│PostgreSQL│       │  MinIO  │
│  :5432   │       │  :9000  │
└─────────┘       └─────────┘
```

## When to Use Docker Development

Only use `just up-dev` or `just fresh-dev` when:

1. **Testing Dockerfile changes** - Modified `frontend/Dockerfile` or `backend/Dockerfile`
2. **Testing entrypoint scripts** - Modified `docker-entrypoint.sh`
3. **Pre-release verification** - Ensuring Docker images work correctly
4. **Debugging production issues** - Reproducing issues that only occur in Docker

For all other development, use `just dev` for the best developer experience.

