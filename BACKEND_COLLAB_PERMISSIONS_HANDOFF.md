# Backend Collaboration Permissions - Implementation Handoff

**Date:** December 21, 2025  
**Branch:** `feature/collab-permissions-backend`  
**Status:** ✅ Complete and ready for review

---

## Overview

Implemented Phase 1 & 2 of the collaboration permissions system as specified in `docs/COLLABORATION_IMPLEMENTATION_PLAN.md`. The backend now supports workspace types (PERSONAL/SHARED), permission-based collaboration, collection access levels, and copy/move operations between workspaces.

---

## Files Created

### New Services

| File | Purpose |
|------|---------|
| `backend/src/workspace/scene-access.service.ts` | Unified permission checking for scene access (view/edit/collaborate) |

### New Migration

| File | Description |
|------|-------------|
| `backend/prisma/migrations/20251221_add_workspace_types_and_collab/migration.sql` | Schema changes for workspace types, access levels, and collaboration fields |

---

## Files Modified

### Core Services

| File | Changes |
|------|---------|
| `backend/prisma/schema.prisma` | Added `isSuperAdmin`, `WorkspaceType`, `CollectionAccessLevel`, `collaborationEnabled`, `roomKeyEncrypted` |
| `backend/src/workspaces/workspaces.service.ts` | Added workspace type enforcement, `createSharedWorkspace`, `requireSharedWorkspace` |
| `backend/src/users/users.service.ts` | Updated default workspace to set `type: PERSONAL`, super admin bootstrap |
| `backend/src/auth/auth.service.ts` | Added super admin bootstrap from `SUPERADMIN_EMAILS` |
| `backend/src/teams/teams.service.ts` | Updated to use `accessLevel` instead of `canWrite`, block personal workspace teams |
| `backend/src/workspace/workspace-scenes.controller.ts` | Integrated `SceneAccessService`, added collaboration endpoints, copy/move operations |
| `backend/src/app.module.ts` | Registered `SceneAccessService` provider |

### Documentation

| File | Changes |
|------|---------|
| `docs/COLLABORATION_IMPLEMENTATION_PLAN.md` | Marked Phase 1 & 2 as completed with implementation notes |
| `docs/COLLABORATION.md` | Updated implementation status with backend completion |
| `backend/CHANGELOG.md` | Added v0.7.0 entry with comprehensive change list |

---

## New API Endpoints

### Scene Access & Loading

```typescript
// Load scene via workspace slug with permissions
GET /api/v2/workspace/by-slug/:workspaceSlug/scenes/:sceneId
Authorization: Bearer <JWT>

Response 200:
{
  "scene": {
    "id": "scene_123",
    "title": "My Drawing",
    "storageKey": "ws_user_abc123",
    "roomId": "room_xyz789",
    "collectionId": "coll_456",
    "isPublic": false,
    "lastOpenedAt": "2025-12-21T10:30:00Z",
    "createdAt": "2025-12-20T08:00:00Z",
    "updatedAt": "2025-12-21T10:30:00Z",
    "canEdit": true
  },
  "data": "base64_encoded_scene_data",
  "access": {
    "canView": true,
    "canEdit": true,
    "canCollaborate": true
  }
}

Response 401: Unauthorized (redirect to login)
Response 403: Access denied
Response 404: Scene or workspace not found
```

### Collaboration Management

```typescript
// Start collaboration on a scene
POST /api/v2/workspace/scenes/:sceneId/collaborate
Authorization: Bearer <JWT>

Response 200:
{
  "roomId": "abc123xyz789",
  "roomKey": "encrypted_40_char_key"
}

Response 403: Forbidden (no collaborate permission or personal workspace)
Response 404: Scene not found

---

// Get existing collaboration info
GET /api/v2/workspace/scenes/:sceneId/collaborate
Authorization: Bearer <JWT>

Response 200:
{
  "roomId": "abc123xyz789",
  "roomKey": "encrypted_40_char_key"  // null if canCollaborate=false
}

Response 200 (no active collaboration):
null

Response 403: Access denied
Response 404: Scene not found
```

### Collection Copy/Move

