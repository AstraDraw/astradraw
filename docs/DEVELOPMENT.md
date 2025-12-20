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

### Storage Architecture

The storage backend supports two pluggable storage implementations:

```
┌─────────────────────────────────────────────────────────────┐
│                    Controllers                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Scenes    │  │    Rooms    │  │    Files    │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
│         │                │                │                  │
│         └────────────────┼────────────────┘                  │
│                          ▼                                   │
│              ┌───────────────────────┐                       │
│              │   IStorageService     │ ← Interface           │
│              └───────────┬───────────┘                       │
│         ┌────────────────┴────────────────┐                  │
│         ▼                                 ▼                  │
│  ┌──────────────┐                  ┌──────────────┐         │
│  │ KeyvStorage  │                  │  S3Storage   │         │
│  │  Service     │                  │   Service    │         │
│  └──────┬───────┘                  └──────┬───────┘         │
│         ▼                                 ▼                  │
│  ┌──────────────┐                  ┌──────────────┐         │
│  │  PostgreSQL  │                  │    MinIO     │         │
│  │   MongoDB    │                  │   AWS S3     │         │
│  │    Redis     │                  │              │         │
│  └──────────────┘                  └──────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

**Selection:** Set `STORAGE_BACKEND` environment variable:
- `s3` or `minio` → S3StorageService (recommended for blob storage)
- `keyv` → KeyvStorageService (legacy, for PostgreSQL/MongoDB)

### New Files Created

1. **`src/utils/secrets.ts`** - Docker secrets support
   ```typescript
   export function getSecret(name: string, defaultValue?: string): string | undefined
   export function getSecretOrThrow(name: string): string
   ```
   - Checks `VAR_FILE` env, reads file if exists
   - Falls back to `VAR` env, then default

2. **`src/storage/storage.interface.ts`** - Storage abstraction interface
   ```typescript
   export interface IStorageService {
     get(key: string, namespace: StorageNamespace): Promise<Buffer | null>;
     set(key: string, value: Buffer, namespace: StorageNamespace): Promise<boolean>;
     has(key: string, namespace: StorageNamespace): Promise<boolean>;
   }
   ```

3. **`src/storage/s3-storage.service.ts`** - S3/MinIO implementation
   - Uses `@aws-sdk/client-s3`
   - Auto-creates bucket on startup
   - Maps namespaces to prefixes: `scenes/{id}`, `rooms/{id}`, `files/{id}`

4. **`src/storage/keyv-storage.service.ts`** - Keyv implementation (refactored)
   - Supports PostgreSQL, MongoDB, Redis, MySQL, SQLite
   - Uses Keyv library with namespace separation

5. **`src/storage/storage.module.ts`** - Dynamic provider factory
   - Selects implementation based on `STORAGE_BACKEND` env var
   - Global module, provides `STORAGE_SERVICE` token

### Modified Files

1. **`src/main.ts`**
   - Uses `getSecret()` for `PORT`, `LOG_LEVEL`, `GLOBAL_PREFIX`

2. **`src/app.module.ts`**
   - Imports `StorageModule` instead of direct `StorageService`

3. **`src/scenes/scenes.controller.ts`**, **`src/rooms/rooms.controller.ts`**, **`src/files/files.controller.ts`**
   - Use `@Inject(STORAGE_SERVICE)` for dependency injection
   - Import from `storage.interface.ts`

4. **`Dockerfile`**
   - Changed `FROM node:20-alpine as builder` to `FROM node:20-alpine AS builder`

5. **`package.json`**
   - Added `@aws-sdk/client-s3` dependency

### Environment Variables (Storage Backend)

**Common:**

| Variable | Description | Supports `_FILE` |
|----------|-------------|------------------|
| `STORAGE_BACKEND` | Storage type: `s3` or `keyv` | ❌ |
| `PORT` | Server port (default: 8080) | ✅ |
| `LOG_LEVEL` | Log level | ✅ |
| `GLOBAL_PREFIX` | API prefix (default: `/api/v2`) | ✅ |

**S3/MinIO (when `STORAGE_BACKEND=s3`):**

| Variable | Description | Supports `_FILE` |
|----------|-------------|------------------|
| `S3_ENDPOINT` | S3 endpoint URL (e.g., `http://minio:9000`) | ✅ |
| `S3_ACCESS_KEY` | Access key ID | ✅ |
| `S3_SECRET_KEY` | Secret access key | ✅ |
| `S3_BUCKET` | Bucket name (default: `excalidraw`) | ✅ |
| `S3_REGION` | Region (default: `us-east-1`) | ✅ |
| `S3_FORCE_PATH_STYLE` | Use path-style URLs (default: `true`) | ✅ |

