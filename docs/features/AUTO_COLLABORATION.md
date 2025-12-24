# Auto-Collaboration for Shared Collections

**Status:** ✅ Implementation Complete  
**Date:** December 22, 2025  
**Related:** [COLLABORATION.md](COLLABORATION.md), [COLLABORATION_IMPLEMENTATION_PLAN.md](../planning/COLLABORATION_IMPLEMENTATION_PLAN.md)

---

## Overview

This document describes the implementation of **automatic real-time collaboration** for scenes in non-private collections of SHARED workspaces. When multiple authorized users open the same scene, they immediately see each other's cursors and edits - no "Share" button required.

## Design Philosophy

The evolution of AstraDraw's collaboration system:

1. **Room Service** - WebSocket relay for real-time collaboration. Problem: users had to remember/share room URLs.

2. **Workspaces** - Persistent storage for scenes. Instead of remembering URLs, save scenes to a workspace.

3. **Teams & Collections** - Access control. Private collections = personal drafts. Team collections = shared with specific people.

4. **Auto-Collaboration** (this feature) - The natural conclusion. If a scene is in a shared collection, collaboration is *implicit*. It's like Google Docs - if you have access and open the document, you're automatically in the collaborative session.

## Storage Architecture

**Key Principle:** Shared collection scenes use **room storage** as their primary storage, not workspace storage.

| Scene Type | Primary Storage | Autosave Target | Collaboration |
|------------|-----------------|-----------------|---------------|
| Personal workspace | Workspace storage (`scenes/{storageKey}`) | Workspace API | Optional (Share button) |
| Private collection | Workspace storage (`scenes/{storageKey}`) | Workspace API | Optional (Share button) |
| **Shared collection** | **Room storage** (`rooms/{roomId}`) | **Room service** | **Always on, can't disable** |

**Why room storage for shared scenes?**
1. Room storage is encrypted end-to-end
2. All collaborators read/write from the same source
3. No sync issues between workspace and room storage
4. Data is always consistent regardless of who opens first

---

## URL Structure

### Current Workspace Scene URL

```
/workspace/{slug}/scene/{sceneId}
```

Example: `/workspace/myteam/scene/abc123`

### Key Insight: No URL Changes Needed

Unlike legacy anonymous collaboration (`/#room=xxx,yyy`), workspace scenes **do not need the room key in the URL**:

| Mode | URL | Room Key Source |
|------|-----|-----------------|
| Legacy Anonymous | `/#room={roomId},{roomKey}` | In URL hash |
| Workspace Scene | `/workspace/{slug}/scene/{id}` | Fetched from backend |

**Why this works:**
1. The scene URL uniquely identifies the scene
2. The backend stores `roomId` and `roomKeyEncrypted` in the database
3. When loading a scene, the backend returns the decrypted `roomKey` (if user has `canCollaborate` access)
4. The frontend uses that key to join the room-service
5. The key never appears in the URL - it's fetched securely via API

**Benefits:**
- Clean, shareable URLs
- No sensitive data in browser history
- Permission-based access (backend validates before returning key)

---

## Current vs Target Behavior

| Aspect | Current Behavior | Target Behavior |
|--------|------------------|-----------------|
| Scene creation | `roomId` = null | Auto-generate `roomId` and `roomKey` |
| Opening scene | Must click "Share" to start collab | Auto-join collaboration room |
| URL appearance | Same | Same (no change needed) |
| Private collections | No collaboration | No collaboration (unchanged) |
| Personal workspaces | No collaboration | No collaboration (unchanged) |

---

## Configuration

### Room Key Secret

The auto-collaboration feature encrypts room keys before storing them in the database. The encryption uses:

1. **`ROOM_KEY_SECRET`** - If set, used for room key encryption
2. **`JWT_SECRET`** - Fallback if `ROOM_KEY_SECRET` is not set

**You do NOT need to define `ROOM_KEY_SECRET`** - the system automatically uses `JWT_SECRET` for encryption.

**When to use a separate `ROOM_KEY_SECRET`:**
- If you want to rotate `JWT_SECRET` without invalidating existing collaboration rooms
- For additional security separation between authentication and collaboration

