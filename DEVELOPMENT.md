# Astradraw Development Summary

This document provides a complete summary of all modifications made to enable self-hosted Excalidraw with collaboration support. It's intended for AI assistants and developers to quickly understand the project.

## Project Overview

**Goal:** Self-host Excalidraw with real-time collaboration, using HTTP storage backend instead of Firebase, with PostgreSQL/MongoDB/S3 as the database.

**Architecture:**
```
┌─────────────────────────────────────────────────────────────────────┐
│                         Traefik Proxy (HTTPS)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐   │
│  │ /            │  │ /socket.io/  │  │ /api/v2/                 │   │
│  │ excalidraw   │  │ excalidraw-  │  │ excalidraw-storage-      │   │
│  │ (frontend)   │  │ room (WS)    │  │ backend (REST API)       │   │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                              │
                              ┌───────────────┴───────────────┐
                              │  PostgreSQL / MongoDB / S3    │
                              └───────────────────────────────┘
```

## Repository Structure

Astradraw is split into three separate repositories:

| Repo | URL | Purpose |
|------|-----|---------|
| `astradraw` | https://github.com/astrateam-net/astradraw | Deployment configuration (docker-compose, docs) |
| `astradraw-app` | https://github.com/astrateam-net/astradraw-app | Forked Excalidraw frontend with HTTP storage |
| `astradraw-storage` | https://github.com/astrateam-net/astradraw-storage | Storage backend with PostgreSQL/MongoDB/S3 support |

**Local Development Structure:**
```
astradraw/
├── excalidraw/                    # Clone of astradraw-app (optional for local dev)
├── excalidraw-storage-backend/    # Clone of astradraw-storage (optional for local dev)
├── docker-compose.yml             # Main deployment config
├── traefik-dynamic.yml            # Traefik TLS config
├── env.example                    # Environment template
├── secrets/                       # Docker secrets (gitignored)
├── certs/                         # TLS certificates (gitignored)
└── DEVELOPMENT.md                 # This file
```

**Production Deployment:**
- Uses pre-built images from GitHub Container Registry (GHCR)
- `ghcr.io/astrateam-net/astradraw-app:latest`
- `ghcr.io/astrateam-net/astradraw-storage:latest`
- `excalidraw/excalidraw-room:latest` (upstream)

To use local builds during development, uncomment the `build:` sections in docker-compose.yml.

---

## Modifications to excalidraw (Frontend)

### New Files Created

1. **`excalidraw-app/data/StorageBackend.ts`** - Interface for storage abstraction
   ```typescript
   export interface StorageBackend {
     isSaved(portal: Portal, elements: readonly ExcalidrawElement[]): boolean;
     saveToStorageBackend(portal: Portal, elements: readonly ExcalidrawElement[], appState: AppState): Promise<boolean>;
     loadFromStorageBackend(roomId: string, roomKey: string, socket: Socket | null): Promise<readonly ExcalidrawElement[] | null>;
     saveFilesToStorageBackend(params: { prefix: string; files: Map<FileId, BinaryFileData> }): Promise<{ savedFiles: Map<FileId, true>; erroredFiles: Map<FileId, true> }>;
     loadFilesFromStorageBackend(prefix: string, decryptionKey: string, filesIds: readonly FileId[]): Promise<{ loadedFiles: BinaryFileData[]; erroredFiles: Map<FileId, true> }>;
   }
   ```

2. **`excalidraw-app/data/httpStorage.ts`** - HTTP storage implementation
   - Implements `StorageBackend` interface
   - Uses `fetch()` to call `/api/v2/scenes`, `/api/v2/rooms`, `/api/v2/files`
   - Reads URL from `getEnv().VITE_APP_HTTP_STORAGE_BACKEND_URL`

3. **`excalidraw-app/data/config.ts`** - Storage backend selector
   ```typescript
   export async function getStorageBackend(): Promise<StorageBackend>
   export function isHttpStorageBackend(): boolean
   ```
   - Selects backend based on `VITE_APP_STORAGE_BACKEND` ("http" or "firebase")

4. **`excalidraw-app/env.ts`** - Runtime environment helper
   ```typescript
   export function getEnv(): ImportMetaEnv {
     if (window.__ENV__) return window.__ENV__;  // Runtime injected
     return import.meta.env;                      // Build-time baked
   }
   ```

5. **`docker-entrypoint.sh`** - Injects env vars at container startup
   - Creates `/usr/share/nginx/html/env-config.js` with `window.__ENV__`
   - Injects `<script src="/env-config.js">` into `index.html`

### Modified Files

1. **`excalidraw-app/collab/Collab.tsx`**
   - Replaced Firebase imports with `getStorageBackend()` calls
   - Changed socket URL to use `getEnv().VITE_APP_WS_SERVER_URL`
   - Renamed `fetchImageFilesFromFirebase` → `fetchImageFilesFromStorageBackend`