**Keyv (when `STORAGE_BACKEND=keyv`):**

| Variable | Description | Supports `_FILE` |
|----------|-------------|------------------|
| `STORAGE_URI` | Keyv connection string | ✅ |

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
  minio:        # S3-compatible object storage (recommended)
  postgres:     # Database (for future comments system)
```

**Traefik routing:**
- `/` → `app` (frontend)
- `/socket.io/` → `room` (WebSocket, requires sticky sessions)
- `/api/v2/` → `storage` (REST API)

**HTTPS requirement:** Web Crypto API (used for E2E encryption in collaboration) requires secure context. Use self-signed certs for local testing.

**Deployment Options:**

1. **Production (using GHCR images):**
   ```bash
   # Create secrets
   mkdir -p secrets
   echo "minioadmin" > secrets/minio_access_key
   openssl rand -base64 32 > secrets/minio_secret_key
   
   # Copy and configure .env
   cp env.example .env
   
   # Start services
   docker compose up -d
   ```

2. **Local Development (using docker-compose.override.yml):**
   ```bash
   # Clone the app and storage repos
   git clone git@github.com:astrateam-net/astradraw-app.git excalidraw
   git clone git@github.com:astrateam-net/astradraw-storage.git excalidraw-storage-backend
   
   # The docker-compose.override.yml automatically builds from local source
   # Build and run
   docker compose up -d --build
   ```

3. **Admin tools (pgAdmin, MinIO Console):**
   ```bash
   docker compose --profile admin up -d
   ```
   - pgAdmin: `https://db.${APP_DOMAIN}`
   - MinIO Console: `https://s3.${APP_DOMAIN}`

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

- [x] ~~S3 storage support in `astradraw-storage`~~ ✅ **Completed** - MinIO/S3 backend with `@aws-sdk/client-s3`
- [x] ~~Extend iframe embeds beyond YouTube~~ ✅ **Completed** - Any URL can now be embedded
- [x] ~~Split into separate repos~~ ✅ **Completed** - Now using `astradraw-app`, `astradraw-storage`, `astradraw` repos
- [ ] Comments system (see detailed spec below)
- [ ] Named rooms with shared encryption key
- [ ] Path-based routing for Authentik integration

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

### Comments System

Add full commenting functionality similar to Excalidraw+ but self-hosted. Based on analysis of Excalidraw+ UI.

**Reference Screenshot Features:**
- User avatars in header showing online collaborators
- Comment markers on canvas (orange circles with avatars)
- Popup thread view when clicking a marker
- Sidebar with all comments, search, sort, and filter
- Threaded replies with @mentions
- Read/unread tracking
- Resolve/unresolve comments

**Current State:**
- UI placeholder already exists in `excalidraw-app/components/AppSidebar.tsx`
- Comments tab with `messageCircleIcon` is present but shows promo for Excalidraw+
- No backend support for comments

**Prerequisites:**
- SSO/Authentication (Authentik, Keycloak, or similar OIDC provider)
- PostgreSQL for structured data (comments require queries, unlike blob storage)
- WebSocket support for real-time updates (can extend excalidraw-room or separate service)

---

#### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Traefik Proxy (HTTPS)                       │
│                              + Authentik                            │
└─────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌──────────────┐          ┌──────────────┐          ┌──────────────┐
│   Frontend   │          │   Storage    │          │   Comments   │
│  (React)     │          │   Backend    │          │   Backend    │
│              │          │  (NestJS)    │          │  (NestJS)    │
└──────────────┘          └──────────────┘          └──────────────┘
        │                         │                         │
        │ WebSocket               │                         │
        ▼                         ▼                         ▼
