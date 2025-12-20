---
description: "AstraDraw project overview - architecture, folder structure, and key concepts"
alwaysApply: true
---

# AstraDraw Project Overview

AstraDraw is a self-hosted fork of Excalidraw with enterprise features. This rule provides essential context for understanding the project.

## Repository Structure

```
astradraw/                    # Main orchestration repo
├── frontend/                 # React app (Excalidraw fork) - SEPARATE GIT REPO
├── backend/                  # NestJS API - SEPARATE GIT REPO
├── room-service/             # WebSocket server - SEPARATE GIT REPO
├── docs/                     # Feature documentation
├── deploy/                   # Docker Compose, configs, secrets
│   ├── docker-compose.yml
│   ├── .env, certs/, secrets/
│   └── libraries/
└── .cursor/rules/            # AI assistant rules
```

| Folder | Description | Tech Stack |
|--------|-------------|------------|
| `frontend/` | Excalidraw fork with AstraDraw features | React, Vite, TypeScript, Jotai |
| `backend/` | NestJS API for auth, workspace, storage | NestJS, Prisma, PostgreSQL |
| `room-service/` | WebSocket collaboration server | Node.js, Socket.io |
| `deploy/` | All files needed to run/test the app | Docker Compose, Traefik |
| `docs/` | Feature documentation | Markdown |

**Important:** `frontend/`, `backend/`, `room-service/` are separate git repositories. Do NOT commit changes to the parent astradraw repo that include these folders.

## Architecture

```
Traefik (HTTPS) → Routes to:
  /           → frontend (React app, port 80)
  /socket.io  → room-service (WebSocket, port 80)
  /api/v2/*   → backend (NestJS, port 8080)

Backend connects to:
  - PostgreSQL (users, scenes, metadata via Prisma)
  - MinIO/S3 (scene data, files, rooms)
  - Kinescope API (video hosting for Talktrack)
```

## Key Features

1. **Workspace** - User accounts, scene management, auto-save
2. **Talktrack** - Video recordings with camera PIP, stored per-scene
3. **Presentation Mode** - Frames as slides with laser pointer
4. **Custom Pens** - Highlighter, fountain, marker presets
5. **Stickers & GIFs** - GIPHY integration
6. **Libraries** - Pre-bundled shape collections

## Documentation

All features are documented in `/docs`:
- `WORKSPACE.md` - Authentication and scene management
- `USER_PROFILE.md` - Profile management
- `TALKTRACK.MD` - Video recording feature
- `PRESENTATION_MODE.md` - Slideshow functionality
- `PENS_IMPLEMENTATION.md` - Custom pen presets
- `GIPHY_SUPPORT.md` - Stickers & GIFs
- `LIBRARIES_SYSTEM.md` - Shape library system
- `DEVELOPMENT.md` - Full technical documentation

**Always read relevant docs before implementing features.**