**Configuration:**
```bash
# Option 1: Use JWT_SECRET (default, no action needed)
# Room keys are encrypted with JWT_SECRET automatically

# Option 2: Use separate secret (optional)
# Generate with any length (will be hashed with SHA-256):
openssl rand -base64 32 > deploy/secrets/room_key_secret

# In deploy/.env:
ROOM_KEY_SECRET=your_separate_secret

# Or via Docker secrets in docker-compose.yml:
# - ROOM_KEY_SECRET_FILE=/run/secrets/room_key_secret
```

### Understanding Key Types

There are TWO different keys in the collaboration system:

| Key | Length | Purpose | Who generates |
|-----|--------|---------|---------------|
| **ROOM_KEY_SECRET** | Any length | Encrypts room keys at rest in database | Admin (you) |
| **Room Key** | Exactly 22 chars | End-to-end encryption between collaborators | Backend (automatic) |

**Why 22 characters for room keys?**

The frontend uses Web Crypto API with AES-128-GCM, which requires exactly 16 bytes. When encoded as base64url, 16 bytes = 22 characters.

```typescript
// Backend generates room keys like this:
import { randomBytes } from 'crypto';
const roomKey = randomBytes(16).toString('base64url'); // Always 22 chars
```

> ⚠️ **Common Error:** If room keys are the wrong length, you'll see:
> ```
> DataError: The JWK "k" member did not include the right length of key data
> ```
> This is handled automatically by the backend - you don't need to worry about it.

---

## Implementation

### Backend Changes

#### 1. Auto-Generate Room Credentials on Scene Creation

**File:** `backend/src/workspace/workspace-scenes.controller.ts`

When creating a scene in a non-private collection of a SHARED workspace:
- Generate `roomId` (20-char nanoid)
- Generate `roomKey` (40-char nanoid)
- Encrypt and store `roomKeyEncrypted`
- Set `collaborationEnabled = true`

```typescript
// Pseudo-code for createScene()
if (collection.workspace.type === 'SHARED' && !collection.isPrivate) {
  roomId = nanoid(20);
  roomKey = nanoid(40);
  roomKeyEncrypted = encrypt(roomKey);
  collaborationEnabled = true;
}
```

#### 2. Return Room Key When Loading Scene

**File:** `backend/src/workspace/workspace-scenes.controller.ts`

When loading a scene via `GET /workspace/by-slug/:slug/scenes/:id`:
- Check access via `SceneAccessService`
- If `canCollaborate` is true AND scene has `roomId`:
  - Decrypt and return `roomKey` in response
- If `canCollaborate` is false:
  - Return `roomKey: null`

#### 3. Lazy Generation for Existing Scenes

For existing scenes that don't have `roomId`:
- When opened by a user with `canCollaborate` access
- Generate credentials on-the-fly
- Save to database
- Return to frontend

### Frontend Changes

#### 1. Update API Types

**File:** `frontend/excalidraw-app/auth/workspaceApi.ts`

Add `roomId` and `roomKey` to the scene load response type.

#### 2. Auto-Join Collaboration on Scene Load

**File:** `frontend/excalidraw-app/App.tsx`

In `loadSceneFromUrl()`:
```typescript
const { scene, data, access, roomId, roomKey } = await loadWorkspaceScene(...);

// Load scene data into canvas
excalidrawAPI.updateScene({ elements, appState, files });

// AUTO-JOIN if eligible
if (access.canCollaborate && roomId && roomKey) {
  await collabAPI.startCollaboration({ roomId, roomKey });
}
```

#### 3. Handle Room Switching

When switching between scenes:
- Leave current collaboration room (if any)
- Join new scene's room (if eligible)

---

## Permission Matrix