┌──────────────┐          ┌──────────────┐          ┌──────────────┐
│  Presence    │          │    MinIO     │          │  PostgreSQL  │
│  Service     │          │    (S3)      │          │   (users,    │
│  (Socket.io) │          │  scenes,     │          │   comments,  │
└──────────────┘          │  rooms,      │          │   presence)  │
                          │  files       │          └──────────────┘
                          └──────────────┘
```

---

#### Database Schema (PostgreSQL)

```sql
-- ============================================
-- USERS
-- ============================================
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id VARCHAR UNIQUE NOT NULL,  -- ID from SSO provider (sub claim)
  email VARCHAR UNIQUE,
  name VARCHAR NOT NULL,
  avatar_url VARCHAR,
  color VARCHAR(7),                     -- User's cursor/avatar color (#RRGGBB)
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- COMMENTS
-- ============================================
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id VARCHAR NOT NULL,             -- Room where comment was made
  element_id VARCHAR,                   -- Optional: attached to specific element
  parent_id UUID REFERENCES comments(id) ON DELETE CASCADE, -- For threaded replies
  author_id UUID NOT NULL REFERENCES users(id),
  text TEXT NOT NULL,
  
  -- Position on canvas (for root comments only, NULL for replies)
  position_x FLOAT,
  position_y FLOAT,
  
  -- Resolution status
  resolved BOOLEAN DEFAULT FALSE,
  resolved_by UUID REFERENCES users(id),
  resolved_at TIMESTAMP,
  
  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_comments_room ON comments(room_id);
CREATE INDEX idx_comments_parent ON comments(parent_id);
CREATE INDEX idx_comments_element ON comments(element_id);
CREATE INDEX idx_comments_resolved ON comments(room_id, resolved);

-- ============================================
-- COMMENT READ STATUS (for read/unread tracking)
-- ============================================
CREATE TABLE comment_reads (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  read_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (user_id, comment_id)
);

-- ============================================
-- COMMENT MENTIONS (@username references)
-- ============================================
CREATE TABLE comment_mentions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  mentioned_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  notified BOOLEAN DEFAULT FALSE,       -- Whether notification was sent
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_mentions_user ON comment_mentions(mentioned_user_id);
CREATE INDEX idx_mentions_comment ON comment_mentions(comment_id);

-- ============================================
-- ROOM PRESENCE (who is currently online)
-- ============================================
CREATE TABLE room_presence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id VARCHAR NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  socket_id VARCHAR NOT NULL,           -- Socket.io connection ID
  cursor_x FLOAT,                       -- Current cursor position
  cursor_y FLOAT,
  last_seen TIMESTAMP DEFAULT NOW(),
  connected_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(room_id, user_id, socket_id)
);

CREATE INDEX idx_presence_room ON room_presence(room_id);
CREATE INDEX idx_presence_last_seen ON room_presence(last_seen);

-- Cleanup stale presence records (run periodically)
-- DELETE FROM room_presence WHERE last_seen < NOW() - INTERVAL '5 minutes';
```

---

#### Backend API Endpoints

```
# ============================================
# COMMENTS CRUD
# ============================================
GET    /api/v2/rooms/:roomId/comments
       Query params:
         - resolved: boolean (filter by resolved status)
         - sort: "date" | "unread" (default: date)
         - search: string (full-text search in comment text)
       Response: { comments: Comment[], unreadCount: number }

POST   /api/v2/rooms/:roomId/comments
       Body: { text, elementId?, positionX?, positionY?, parentId? }
       Response: { comment: Comment }
       Side effects: Parse @mentions, create mention records

GET    /api/v2/comments/:id
       Response: { comment: Comment, replies: Comment[], viewers: User[] }

PUT    /api/v2/comments/:id
       Body: { text }
       Auth: Only author can edit
       Response: { comment: Comment }

DELETE /api/v2/comments/:id
       Auth: Only author can delete
       Response: { success: true }

