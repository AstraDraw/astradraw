# AstraDraw Architecture

This document describes the technical architecture of AstraDraw for developers and AI assistants.

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Traefik Proxy (HTTPS)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐   │
│  │ /            │  │ /socket.io/  │  │ /api/v2/                 │   │
│  │ Frontend     │  │ Room Server  │  │ Backend API              │   │
│  │ (React)      │  │ (WebSocket)  │  │ (NestJS)                 │   │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                              │
                              ┌───────────────┴───────────────┐
                              │  PostgreSQL / MinIO (S3)      │
                              └───────────────────────────────┘
```

## Components

### Frontend (`frontend/`)

React/Vite application forked from Excalidraw with AstraDraw-specific features.

**Key Modifications:**

| File | Purpose |
|------|---------|
| `excalidraw-app/data/StorageBackend.ts` | Storage abstraction interface |
| `excalidraw-app/data/httpStorage.ts` | HTTP storage implementation |
| `excalidraw-app/data/config.ts` | Storage backend selector |
| `excalidraw-app/env.ts` | Runtime environment helper |
| `docker-entrypoint.sh` | Injects env vars at container startup |

**Storage Abstraction:**

```typescript
export interface StorageBackend {
  isSaved(portal: Portal, elements: readonly ExcalidrawElement[]): boolean;
  saveToStorageBackend(portal: Portal, elements: readonly ExcalidrawElement[], appState: AppState): Promise<boolean>;
  loadFromStorageBackend(roomId: string, roomKey: string, socket: Socket | null): Promise<readonly ExcalidrawElement[] | null>;
  saveFilesToStorageBackend(params: { prefix: string; files: Map<FileId, BinaryFileData> }): Promise<{ savedFiles: Map<FileId, true>; erroredFiles: Map<FileId, true> }>;
  loadFilesFromStorageBackend(prefix: string, decryptionKey: string, filesIds: readonly FileId[]): Promise<{ loadedFiles: BinaryFileData[]; erroredFiles: Map<FileId, true> }>;
}
```

**Runtime Environment Injection:**

Instead of baking environment variables at build time, AstraDraw injects them at container startup:

```typescript
// env.ts
export function getEnv(): ImportMetaEnv {
  if (window.__ENV__) return window.__ENV__;  // Runtime injected
  return import.meta.env;                      // Build-time fallback
}
```

The `docker-entrypoint.sh` creates `/usr/share/nginx/html/env-config.js` with `window.__ENV__` and injects it into `index.html`.

### Backend (`backend/`)

NestJS API for authentication, workspace management, and storage.

**Storage Architecture:**

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

**Storage Interface:**

```typescript
export interface IStorageService {
  get(key: string, namespace: StorageNamespace): Promise<Buffer | null>;
  set(key: string, value: Buffer, namespace: StorageNamespace): Promise<boolean>;
  has(key: string, namespace: StorageNamespace): Promise<boolean>;
}
```

**Selection:** Set `STORAGE_BACKEND` environment variable:
- `s3` or `minio` → S3StorageService (recommended)
- `keyv` → KeyvStorageService (legacy)

**Docker Secrets Support:**

```typescript
// utils/secrets.ts
export function getSecret(name: string, defaultValue?: string): string | undefined
export function getSecretOrThrow(name: string): string
```

Checks `VAR_FILE` env, reads file if exists, falls back to `VAR` env.

### Room Service (`room-service/`)

Upstream Excalidraw Room server for WebSocket-based real-time collaboration.

**No code changes** - only Dockerfile updated to use Node 18.

## Database Schema

PostgreSQL is used for structured data (users, scenes, recordings).

**Core Tables:**

```prisma
model User {
  id            String    @id @default(uuid())
  email         String    @unique
  name          String
  passwordHash  String?   // null for SSO-only users
  oidcId        String?   @unique
  oidcProvider  String?
  avatarUrl     String?   @db.Text
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt
  scenes        Scene[]
  recordings    TalktrackRecording[]
}

model Scene {
  id          String    @id @default(uuid())
  name        String
  storageKey  String    @unique
  userId      String
  user        User      @relation(fields: [userId], references: [id])
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt
  recordings  TalktrackRecording[]
}

