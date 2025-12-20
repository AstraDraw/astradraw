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
- `/docs/WORKSPACE.md` - Auth and scene management
- `/docs/USER_PROFILE.md` - Profile management
- `/docs/TALKTRACK.MD` - Video recordings
- `/docs/PRESENTATION_MODE.md` - Slideshow
- `/docs/DEVELOPMENT.md` - Full technical docs

## Common Commands

```bash
# Frontend checks (run before release)
cd frontend
yarn test:typecheck    # TypeScript type checking
yarn test:other        # Prettier formatting
yarn test:code         # ESLint code quality
yarn test:all          # All checks + tests

# Backend checks (run before release)
cd backend
npm run build          # Build (includes TypeScript)
npm run format         # Prettier formatting
npm run lint           # ESLint code quality

# Docker (from deploy/ folder)
cd deploy
docker compose up -d --build  # Build and start
docker compose logs -f api    # View API logs
```

## Release Checklist

1. Create feature branches in affected repos
2. Implement changes
3. Run all checks (see commands above)
4. Test with Docker deployment
5. Merge to main in each repo
6. Update CHANGELOG.md in each repo
7. Tag and push (`git tag vX.X.X && git push origin main --tags`)
8. Update `deploy/docker-compose.yml` with new image versions
9. Commit and push main repo