# ============================================
# COMMENT ACTIONS
# ============================================
POST   /api/v2/comments/:id/resolve
       Response: { comment: Comment }

POST   /api/v2/comments/:id/unresolve
       Response: { comment: Comment }

POST   /api/v2/comments/:id/read
       Mark comment as read for current user
       Response: { success: true }

POST   /api/v2/rooms/:roomId/comments/read-all
       Mark all comments in room as read
       Response: { success: true, count: number }

GET    /api/v2/comments/:id/link
       Generate shareable deep link to comment
       Response: { url: "https://draw.example.com/room/x?comment=uuid" }

# ============================================
# PRESENCE (Online Users)
# ============================================
GET    /api/v2/rooms/:roomId/presence
       Response: { users: User[], count: number }

# WebSocket events (via Socket.io):
#   - user:join    { userId, name, avatar, color }
#   - user:leave   { userId }
#   - user:cursor  { userId, x, y }
#   - comment:new  { comment }
#   - comment:update { comment }
#   - comment:delete { commentId }
#   - comment:resolve { commentId, resolvedBy }

# ============================================
# USERS
# ============================================
GET    /api/v2/users/me
       Response: { user: User }

GET    /api/v2/users/search?q=<query>
       For @mention autocomplete
       Response: { users: User[] }

PUT    /api/v2/users/me
       Body: { name?, avatarUrl?, color? }
       Response: { user: User }
```

---

#### Feature Specifications

##### 1. Online Users / Presence System

**How it works:**
- When user connects to room via WebSocket, add to `room_presence` table
- Broadcast `user:join` event to all users in room
- Show avatars in top-right header (like Excalidraw+ shows Shogun, TheSnake, TheChief, etc.)
- Update cursor position in real-time
- On disconnect, remove from presence and broadcast `user:leave`
- Periodic heartbeat to detect stale connections

**UI Components:**
- `PresenceAvatars.tsx` - Row of user avatars in header
- `UserCursor.tsx` - Colored cursor with username label on canvas
- Click on avatar → show user card with name, email

**Data flow:**
```
User joins room
    → WebSocket connect
    → INSERT INTO room_presence
    → Broadcast user:join to room
    → Other clients add avatar to header

User moves cursor
    → Throttled WebSocket event (50ms)
    → UPDATE room_presence SET cursor_x, cursor_y
    → Broadcast to room (except sender)
    → Other clients update cursor position

User disconnects
    → WebSocket disconnect event
    → DELETE FROM room_presence
    → Broadcast user:leave
    → Other clients remove avatar
