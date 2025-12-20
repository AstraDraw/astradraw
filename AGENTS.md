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
├── docker-compose.yml        # Production deployment
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
- `/docs/WORKSPACE.md` - Auth and scene management
- `/docs/USER_PROFILE.md` - Profile management
- `/docs/TALKTRACK.MD` - Video recordings
- `/docs/PRESENTATION_MODE.md` - Slideshow
- `/docs/DEVELOPMENT.md` - Full technical docs

## Common Commands

```bash
# Frontend
cd frontend
yarn tsc --noEmit      # Type check
yarn prettier --write  # Format

# Backend
cd backend
npm run build          # Build
npm run prisma:generate # Generate Prisma client

# Docker
docker compose up -d --build  # Build and start
docker compose logs -f api    # View API logs
```

## Release Checklist

1. Update CHANGELOG.md in respective repo
2. Run local build to verify
3. Commit and tag (`git tag vX.X.X`)
4. Push with tags (`git push origin main --tags`)
5. Update docker-compose.yml with new image versions
6. Push main repo

