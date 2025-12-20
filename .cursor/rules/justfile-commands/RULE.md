---
description: "Use Justfile commands instead of writing full shell commands"
alwaysApply: true
---

# Justfile Commands

This project uses [just](https://github.com/casey/just) for common commands. **Always prefer `just` commands over writing full shell commands.**

## Quick Reference

### Docker

| Command | Description |
|---------|-------------|
| `just up` | Start services (production images) |
| `just up-dev` | Start with local builds |
| `just down` | Stop services |
| `just restart` | Restart services |
| `just fresh` | Fresh start (removes volumes) |
| `just logs` | View all logs |
| `just logs-api` | View API logs |
| `just logs-app` | View frontend logs |
| `just up-oidc` | Start with Dex OIDC |
| `just up-admin` | Start with pgAdmin/MinIO Console |

### Code Checks

| Command | Description |
|---------|-------------|
| `just check-all` | Run ALL checks (frontend + backend + room) |
| `just check-frontend` | TypeScript + Prettier + ESLint |
| `just check-backend` | Build + Prettier + ESLint |
| `just check-room` | Build + Prettier + ESLint |
| `just fix-all` | Auto-fix formatting issues |

### Development

| Command | Description |
|---------|-------------|
| `just dev-frontend` | Start frontend dev server |
| `just dev-backend` | Start backend dev server |
| `just install` | Install all dependencies |

### Database

| Command | Description |
|---------|-------------|
| `just db-migrate` | Run Prisma migrations |
| `just db-generate` | Generate Prisma client |
| `just db-studio` | Open Prisma Studio |

### Git

| Command | Description |
|---------|-------------|
| `just status` | Git status for all repos |
| `just pull` | Pull latest from all repos |

### Setup

| Command | Description |
|---------|-------------|
| `just setup` | Full setup for new developers |

### Release

| Command | Description |
|---------|-------------|
| `just release-frontend 0.18.0-beta0.37` | Tag and push frontend |
| `just release-backend 0.5.3` | Tag and push backend |
| `just release-room 1.0.1` | Tag and push room service |

## AI Usage Guidelines

1. **For deployment testing**: Use `just up-dev` instead of `cd deploy && docker compose up -d --build`
2. **For checking code**: Use `just check-all` instead of running individual commands
3. **For viewing logs**: Use `just logs-api` instead of `cd deploy && docker compose logs -f api`
4. **For fresh start**: Use `just fresh` instead of manually removing volumes

## Example AI Responses

❌ **Bad** (verbose):
```
Let me run the checks:
cd frontend && yarn test:typecheck && yarn test:other && yarn test:code
cd backend && npm run build && npm run format && npm run lint
```

✅ **Good** (concise):
```
Let me run the checks:
just check-all
```

❌ **Bad**:
```
cd deploy && docker compose down -v
docker volume rm astradraw_postgres_data astradraw_minio_data
cd deploy && docker compose up -d
```

✅ **Good**:
```
just fresh
```