| Workspace Type | Collection Type | User Access | Auto-Collaboration |
|----------------|-----------------|-------------|-------------------|
| PERSONAL | Any | Owner | ❌ No |
| SHARED | Private | Owner | ❌ No |
| SHARED | Private | Others | ❌ No access |
| SHARED | Team Collection | ADMIN | ✅ Yes |
| SHARED | Team Collection | MEMBER with EDIT | ✅ Yes |
| SHARED | Team Collection | MEMBER with VIEW | ❌ View-only |
| SHARED | Team Collection | VIEWER | ❌ View-only |

---

## Room Service

**No changes required** to room-service.

The room-service remains a stateless relay:
- It accepts any `roomId` and broadcasts messages to that room
- Permission enforcement happens at the backend API level
- Only users who can call the backend API and receive the `roomKey` can meaningfully participate

---

## Autosave vs Collaboration Save

### How It Works

When a scene has auto-collaboration enabled:

1. **Autosave is DISABLED** - The `onChange` callback checks `collabAPI?.isCollaborating()` and skips workspace autosave
2. **Collab save takes over** - The `Collab.tsx` component saves to room storage via `saveCollabRoomToStorage()`
3. **Data stays in room storage** - All changes are encrypted and stored at `/rooms/{roomId}`

```
Solo Mode (personal/private scenes):
User draws → onChange() → debounce → performSave() → PUT /api/v2/workspace/scenes/{id}/data

Collab Mode (shared collection scenes):
User draws → onChange() → collabAPI.syncElements() → WebSocket broadcast
                                              ↓
                       saveCollabRoomToStorage() (debounced)
                                              ↓
                       PUT /rooms/{roomId} (encrypted)
```

### First Load Behavior (isAutoCollab)

When opening a shared scene for the first time:
1. Backend returns scene data from workspace storage (initial state)
2. Frontend loads scene into canvas
3. Frontend calls `collabAPI.startCollaboration({ roomId, roomKey, isAutoCollab: true })`
4. With `isAutoCollab: true`:
   - Scene is NOT reset (unlike joining via link)
   - Current elements are saved to room storage
   - Future saves go to room storage

This ensures the initial scene data is preserved and synced to room storage for other collaborators.

---

## UI Changes for Auto-Collab Scenes

### Hidden Elements

For scenes with auto-collaboration enabled:

1. **SaveStatusIndicator is hidden** - Collaboration handles saving, not autosave
2. **"End Session" button is hidden** - Users cannot stop collaboration for shared scenes

### Visible Elements

1. **Share button remains visible** - Shows collaborator count/avatars
2. **Share dialog opens** - But without the "End Session" button
3. **Collaborator cursors** - Visible in real-time

### State Management

A Jotai atom `isAutoCollabSceneAtom` tracks whether the current scene is auto-collab:

```typescript
// Set when loading a scene
if (loaded.access.canCollaborate && loaded.roomId && loaded.roomKey) {
  setIsAutoCollabScene(true);
} else {
  setIsAutoCollabScene(false);
}
```

This atom is used to:
- Hide SaveStatusIndicator during collaboration
- Hide "End Session" button in ShareDialog

---

## Testing Checklist

### Scene Creation

- [ ] Create scene in shared collection → has `roomId` and `roomKeyEncrypted`
- [ ] Create scene in private collection → no `roomId`
- [ ] Create scene in personal workspace → no `roomId`
- [ ] `collaborationEnabled` is set correctly based on context

### Scene Loading

- [ ] Open scene with collaboration → auto-joins room
- [ ] Open scene → see other users' cursors immediately
- [ ] User with VIEW access → no collaboration, view-only mode
- [ ] User with no access → 403 error

### Room Switching

- [ ] Switch from scene A to scene B → leaves room A, joins room B
- [ ] Switch from collaborative scene to private scene → leaves room
- [ ] Switch from private scene to collaborative scene → joins room

### Legacy Compatibility

- [ ] Legacy `#room=xxx,yyy` links still work
- [ ] Anonymous mode still works
- [ ] Existing scenes without `roomId` work (lazy generation)

### Edge Cases

- [ ] Scene moved from private to shared collection → generates credentials on next open
- [ ] Scene moved from shared to private collection → `canCollaborate` returns false
- [ ] Network disconnect → existing reconnection logic handles it
- [ ] Multiple browser tabs with same scene → both join same room