```

##### 2. Comment Markers on Canvas

**How it works:**
- Render overlay layer above canvas but below UI
- Each root comment (not a reply) has a marker at (position_x, position_y)
- Marker shows author's avatar in a colored circle
- Click marker → open popup with full thread
- Drag marker to reposition comment

**UI Components:**
- `CommentMarkerLayer.tsx` - Overlay container
- `CommentMarker.tsx` - Single marker (avatar + count badge)
- `CommentPopup.tsx` - Floating popup with thread

**Marker states:**
- Default: Small avatar circle
- Hover: Expand slightly, show "3 replies" count
- Active: Full popup open
- Resolved: Grayed out or hidden (based on filter)

**Adding new comment:**
1. User clicks "Add comment" tool in toolbar
2. Click on canvas → create marker at position
3. Popup opens with empty text field
4. Submit → POST to API → marker becomes permanent

##### 3. Comment Thread Popup

**Layout (based on screenshot):**
```
┌─────────────────────────────────────────────┐
│  < >  [Navigate]     ✓ ✏ 🗑  ✕ [Close]      │
├─────────────────────────────────────────────┤
│  👤 Butterbean • a day ago            ⋮     │
│  Excalidraw's hand-drawn charm infuses...   │
├─────────────────────────────────────────────┤
│    👤 Tony • 30min ago                ⋮     │
│    The color palette chosen for...          │
│                        [Copy link] [Remove] │
├─────────────────────────────────────────────┤
│    👤 Smokin • 5min ago                     │
│    The seamless integration of...           │
├─────────────────────────────────────────────┤
│  👤 [Reply, @mention someone...]      ↑     │
└─────────────────────────────────────────────┘
```

**Features:**
- `< >` Navigation between comments (prev/next by date)
- `✓` Resolve button (marks thread as resolved)
- `✏` Edit button (only for own comments)
- `🗑` Delete button (only for own comments)
- `✕` Close popup
- `⋮` Menu: Copy link, Remove (for own), Report
- Reply input with @mention support

##### 4. Sidebar Comments Panel

**Layout (based on screenshot):**
```
┌─────────────────────────────────────────────┐
│  🔍 Quick search                      ⌘3    │
├─────────────────────────────────────────────┤
│                         ✓ Mark all as read  │
│  ↕ Sort by date                             │
│  ↕ Sort by unread                           │
│  Show resolved comments  [○────]            │
├─────────────────────────────────────────────┤
│  👤 TheChief • a moment ago                 │
│  The seamless integration of Excalidraw's   │
│  hand-drawn feeling enhances the design's   │
│  visual storytelling...                     │
│  👥👥👥 +99 users    3 replies              │
├─────────────────────────────────────────────┤
│  👤 milos • a moment ago                    │
│  Excalidraw's hand-drawn aesthetics inject  │
│  a sense of playfulness and warmth...       │
│  👥👥👥 +99 users    3 replies              │
├─────────────────────────────────────────────┤
│  ... more comments ...                      │
└─────────────────────────────────────────────┘
```

**Features:**
- **Quick search**: Filter comments by text content
- **Sort options**:
  - By date (newest first)
  - By unread (unread first, then by date)
- **Show resolved toggle**: Hide/show resolved comments
- **Mark all as read**: Bulk action
- **Comment preview**: Shows first ~100 chars of text
- **Viewers count**: "+99 users" who viewed the comment
- **Reply count**: "3 replies" badge
- **Click to navigate**: Click comment → scroll canvas to marker position

##### 5. @Mentions System

**How it works:**
1. User types `@` in comment input
2. Dropdown appears with user search results
3. As user types, filter by name/email
4. Select user → insert `@username` into text
5. On submit:
   - Parse text for `@username` patterns
   - Create records in `comment_mentions` table
   - (Future) Send notification to mentioned users

**UI Components:**
- `MentionInput.tsx` - Text input with mention detection
- `MentionDropdown.tsx` - User search/select dropdown
- `MentionBadge.tsx` - Styled @username in rendered text

**Storage:**
- Store raw text with `@username` markers
- On render, replace with styled badges
- `comment_mentions` table tracks who was mentioned for notifications

##### 6. Read/Unread Tracking

**How it works:**
- When user opens a comment thread, mark as read
- Track in `comment_reads` table (user_id, comment_id, read_at)
- Show unread indicator (dot or bold text) in sidebar
- "Mark all as read" creates records for all unread comments

**Unread detection:**
```sql
-- Get unread comments for user in room
SELECT c.* FROM comments c
WHERE c.room_id = :roomId
  AND c.id NOT IN (
    SELECT comment_id FROM comment_reads WHERE user_id = :userId
  )
ORDER BY c.created_at DESC;
```

**UI indicators:**
- Blue dot next to unread comments in sidebar
- Bold text for unread comment titles
- Unread count badge on Comments tab icon

##### 7. Copy Link to Comment

**How it works:**
- Each comment has a unique URL
- Format: `https://draw.example.com/room/:roomId?comment=:commentId`
- When opening URL with `?comment=` param:
  1. Load room
  2. Scroll canvas to comment position
  3. Open comment popup

**Implementation:**
- Add `commentId` query param handling to room initialization
- Generate link via API or client-side
- Copy to clipboard with visual feedback

---

#### Frontend File Structure