```typescript
// Copy collection to another workspace
POST /api/v2/workspace/collections/:collectionId/copy-to-workspace
Authorization: Bearer <JWT>
Content-Type: application/json

Body:
{
  "targetWorkspaceId": "workspace_789",
  "name": "Copied Collection Name"  // optional, defaults to "Copy of {original}"
}

Response 200:
{
  "id": "new_collection_id",
  "name": "Copied Collection Name",
  "icon": "📁",
  "color": "#3B82F6",
  "isPrivate": false,
  "userId": "user_id",
  "workspaceId": "workspace_789",
  "sceneCount": 5,
  "canWrite": true,
  "isOwner": true,
  "createdAt": "2025-12-21T11:00:00Z",
  "updatedAt": "2025-12-21T11:00:00Z"
}

Response 403: No write access to source or target
Response 404: Collection not found

---

// Move collection to another workspace
POST /api/v2/workspace/collections/:collectionId/move-to-workspace
Authorization: Bearer <JWT>
Content-Type: application/json

Body:
{
  "targetWorkspaceId": "workspace_789"
}

Response 200:
{
  "id": "collection_id",
  "name": "Collection Name",
  "icon": "📁",
  "color": "#3B82F6",
  "isPrivate": false,
  "userId": "user_id",
  "workspaceId": "workspace_789",
  "sceneCount": 5,
  "canWrite": true,
  "isOwner": true,
  "createdAt": "2025-12-20T08:00:00Z",
  "updatedAt": "2025-12-21T11:00:00Z"
}

Response 403: No write access or target not admin
Response 404: Collection not found
```

---

## Database Schema Changes

### New Enums

```prisma
enum WorkspaceType {
  PERSONAL
  SHARED
}

enum CollectionAccessLevel {
  VIEW
  EDIT
}
```

### Updated Models

```prisma
model User {
  // ... existing fields
  isSuperAdmin Boolean @default(false)  // NEW
}

model Workspace {
  // ... existing fields
  type WorkspaceType @default(PERSONAL)  // NEW
}

model TeamCollection {
  // REMOVED: canWrite Boolean
  accessLevel CollectionAccessLevel @default(EDIT)  // NEW
}

model Scene {
  // ... existing fields
  collaborationEnabled Boolean @default(true)  // NEW
  roomKeyEncrypted     String?                 // NEW
}
```

---

## Environment Variables

### New (Optional)

```bash
# Super Admin Bootstrap
SUPERADMIN_EMAILS=admin@example.com,owner@example.com

# Room Key Encryption (falls back to JWT_SECRET if not set)
ROOM_KEY_SECRET=your-secure-room-key-secret-here
```

---

## Permission Model

### Scene Access Flow

```
User → WorkspaceMember → TeamMember → Team → TeamCollection → Collection → Scene
```

### Access Rules

| Workspace Type | Collection Type | User Role | Access |
|----------------|----------------|-----------|--------|
| PERSONAL | Any | Owner | VIEW, EDIT, no COLLABORATE |
| PERSONAL | Any | Other | No access |
| SHARED | Private | Owner | VIEW, EDIT, COLLABORATE |
| SHARED | Private | Other | No access |
| SHARED | Team (VIEW) | Team Member | VIEW only |
| SHARED | Team (VIEW) | VIEWER role | VIEW only |
| SHARED | Team (EDIT) | Team Member + MEMBER/ADMIN | VIEW, EDIT, COLLABORATE |
| SHARED | Team (EDIT) | VIEWER role | VIEW only |
| SHARED | Any | ADMIN role | VIEW, EDIT, COLLABORATE |

### Room Key Encryption

Room keys are encrypted using AES-256-GCM:

```typescript
// Encryption format: iv (12 bytes) + authTag (16 bytes) + ciphertext
const secret = process.env.ROOM_KEY_SECRET || process.env.JWT_SECRET;
const key = createHash('sha256').update(secret).digest();
```

---

## Migration Instructions

### Apply Migration

```bash
cd backend

# Option 1: Prisma migrate (recommended)
npx prisma migrate dev --name add_workspace_types_and_collab

# Option 2: Apply SQL manually
psql $DATABASE_URL < prisma/migrations/20251221_add_workspace_types_and_collab/migration.sql
npx prisma generate
```

### Data Migration Notes

1. **Existing workspaces**: All set to `PERSONAL` by default (migration default)
2. **Existing team collections**: All set to `EDIT` access level (migration default)
3. **Existing scenes**: `collaborationEnabled` defaults to `true`
4. **Super admins**: Must be set via `SUPERADMIN_EMAILS` env var and re-login

---

## Testing Checklist

### Backend Tests (Completed)

- [x] TypeScript compilation (`npm run build`)
- [x] ESLint checks (`npm run lint`)
- [x] Prisma client generation