model TalktrackRecording {
  id              String    @id @default(uuid())
  name            String
  kinescopeId     String
  duration        Int?
  thumbnailUrl    String?
  sceneId         String
  scene           Scene     @relation(fields: [sceneId], references: [id])
  userId          String
  user            User      @relation(fields: [userId], references: [id])
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt
}
```

## Authentication

### JWT Flow

1. User logs in via local auth or OIDC
2. Backend issues JWT stored in HTTP-only cookie
3. Frontend includes cookie in all API requests (`credentials: "include"`)
4. JWT guard validates token on protected routes

### OIDC Integration

```typescript
// For Docker networking, use internal URL for discovery
const discoveryUrl = process.env.OIDC_INTERNAL_URL || process.env.OIDC_ISSUER_URL;

// Validate tokens against external issuer URL
const issuer = process.env.OIDC_ISSUER_URL;
```

**User Linking:**
1. Check by OIDC ID (existing SSO user)
2. Check by email (migration from local to SSO)
3. Create new user if neither found

## Traefik Routing

```yaml
# Path-based routing
- "traefik.http.routers.app.rule=Host(`${APP_DOMAIN}`)"
- "traefik.http.routers.room.rule=Host(`${APP_DOMAIN}`) && PathPrefix(`/socket.io`)"
- "traefik.http.routers.api.rule=Host(`${APP_DOMAIN}`) && PathPrefix(`/api`)"
```

**WebSocket Requirements:**
- Sticky sessions for Socket.io
- HTTPS required for Web Crypto API (collaboration encryption)

## Iframe Embedding

AstraDraw allows embedding any URL via `validateEmbeddable={true}`.

**Same-Origin Access:**

Some embeds need `allow-same-origin` in iframe sandbox. Add domains to `packages/element/src/embeddable.ts`:

```typescript
const ALLOW_SAME_ORIGIN = new Set([
  "youtube.com",
  "kinescope.io",
  // Add your domain here
]);
```

## Environment Variables

### Frontend

| Variable | Description |
|----------|-------------|
| `VITE_APP_WS_SERVER_URL` | WebSocket server URL |
| `VITE_APP_STORAGE_BACKEND` | `http` or `firebase` |
| `VITE_APP_HTTP_STORAGE_BACKEND_URL` | Storage API base URL |
| `VITE_APP_BACKEND_V2_GET_URL` | Scene GET endpoint |
| `VITE_APP_BACKEND_V2_POST_URL` | Scene POST endpoint |
| `VITE_APP_DISABLE_TRACKING` | Disable analytics |

### Backend

| Variable | Description | Supports `_FILE` |
|----------|-------------|------------------|
| `STORAGE_BACKEND` | `s3` or `keyv` | ❌ |
| `PORT` | Server port | ✅ |
| `JWT_SECRET` | JWT signing secret | ✅ |
| `S3_ENDPOINT` | S3/MinIO endpoint | ✅ |
| `S3_ACCESS_KEY` | S3 access key | ✅ |
| `S3_SECRET_KEY` | S3 secret key | ✅ |
| `S3_BUCKET` | S3 bucket name | ✅ |
| `DATABASE_URL` | PostgreSQL connection | ✅ |
| `OIDC_ISSUER_URL` | OIDC provider URL | ❌ |
| `OIDC_INTERNAL_URL` | Internal OIDC URL (Docker) | ❌ |
| `OIDC_CLIENT_ID` | OIDC client ID | ❌ |
| `OIDC_CLIENT_SECRET` | OIDC client secret | ✅ |

## Key Design Decisions

1. **Runtime env injection** - Single Docker image works in multiple environments
2. **StorageBackend interface** - Easy to swap Firebase for HTTP storage
3. **`_FILE` secrets pattern** - Works with Docker Swarm/Kubernetes secrets
4. **Traefik for routing** - Single domain, path-based routing, WebSocket support
5. **PostgreSQL over MongoDB** - Better tooling, ACID compliance
6. **JWT in HTTP-only cookies** - Secure, automatic inclusion in requests
7. **Avatars as base64 data URLs** - Simpler than separate file storage for small images

## Testing Collaboration

1. HTTPS is required (Web Crypto API needs secure context)
2. Generate self-signed cert for local testing
3. Accept cert warning in browsers
4. Share link with room key (encryption key is in URL hash, never sent to server)

## Related Documentation

- [Workspace & Auth](./WORKSPACE.md) - Authentication and scene management
- [Talktrack](./TALKTRACK.MD) - Video recording feature
- [Presentation Mode](./PRESENTATION_MODE.md) - Slideshow functionality
- [User Profile](./USER_PROFILE.md) - Profile management
- [Future Work](./ROADMAP.md) - Planned features and specs

