# AstraDraw Collaboration System

This document describes the real-time collaboration system in AstraDraw, including how it integrates with workspaces, teams, collections, and user profiles.

## Overview

AstraDraw supports two collaboration modes:

| Mode | Description | Authentication | Use Case |
|------|-------------|----------------|----------|
| **Workspace Collaboration** | Permission-based, tied to scenes in shared workspaces | Required | Team collaboration |
| **Legacy Anonymous Mode** | Link-based, no authentication | Not required | Quick sharing, backward compatibility |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Frontend (React)                               │
│                                                                         │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐  │
│  │   AuthContext    │───►│   authUserAtom   │───►│      Collab      │  │
│  │  (User Profile)  │    │   (Jotai Store)  │    │ (Manages Session)│  │
│  └──────────────────┘    └──────────────────┘    └────────┬─────────┘  │
│                                                           │             │
│  ┌──────────────────┐    ┌──────────────────┐            │             │
│  │ SceneAccessCheck │◄───│  workspaceApi    │            │             │
│  │  (Permissions)   │    │  (API Client)    │            │             │
│  └──────────────────┘    └──────────────────┘            │             │
│                                                           ▼             │
│                                                  ┌──────────────────┐  │
│                                                  │      Portal      │  │
│                                                  │ (WebSocket Msgs) │  │
│                                                  └────────┬─────────┘  │
└──────────────────────────────────────────────────────────│──────────────┘
                                                           │
                        ┌──────────────────────────────────┤
                        │                                  │
                        ▼                                  ▼
┌───────────────────────────────────┐    ┌───────────────────────────────┐
│        Backend (NestJS)           │    │    Room Service (Node.js)     │
│                                   │    │                               │
│  ┌─────────────────────────────┐  │    │  ┌─────────────────────────┐  │
│  │    SceneAccessService       │  │    │  │  WebSocket Relay        │  │
│  │  - Workspace permissions    │  │    │  │  - Broadcasts messages  │  │
│  │  - Team → Collection access │  │    │  │  - E2E encrypted        │  │
│  │  - Collaboration eligibility│  │    │  │  - Stateless            │  │
│  └─────────────────────────────┘  │    │  └─────────────────────────┘  │
└───────────────────────────────────┘    └───────────────────────────────┘
                │
                ▼
┌───────────────────────────────────┐
│         PostgreSQL + S3           │
│  - Scene metadata & permissions   │
│  - Scene data (encrypted)         │
└───────────────────────────────────┘
```

---

## Part 1: Workspace Types and Permissions

### Workspace Types

| Type | Description | Collaboration |
|------|-------------|---------------|
| **Personal** | Created automatically for each user | Not allowed |
| **Shared** | Created explicitly, supports teams | Allowed |

### Permission Model

```
User
  └─► WorkspaceMember (role: ADMIN / MEMBER / VIEWER)
        └─► TeamMember
              └─► Team
                    └─► TeamCollection (accessLevel: VIEW / EDIT)
                          └─► Collection
                                └─► Scene
```

### Access Rules

| Workspace Type | Collection Type | Who Can Collaborate |
|----------------|-----------------|---------------------|
| Personal | Any | No one (collaboration disabled) |
| Shared | Private | Only the owner |
| Shared | Team collection | Team members with EDIT access |

### Scene Access Levels

| Access Level | Can View | Can Edit | Can Collaborate |
|--------------|----------|----------|-----------------|
| No access | ❌ | ❌ | ❌ |
| VIEW | ✅ | ❌ | ❌ (view-only in room) |
| EDIT | ✅ | ✅ | ✅ |
| ADMIN | ✅ | ✅ | ✅ |

---

## Part 2: URL Structure

### Workspace Scene URLs

```
https://example.com/workspace/{slug}/scene/{sceneId}#key={roomKey}
```

| Component | Description |
|-----------|-------------|
| `slug` | Workspace URL-friendly identifier |
| `sceneId` | Scene database ID |
| `roomKey` | Encryption key (in hash, never sent to server) |

**Flow:**
1. User opens URL
2. If not authenticated → redirect to login
3. Backend checks permissions via `SceneAccessService`
4. If authorized → load scene and join collaboration room
5. If `#key` present → enable real-time sync

### Legacy Anonymous URLs

```
https://example.com/#room={roomId},{roomKey}
```

| Component | Description |
|-----------|-------------|
| `roomId` | Random 20-character ID |
| `roomKey` | Encryption key |

**Flow:**
1. User opens URL
2. No authentication required
3. Join room directly
4. Full edit access for anyone with link

---

## Part 3: Profile Integration

When users collaborate, their identity is displayed to other participants.

### How Profiles Work

1. **Authenticated users** appear with their profile name and avatar
2. **Anonymous users** use randomly generated names (editable)
3. Profile data is transmitted via encrypted WebSocket messages

### State Management

The `Collab` component is a class component, so it accesses user data via Jotai:

```typescript
// AuthContext syncs to atom
useEffect(() => {
  appJotaiStore.set(authUserAtom, user);
}, [user]);

// Collab reads from atom
const authUser = appJotaiStore.get(authUserAtom);
if (authUser?.name) {
  this.setUsername(authUser.name);
}
```

### Priority Order for Username

1. **Authenticated user name** (highest priority)
2. **localStorage saved name** (from previous sessions)
3. **Random generated name** (fallback)