### Integration Tests (Pending)

- [ ] Personal workspace blocks team creation
- [ ] Personal workspace blocks member invites
- [ ] Personal workspace scenes cannot collaborate
- [ ] Shared workspace allows collaboration
- [ ] VIEW access prevents editing
- [ ] EDIT access allows collaboration
- [ ] Copy collection duplicates scenes with new storage keys
- [ ] Move collection clears team associations
- [ ] Room key encryption/decryption works correctly
- [ ] Super admin bootstrap from env variable

---

## Known Issues & TODOs

### None Currently

All planned functionality has been implemented and builds successfully.

### Future Enhancements (Not in Scope)

- Room service permission checks (Option B from plan) - can be added later if needed
- Client-side room key derivation for maximum privacy
- Audit logging for permission changes
- Rate limiting on collaboration endpoint

---

## Frontend Integration TODOs

### Required Frontend Changes

1. **URL Routing**
   - Detect `/workspace/{slug}/scene/{id}#key={roomKey}` pattern
   - Call `GET /workspace/by-slug/{slug}/scenes/{id}` to load scene
   - Use `access` object to enable/disable collaboration UI

2. **Workspace Type Selection**
   - Add workspace type selector when creating workspaces
   - Show "Personal" or "Shared" badge in workspace list
   - Disable team/invite UI for personal workspaces

3. **Collaboration UI**
   - Check `canCollaborate` before showing share button
   - Call `POST /workspace/scenes/:id/collaborate` to start
   - Call `GET /workspace/scenes/:id/collaborate` to get existing room
   - Show "Collaboration disabled" for personal workspace scenes

4. **Collection Operations**
   - Add "Copy to Workspace" action to collection context menu
   - Add "Move to Workspace" action to collection context menu
   - Show workspace selector dialog
   - Display permission warnings (e.g., "Collaboration will be disabled")

5. **Access Level UI**
   - Show VIEW/EDIT badges for team collections
   - Disable edit operations for VIEW-only collections
   - Show tooltip: "You have view-only access"

### API Client Updates

```typescript
// Add to workspaceApi.ts
export async function getSceneBySlug(
  workspaceSlug: string,
  sceneId: string
): Promise<LoadedScene> {
  const response = await fetch(
    `${getApiBaseUrl()}/workspace/by-slug/${workspaceSlug}/scenes/${sceneId}`,
    { credentials: "include" }
  );
  
  if (response.status === 401) {
    window.location.href = `/api/v2/auth/login?redirect=${encodeURIComponent(window.location.href)}`;
    throw new Error("Authentication required");
  }
  
  if (!response.ok) throw new Error("Failed to load scene");
  return response.json();
}

export async function startCollaboration(
  sceneId: string
): Promise<{ roomId: string; roomKey: string }> {
  const response = await fetch(
    `${getApiBaseUrl()}/workspace/scenes/${sceneId}/collaborate`,
    { method: "POST", credentials: "include" }
  );
  
  if (!response.ok) throw new Error("Failed to start collaboration");
  return response.json();
}
```

---

## Verification Commands

```bash
# Verify build
cd backend && npm run build

# Verify lint
cd backend && npm run lint

# Regenerate Prisma client
cd backend && npx prisma generate

# Check migration files
ls -la backend/prisma/migrations/20251221_add_workspace_types_and_collab/

# View schema changes
git diff main backend/prisma/schema.prisma
```

---

## Deployment Notes

### Before Merging to Main

1. Review all code changes
2. Test with `just fresh-dev` (requires frontend integration)
3. Ensure migration applies cleanly to test database
4. Update `deploy/docker-compose.yml` with new version tag

### After Merging to Main

1. Create release tag: `git tag v0.7.0 && git push --tags`
2. GitHub Actions will build and push to GHCR
3. Update main repo `deploy/docker-compose.yml`:
   ```yaml
   api:
     image: ghcr.io/astrateam-net/astradraw-api:0.7.0
   ```
4. Apply database migration to production
5. Set `SUPERADMIN_EMAILS` and `ROOM_KEY_SECRET` in production environment

---

## Contact & Questions

For questions about this implementation, refer to:
- Implementation plan: `docs/COLLABORATION_IMPLEMENTATION_PLAN.md`
- Architecture overview: `docs/COLLABORATION.md`
- API changes: `backend/CHANGELOG.md`
- This handoff: `BACKEND_COLLAB_PERMISSIONS_HANDOFF.md`