2. **`excalidraw-app/data/firebase.ts`**
   - Changed to use `getEnv().VITE_APP_FIREBASE_CONFIG`

3. **`excalidraw-app/App.tsx`**
   - Uses storage abstraction for file loading
   - Added `validateEmbeddable={true}` prop to allow any URL to be embedded

4. **`excalidraw-app/data/index.ts`**
   - Uses storage abstraction for file saving

5. **`excalidraw-app/vite-env.d.ts`**
   - Added new env var declarations:
     - `VITE_APP_STORAGE_BACKEND`
     - `VITE_APP_HTTP_STORAGE_BACKEND_URL`

6. **`excalidraw-app/package.json`**
   - Modified `build:app:docker` script to set placeholder env vars

7. **`Dockerfile`**
   - Removed HEALTHCHECK
   - Added `docker-entrypoint.sh` as ENTRYPOINT
   - Uses placeholder env vars during build

8. **`.dockerignore`**
   - Added `!docker-entrypoint.sh`

9. **`packages/element/src/embeddable.ts`**
   - Added domains to `ALLOW_SAME_ORIGIN` set for iframe sandbox permissions
   - Current additional domains: `kinescope.io`, `*.kinescopecdn.net`

### Iframe Embedding Support

Astradraw supports embedding any iframe URL via `validateEmbeddable={true}`.

**Implementation:**

Set `validateEmbeddable={true}` in `excalidraw-app/App.tsx` (line 819) - this allows ANY URL to be embedded without checking domain allowlists.

**How to add domains that need same-origin access:**

Some embeds (video players, interactive tools) need `allow-same-origin` in the iframe sandbox to function. For these, edit [`excalidraw/packages/element/src/embeddable.ts`](excalidraw/packages/element/src/embeddable.ts):

```typescript
// Line 106-118: Add domain here if it needs same-origin sandbox
const ALLOW_SAME_ORIGIN = new Set([
  "youtube.com",
  "youtu.be",
  "vimeo.com",
  // ... existing domains
  "your-video-platform.com",  // Add your domain here
]);
```

**When to add to `ALLOW_SAME_ORIGIN`:**
- ✅ Video players (Kinescope, Wistia, Vimeo, etc.) - need same-origin to control playback
- ✅ Interactive embeds (Figma, Miro, etc.) - need same-origin for user interaction
- ✅ Embeds using localStorage/cookies/iframes
- ❌ Static content (tweets, GitHub gists) - work fine with restricted sandbox

**Default sandbox (without same-origin):**
```
allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox allow-presentation allow-downloads
```

**With same-origin:**
```
allow-same-origin allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox allow-presentation allow-downloads
```

**Rebuild after changes:**
```bash
docker compose build app --no-cache
docker compose up -d app
```

### Environment Variables (Frontend)

| Variable | Description | Example |
|----------|-------------|---------|
| `VITE_APP_WS_SERVER_URL` | WebSocket server for collaboration | `wss://draw.example.com` |
| `VITE_APP_STORAGE_BACKEND` | Storage type | `http` or `firebase` |
| `VITE_APP_HTTP_STORAGE_BACKEND_URL` | Storage API base URL | `https://draw.example.com` |
| `VITE_APP_BACKEND_V2_GET_URL` | Scene GET endpoint | `https://draw.example.com/api/v2/scenes/` |
| `VITE_APP_BACKEND_V2_POST_URL` | Scene POST endpoint | `https://draw.example.com/api/v2/scenes/` |
| `VITE_APP_FIREBASE_CONFIG` | Firebase config (if using firebase backend) | `{}` |
| `VITE_APP_DISABLE_TRACKING` | Disable analytics | `true` |

---

## Modifications to excalidraw-storage-backend

### New Files Created

1. **`src/utils/secrets.ts`** - Docker secrets support
   ```typescript
   export function getSecret(name: string, defaultValue?: string): string | undefined
   export function getSecretOrThrow(name: string): string
   ```
   - Checks `VAR_FILE` env, reads file if exists
   - Falls back to `VAR` env, then default

### Modified Files

1. **`src/main.ts`**
   - Uses `getSecret()` for `PORT`, `LOG_LEVEL`, `GLOBAL_PREFIX`

2. **`src/storage/storage.service.ts`**
   - Uses `getSecret('STORAGE_URI')` instead of `process.env.STORAGE_URI`

3. **`Dockerfile`**
   - Changed `FROM node:20-alpine as builder` to `FROM node:20-alpine AS builder`

### Environment Variables (Storage Backend)

| Variable | Description | Supports `_FILE` |
|----------|-------------|------------------|
| `STORAGE_URI` | Keyv connection string | ✅ |
| `PORT` | Server port (default: 8080) | ✅ |
| `LOG_LEVEL` | Log level | ✅ |
| `GLOBAL_PREFIX` | API prefix (default: `/api/v2`) | ✅ |

