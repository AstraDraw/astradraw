# AstraDraw AI Agent Instructions

This file provides context for AI assistants working on the AstraDraw project.

## Project Overview

AstraDraw is a self-hosted fork of Excalidraw with enterprise features:
- User authentication (OIDC/local)
- Personal workspaces with scene management
- Video recordings (Talktrack)
- Presentation mode
- Custom pens
- GIPHY integration

## Repository Structure

```
astradraw/                    # Main orchestration repo
├── frontend/                 # React app (Excalidraw fork) - SEPARATE GIT REPO
├── backend/                  # NestJS API - SEPARATE GIT REPO
├── room-service/             # WebSocket server - SEPARATE GIT REPO
├── docs/                     # Feature documentation
├── deploy/                   # Docker Compose, configs, secrets, certs
│   ├── docker-compose.yml
│   ├── .env, env.example
│   ├── certs/, secrets/, libraries/
└── .cursor/rules/            # Detailed Cursor rules
```

**Important:** `frontend/`, `backend/`, and `room-service/` are separate git repositories. They are gitignored in the main repo.

## Key Technical Decisions

### Authentication
- JWT tokens stored in HTTP-only cookies
- OIDC support with internal URL for Docker networking
- Local auth with bcrypt password hashing

### Storage
- PostgreSQL for metadata (users, scenes, recordings)
- MinIO/S3 for binary data (scene content, files)
- Avatars stored as base64 data URLs in database

### Frontend Patterns
- Stop keyboard event propagation in input fields
- Use Jotai for shared state
- Always add translation keys to both en.json and ru-RU.json

### Backend Patterns
- JWT guard is at `auth/jwt.guard.ts` (not jwt-auth.guard.ts)
- Use Prisma for database operations
- File uploads require @types/multer

## Documentation

Read these docs before implementing features:

**Architecture & Setup:**
- `/CONTRIBUTING.md` - How to set up for development
- `/docs/ARCHITECTURE.md` - Technical architecture and design decisions
- `/docs/ROADMAP.md` - Planned features and specifications

**Feature Documentation:**
- `/docs/WORKSPACE.md` - Auth and scene management
- `/docs/USER_PROFILE.md` - Profile management
- `/docs/TALKTRACK.MD` - Video recordings
- `/docs/PRESENTATION_MODE.md` - Slideshow

## Common Commands (use Justfile)

**Always prefer `just` commands over writing full shell commands.**

```bash
# Code checks
just check-all           # Run ALL checks (frontend + backend + room)
just check-frontend      # TypeScript + Prettier + ESLint
just check-backend       # Build + Prettier + ESLint
just fix-all             # Auto-fix formatting issues

# Docker deployment - Production (GHCR images)
just up                  # Start with production images
just up-prod             # Force production (ignores override file)
just fresh               # Fresh start with production images
just pull                # Pull latest production images

# Docker deployment - Development (local builds)
just up-dev              # Start with local builds
just fresh-dev           # Fresh start with local builds
just build               # Build local images only

# Docker - Mode switching
just mode                # Show current mode (production/development)
just enable-dev          # Enable local builds
just disable-dev         # Use production images

# Docker - Common
just down                # Stop services
just restart             # Restart services
just logs-api            # View API logs

# Development
just dev-frontend        # Start frontend dev server
just dev-backend         # Start backend dev server
just install             # Install all dependencies

# Database
just db-migrate          # Run Prisma migrations
just db-studio           # Open Prisma Studio

# Git
just status              # Git status for all repos
just git-pull            # Pull latest from all repos

# Release
just release-frontend 0.18.0-beta0.XX
just release-backend 0.5.X
```

## Release Checklist

1. Create feature branches in affected repos
2. Implement changes
3. Run `just check-all`
4. Test with `just up-dev`
5. Merge to main in each repo
6. Update CHANGELOG.md in each repo
7. Run `just release-frontend X.X.X` / `just release-backend X.X.X`
8. Update `deploy/docker-compose.yml` with new image versions
9. Commit and push main repo