---

## Implementation Progress

### Backend ✅

- [x] Modify `createScene()` to auto-generate room credentials
- [x] Modify `getSceneBySlug()` to return `roomKey` for eligible users
- [x] Add lazy credential generation for existing scenes
- [x] Generate proper AES-128-GCM keys (22-char base64url)

### Frontend ✅

- [x] Update `workspaceSceneLoader.ts` types
- [x] Modify `loadSceneFromUrl()` to auto-join collaboration
- [x] Handle room switching when navigating between scenes
- [x] Add `isAutoCollab` flag to preserve scene data on first load
- [x] Hide SaveStatusIndicator during collaboration
- [x] Hide "End Session" button for auto-collab scenes
- [x] Add `isAutoCollabSceneAtom` for state tracking

### Integration ✅

- [x] Test full flow: create scene → open in two browsers → see cursors
- [x] Test data persistence after refresh
- [x] Test UI elements hidden correctly

---

## Estimated Effort

| Task | Estimate |
|------|----------|
| Backend: Auto-generate credentials on create | 2-3 hours |
| Backend: Return credentials on scene load | 1-2 hours |
| Backend: Lazy generation for existing scenes | 1-2 hours |
| Frontend: Auto-join collaboration | 2-3 hours |
| Frontend: Room switching | 1-2 hours |
| Testing and edge cases | 2-3 hours |
| **Total** | **9-15 hours** |

---

## Future Enhancements (Out of Scope)

These features are NOT part of this implementation:

1. **Dashboard presence** - See who's online in a collection
2. **Scene card indicators** - Show active collaborators on scene thumbnails
3. **Notifications** - Alert when someone joins your scene
4. **Presence history** - "Last seen" timestamps

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-22 | Initial document created |
| 2025-12-22 | Backend implementation complete |
| 2025-12-22 | Frontend implementation complete |
| 2025-12-22 | Fixed AES-128-GCM key generation (22-char base64url) |
| 2025-12-22 | Added `isAutoCollab` flag to preserve scene data on first load |
| 2025-12-22 | Hide SaveStatusIndicator and "End Session" button for auto-collab |
| 2025-12-22 | ✅ Feature complete and tested |
| 2025-12-24 | 🐛 **Critical Bug Fixes (COLLAB-001, COLLAB-002)** - see section below |
| 2025-12-25 | 🐛 **Scene Switching Fixes (COLLAB-003, COLLAB-004)** - see section below |

---

## Bug Fixes - December 24, 2025

### COLLAB-001: Scene Data Loss on Scene Switching

**Problem:** When switching between scenes in a shared workspace, drawing data was lost. Users would see their drawings briefly, then the canvas would reset to empty (Excalidraw welcome screen).

**Root Causes Identified:**

1. **Wrong roomId during save** - `saveCollabRoomToStorage` was saving to the old room instead of the new room because collaboration session wasn't properly switched
2. **Elements captured too late** - `stopCollaboration` was getting elements AFTER async operations started, when canvas was already empty
3. **Socket destroyed before save** - `saveCollabRoomToStorage` (async) wasn't awaited, so `destroySocketClient()` ran before save completed
4. **Loading from wrong storage** - For auto-collab scenes, data was loaded from backend API (stale) instead of room storage (real-time)
5. **Workspace slug mismatch** - `CollectionView` and `WorkspaceSidebar` used stale `currentWorkspaceSlugAtom` instead of `currentWorkspace?.slug`
6. **Empty canvas saved** - `stopCollaboration` saved empty canvas before `roomDataLoaded` flag was set
7. **Loaded data not applied** - `startCollaboration` returned scene data but it wasn't applied to canvas via `updateScene()`

**Fixes Applied:**