**Supported databases via Keyv:**
- PostgreSQL: `postgres://user:pass@host:5432/db`
- MongoDB: `mongodb://user:pass@host:27017/db`
- Redis: `redis://user:pass@host:6379`
- MySQL: `mysql://user:pass@host:3306/db`
- In-memory: (empty string, non-persistent)

---

## Modifications to excalidraw-room

**No code changes.** Only the Dockerfile was updated:
- Changed `FROM node:12-alpine` to `FROM node:18-alpine`

Can be built directly from upstream with inline Dockerfile override.

---

## Docker Compose Configuration

Key services in `docker-compose.yml`:

```yaml
services:
  traefik:      # Reverse proxy with HTTPS
  app:          # Excalidraw frontend (astradraw-app)
  room:         # WebSocket server (upstream excalidraw-room)
  storage:      # Storage API (astradraw-storage)
  postgres:     # Database
```

**Traefik routing:**
- `/` → `app` (frontend)
- `/socket.io/` → `room` (WebSocket, requires sticky sessions)
- `/api/v2/` → `storage` (REST API)

**HTTPS requirement:** Web Crypto API (used for E2E encryption in collaboration) requires secure context. Use self-signed certs for local testing.

**Deployment Options:**

1. **Production (using GHCR images):**
   ```bash
   docker compose up -d
   ```

2. **Local Development (build from source):**
   ```bash
   # Clone the app and storage repos
   git clone git@github.com:astrateam-net/astradraw-app.git excalidraw
   git clone git@github.com:astrateam-net/astradraw-storage.git excalidraw-storage-backend
   
   # Uncomment build: sections in docker-compose.yml
   # Then build and run
   docker compose up -d --build
   ```

3. **Hybrid (some local, some GHCR):**
   Edit docker-compose.yml to mix `image:` and `build:` directives as needed.

---

## Key Design Decisions

1. **Runtime env injection** instead of build-time baking - allows single Docker image for multiple environments

2. **StorageBackend interface** - abstracts Firebase vs HTTP, easy to add new backends

3. **`_FILE` secrets pattern** - native support in app code, works with Docker Swarm/K8s secrets

4. **Traefik for routing** - single domain, path-based routing, handles WebSocket upgrades

5. **PostgreSQL preferred** over MongoDB - better tooling, ACID compliance, same Keyv interface

---

## Testing Collaboration

1. **HTTPS required** for cross-device testing (Web Crypto API)
2. Generate self-signed cert: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout certs/key.pem -out certs/cert.pem`
3. Accept cert warning in browsers
4. Share link with room key (encryption key is in URL hash, never sent to server)

---

## Future Work

- [ ] S3 storage support in `astradraw-storage`
- [x] ~~Extend iframe embeds beyond YouTube~~ ✅ **Completed** - Any URL can now be embedded
- [x] ~~Split into separate repos~~ ✅ **Completed** - Now using `astradraw-app`, `astradraw-storage`, `astradraw` repos

### Named Rooms with Shared Encryption Key

Allow users to create human-readable room URLs like `#room=project-kickoff` instead of random IDs.

**Design:**
- Add `VITE_APP_SHARED_ENCRYPTION_KEY` env var for server-wide shared key
- When creating a session, user can choose:
  - **Quick room** (default): Random ID + unique encryption key → `#room=a1b2c3,<unique-key>`
  - **Named room**: Custom name + shared key → `#room=my-project`
- When joining: If URL has no key, use shared key from config

**UI Changes:**
- Add radio buttons in "Start collaboration" modal
- Add text input for custom room name when "Named room" selected

### Path-Based Routing for Authentik Integration

Change from hash-based (`/#room=...`) to path-based (`/room/...`) routing to enable per-room access control via Authentik forward proxy.

**Current (hash-based):**
```
https://draw.example.com/#room=finance-budget
```
- Server sees: `GET /` (cannot distinguish rooms)
- Authentik cannot apply per-room policies

**Proposed (path-based):**
```
https://draw.example.com/room/finance/budget-2025
https://draw.example.com/room/hr/onboarding
https://draw.example.com/room/public/whiteboard
```
- Server sees full path
- Authentik can apply policies:
  - `/room/finance/*` → Finance AD group only
  - `/room/hr/*` → HR AD group only
  - `/room/public/*` → All authenticated users

**Implementation Required:**
1. React Router with path-based routes (replace hash routing)
2. Nginx config for SPA fallback (return `index.html` for `/room/*`)
3. Traefik routing updates
4. Support encryption key via query param: `/room/name?key=<key>`

**Benefits:**
- Granular access control per room/department
- Clean, shareable URLs
- Compatible with enterprise SSO policies

---

## Reference Repositories (Already Extracted, Can Be Removed)

These were used as references and are no longer needed:
- `excalidraw-collaboration/` - alswl's fork reference
- `excalidraw-self-hosted/` - Traefik config reference