```
excalidraw-app/
├── comments/
│   ├── CommentsPanel.tsx         # Sidebar panel with all comments
│   ├── CommentThread.tsx         # Single thread (root + replies)
│   ├── CommentPopup.tsx          # Floating popup on canvas
│   ├── CommentMarkerLayer.tsx    # Canvas overlay with markers
│   ├── CommentMarker.tsx         # Individual marker component
│   ├── CommentForm.tsx           # Create/edit form
│   ├── CommentActions.tsx        # Resolve, edit, delete buttons
│   ├── MentionInput.tsx          # Input with @mention support
│   ├── MentionDropdown.tsx       # User search dropdown
│   ├── CommentsContext.tsx       # React context for state
│   ├── commentsApi.ts            # API client functions
│   ├── commentsSocket.ts         # WebSocket event handlers
│   └── types.ts                  # TypeScript interfaces
├── presence/
│   ├── PresenceAvatars.tsx       # Online users in header
│   ├── UserCursor.tsx            # Cursor on canvas
│   ├── PresenceContext.tsx       # Presence state management
│   └── presenceSocket.ts         # WebSocket handlers
└── auth/
    ├── AuthContext.tsx           # Current user context
    ├── useAuth.ts                # Auth hook
    └── authApi.ts                # Auth API client
```

---

#### Environment Variables

| Variable | Description |
|----------|-------------|
| `VITE_APP_COMMENTS_ENABLED` | Enable comments feature (`true`/`false`) |
| `VITE_APP_AUTH_ENABLED` | Require authentication (`true`/`false`) |
| `VITE_APP_OIDC_ISSUER` | OIDC provider URL (e.g., Authentik) |
| `VITE_APP_OIDC_CLIENT_ID` | OIDC client ID |
| `VITE_APP_OIDC_SCOPES` | OIDC scopes (default: `openid profile email`) |
| `VITE_APP_PRESENCE_ENABLED` | Enable presence/cursors (`true`/`false`) |

---

#### Implementation Phases

**Phase 1: Authentication & Users (Week 1)**
- [ ] Integrate Authentik with Traefik forward-auth
- [ ] Add JWT validation middleware to storage backend
- [ ] Create users table, sync on first SSO login
- [ ] Add `/api/v2/users/me` endpoint
- [ ] Frontend: Add AuthContext, redirect to login if needed

**Phase 2: Presence System (Week 1-2)**
- [ ] Add presence table and cleanup job
- [ ] Extend excalidraw-room with presence events
- [ ] Frontend: PresenceAvatars component in header
- [ ] Frontend: UserCursor component on canvas

**Phase 3: Comments Backend (Week 2)**
- [ ] Add comments, comment_reads, comment_mentions tables
- [ ] Implement CRUD endpoints
- [ ] Add authorization (author-only edit/delete)
- [ ] Add WebSocket events for real-time updates

**Phase 4: Comments Frontend - Sidebar (Week 2-3)**
- [ ] Replace promo in AppSidebar with CommentsPanel
- [ ] Implement comment list with search/sort/filter
- [ ] Add read/unread tracking UI
- [ ] Add "Mark all as read" action

**Phase 5: Comments Frontend - Canvas (Week 3)**
- [ ] CommentMarkerLayer overlay
- [ ] CommentMarker with avatar
- [ ] CommentPopup with thread view
- [ ] Navigation between comments

**Phase 6: @Mentions & Polish (Week 3-4)**
- [ ] MentionInput with autocomplete
- [ ] Parse and store mentions
- [ ] Copy link to comment
- [ ] Deep link handling (?comment=id)
- [ ] UI polish, animations, error handling

---

#### Complexity Estimate (Updated)

| Component | Effort |
|-----------|--------|
| SSO Integration (Authentik) | 2-3 days |
| Presence System (backend + frontend) | 3-4 days |
| Comments Backend API | 3-4 days |
| Comments Sidebar UI | 3-4 days |
| Comment Markers & Popup | 4-5 days |
| @Mentions System | 2-3 days |
| Read/Unread Tracking | 1-2 days |
| Deep Links & Polish | 2-3 days |
| **Total** | **~4-5 weeks** |

---

## Reference Repositories (Already Extracted, Can Be Removed)

These were used as references and are no longer needed:
- `excalidraw-collaboration/` - alswl's fork reference
- `excalidraw-self-hosted/` - Traefik config reference