```typescript
// Fix 1: Capture elements BEFORE async operations
const elementsToSave = excalidrawAPI.getSceneElementsIncludingDeleted();
collabAPI.stopCollaboration(false, elementsToSave); // Pass elements as parameter

// Fix 2: Await save before destroying socket
async stopCollaboration(keepRemoteState: boolean, elementsToSave?: readonly OrderedExcalidrawElement[]) {
  if (this.roomDataLoaded && elements.length > 0) {
    await this.saveCollabRoomToStorage(getSyncableElements(elements)); // AWAIT!
  }
  this.destroySocketClient(); // Now safe to destroy
}

// Fix 3: Load from room storage, not backend API
const sceneData = await collabAPI.startCollaboration({ roomId, roomKey, isAutoCollab: true });
if (sceneData?.elements) {
  excalidrawAPI.updateScene({ elements: sceneData.elements }); // Apply to canvas!
}

// Fix 4: Use workspace directly, not stale atom
const workspaceSlug = currentWorkspace?.slug; // NOT currentWorkspaceSlugAtom
```

### COLLAB-002: New Scenes Don't Initialize Collaboration

**Problem:** When creating a new scene in a shared workspace, collaboration wasn't initialized. The scene was created but saving went to the wrong room (from previous session).

**Root Cause:** `handleNewScene` in `App.tsx` called `collabAPI.startCollaboration()` but:
1. Previous collaboration session was still active (`portal.socket` existed)
2. `startCollaboration()` returns early if socket exists: `if (this.portal.socket) return null;`
3. New scene was created but collaboration stayed connected to old room

**Fix Applied:**

```typescript
// In handleNewScene - stop old session before starting new
if (collabAPI.isCollaborating()) {
  await collabAPI.stopCollaboration(false, []); // Stop old session first
}

// Now startCollaboration will work
const { roomId, roomKey } = await startCollaboration(scene.id);
await collabAPI.startCollaboration({ roomId, roomKey, isAutoCollab: true });
```

### Key Architectural Lessons

1. **Room storage is source of truth** for collaboration scenes, not backend API
2. **Capture state synchronously** before any async operations
3. **Await saves** before destroying resources (sockets, portals)
4. **Check collaboration state** before starting new sessions
5. **Use single source of truth** for workspace data (`currentWorkspaceAtom`, not separate slug atoms)

### Related Documentation

- [MVP Release Bugs](/docs/development/MVP_RELEASE_BUGS.md) - Full postmortem with code examples
- [Collaboration System](/docs/features/COLLABORATION.md) - Architecture overview

---

## Bug Fixes - December 25, 2025

### COLLAB-003: Data Contamination When Switching Scenes

**Problem:** When quickly switching between scenes in a shared collection, drawings from Scene A would appear on Scene B.

**Root Causes:**
1. Throttled `queueSaveToStorage` (20-second interval) could fire after room switch, saving old data to new room
2. `syncElements` was called during room transitions when portal was inconsistent
3. Canvas wasn't cleared for auto-collab scenes when joining existing rooms

**Fixes Applied:**
1. **Cancel (not flush) pending operations** when switching rooms
2. **Guard `syncElements`** with `portal.isOpen()` check
3. **Clear canvas for ALL existing room joins**, including auto-collab

```typescript
// Cancel pending operations when switching
this.queueBroadcastAllElements.cancel();
this.queueSaveToStorage.cancel();

// Guard syncElements
if (!this.portal.isOpen()) return;

// Clear canvas for all room joins
if (existingRoomLinkData) {
  this.excalidrawAPI.resetScene();
}
```

### COLLAB-004: Stale Content During Scene Loading

**Problem:** When switching scenes, old content was visible for 2-3 seconds. Users could accidentally draw on empty canvas.

**Fix:** Use Excalidraw's `isLoading` state to disable drawing during transitions:

```typescript
// Start loading - disable drawing
excalidrawAPI.updateScene({
  elements: [],
  appState: { isLoading: true },
});

// After load - re-enable drawing
excalidrawAPI.updateScene({
  elements: sceneData.elements,
  appState: { isLoading: false },
});
```

### Key Lessons

1. **Cancel, don't flush** throttled operations when context changes
2. **Use framework loading states** to prevent user interaction during transitions
3. **Guard all sync operations** with portal state checks
4. **Clear canvas for ALL room joins** to prevent element reconciliation issues