### WebSocket Message Payloads

**Mouse Location:**
```typescript
{
  type: "MOUSE_LOCATION",
  payload: {
    socketId: "...",
    pointer: { x, y },
    button: "up" | "down",
    selectedElementIds: {...},
    username: "John Doe",
    avatarUrl: "data:image/..."  // Base64
  }
}
```

**Idle Status:**
```typescript
{
  type: "IDLE_STATUS",
  payload: {
    socketId: "...",
    userState: "active" | "idle" | "away",
    username: "John Doe",
    avatarUrl: "data:image/..."
  }
}
```

---

## Part 4: Security

### End-to-End Encryption

- All scene data and messages are encrypted client-side
- Encryption key is in URL hash (never sent to server)
- Room service only relays encrypted payloads
- Only room participants can decrypt

### Permission Enforcement

- **Workspace scenes**: Backend validates access before returning room credentials
- **Anonymous rooms**: Anyone with link has access (by design)
- Room service is stateless - permission checks happen at API level

### Avatar Data

- Stored as base64 data URLs in database
- Transmitted within encrypted WebSocket payloads
- No external image loading (prevents tracking)

---

## Part 5: Data Storage

### Scene Data Locations

| Mode | Metadata | Scene Data | Files |
|------|----------|------------|-------|
| Workspace | PostgreSQL `scenes` table | S3 `{storageKey}` | S3 `files/{id}` |
| Anonymous | None | S3 `rooms/{roomId}` | S3 `files/{id}` |

### Scene Model

```prisma
model Scene {
  id                   String   @id
  title                String
  storageKey           String   @unique
  
  // Collaboration
  roomId               String?  // Collaboration room ID
  roomKeyEncrypted     String?  // Encrypted room key (server-side)
  collaborationEnabled Boolean  @default(true)
  
  // Ownership & Organization
  userId               String
  collectionId         String?
  
  // ...
}
```

---

## Part 6: UI Components

### Share Dialog

When sharing a workspace scene:

```
┌─────────────────────────────────────────┐
│  Share this scene                       │
│                                         │
│  Team members with access to this       │
│  collection can collaborate in          │
│  real-time.                             │
│                                         │
│  [Enable collaboration]                 │
│                                         │
│  ─────────── or ───────────             │
│                                         │
│  [Start anonymous board]                │
│  (Creates a separate, unlinked board)   │
└─────────────────────────────────────────┘
```

### Collaborator Avatars

Top-right corner shows connected collaborators:
- **With avatar**: Profile picture in circle
- **Without avatar**: Colored circle with initials
- **Hover**: Shows username tooltip

---

## Part 7: Implementation Status

### Implemented (Current)

- [x] Legacy anonymous collaboration (`#room=` URLs)
- [x] Profile integration (name + avatar in collaboration)
- [x] End-to-end encryption
- [x] Workspace/team/collection permission model
- [x] Scene CRUD with collections

### Planned (See COLLABORATION_IMPLEMENTATION_PLAN.md)

- [ ] Workspace types (PERSONAL vs SHARED)
- [ ] Scene direct URLs (`/workspace/{slug}/scene/{id}`)
- [ ] Permission-based collaboration access
- [ ] Copy/Move collections between workspaces
- [ ] Super admin role

---

## Related Files

### Frontend

| File | Purpose |
|------|---------|
| `excalidraw-app/app-jotai.ts` | `authUserAtom` definition |
| `excalidraw-app/auth/AuthContext.tsx` | Syncs user to atom |
| `excalidraw-app/collab/Collab.tsx` | Collaboration session management |
| `excalidraw-app/collab/Portal.tsx` | WebSocket message handling |
| `excalidraw-app/data/index.ts` | Link generation, message types |
| `excalidraw-app/data/httpStorage.ts` | Room data storage |
| `excalidraw-app/share/ShareDialog.tsx` | Share UI |

### Backend

| File | Purpose |
|------|---------|
| `src/workspace/workspace-scenes.controller.ts` | Scene API endpoints |
| `src/workspace/scene-access.service.ts` | Permission checking (planned) |
| `prisma/schema.prisma` | Database schema |

### Room Service

| File | Purpose |
|------|---------|
| `src/index.ts` | WebSocket relay server |

---

## Testing Checklist

### Profile Integration

- [ ] Authenticated user starts collaboration → shows profile name
- [ ] Avatar appears in collaborator list
- [ ] Anonymous user joins → random name generated
- [ ] Multiple authenticated users see each other's profiles

### Permission-Based Collaboration (After Implementation)

- [ ] Personal workspace scenes → no collaboration option
- [ ] Shared workspace scenes → collaboration available
- [ ] VIEW access → can join but not edit
- [ ] EDIT access → full collaboration
- [ ] Non-member → access denied

### Legacy Mode

- [ ] `#room=` URLs still work
- [ ] No authentication required
- [ ] Anyone with link can edit

---

## Known Limitations

1. **Avatar Size**: Base64 avatars transmitted with every position update
2. **Profile Updates**: Changes during session require reconnection
3. **Room Key Storage**: Currently encrypted server-side; consider client-side key derivation for maximum privacy

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-21 | Initial collaboration profile integration |
| 2025-12-21 | Documented permission model and workspace types |
| 2025-12-21 | Created implementation plan for permission-based collaboration |

