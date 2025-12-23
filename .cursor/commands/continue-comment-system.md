# Continue Comment System Implementation

You are helping continue work on the Comment System feature from `docs/planning/COMMENT_SYSTEM_IMPLEMENTATION_PLAN.md`.

## Step 1: Review the Implementation Plan

Read the current state:
```
@docs/planning/COMMENT_SYSTEM_IMPLEMENTATION_PLAN.md
```

Also review the research document for UI/UX details:
```
@docs/planning/COMMENT_SYSTEM_RESEARCH.md
```

## Step 2: Select a Phase

Ask the user which phase to work on, or suggest based on dependencies:

**Phase 1: Backend Foundation** (No dependencies)
- [ ] Prisma schema migration
- [ ] NestJS comments module
- [ ] CRUD endpoints for threads/comments
- [ ] Permission guards
- [ ] Field filtering support

**Phase 2: Frontend State & API** (Depends on Phase 1)
- [ ] API client `auth/api/comments.ts`
- [ ] TypeScript interfaces
- [ ] Query keys in `queryClient.ts`
- [ ] React Query hooks
- [ ] Jotai atoms

**Phase 3: Canvas Integration** (Depends on Phase 2)
- [ ] ThreadMarkersLayer component
- [ ] ThreadMarker component
- [ ] Position updates on pan/zoom
- [ ] Comment mode (C hotkey)
- [ ] CommentCreationOverlay

**Phase 4: Comment Popup** (Depends on Phase 3)
- [ ] ThreadPopup component
- [ ] CommentItem, CommentInput
- [ ] @mention autocomplete
- [ ] Deep links in router.ts
- [ ] Resolve/reopen functionality

**Phase 5: Sidebar Panel** (Depends on Phase 2)
- [ ] CommentsSidebar component
- [ ] Search with highlighting
- [ ] Filter/sort controls
- [ ] Replace AppSidebar placeholder
- [ ] CommentsFooterButton

**Phase 6: Real-time Sync** (Optional, depends on Phase 4)
- [ ] WebSocket events in room-service
- [ ] useCommentSync hook
- [ ] Event emission on mutations

**Phase 7: Notification Integration** (Depends on Phase 4 + Notification System)
- [ ] Create notifications on @mention
- [ ] Create notifications on new comment

## Step 3: Implementation Approach

### For Backend Work (Phase 1)
1. Create Prisma migration first
2. Run `npx prisma migrate dev`
3. Create module structure in `backend/src/comments/`
4. Follow existing patterns from `backend/src/collections/`
5. Test endpoints with curl or Postman

### For Frontend Work (Phases 2-5)
1. Follow patterns from existing code:
   - API client: `auth/api/scenes.ts`
   - Hooks: `hooks/useScenesCache.ts`
   - Atoms: `components/Settings/settingsState.ts`
   - Components: Use CSS Modules with folder structure

2. Key patterns to follow:
   ```typescript
   // API client
   import { apiRequest, jsonBody } from "./client";
   
   // React Query hooks
   import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
   import { queryKeys } from "../lib/queryClient";
   
   // Jotai atoms
   import { atom } from "jotai";
   import { useAtomValue, useSetAtom } from "jotai";
   
   // CSS Modules
   import styles from "./ComponentName.module.scss";
   ```

3. Component folder structure:
   ```
   ComponentName/
   ├── index.ts                    # Re-export
   ├── ComponentName.tsx           # Component
   └── ComponentName.module.scss   # Styles
   ```

### For Real-time Sync (Phase 6)
1. Add events to `room-service/src/index.ts`
2. Create `useCommentSync` hook in frontend
3. Integrate with existing Collab component

## Step 4: Implementation

1. **Ensure dev environment running:**
   ```bash
   just dev-status
   ```

2. **Make incremental changes** - commit frequently

3. **Run checks after each significant change:**
   ```bash
   just check        # All checks
   just check-backend   # Backend only
   just check-frontend  # Frontend only
   ```

4. **Test manually:**
   - Backend: Use curl or browser DevTools
   - Frontend: Test in browser with hot reload

## Step 5: Finalize Phase

After completing a phase:

1. **Run all checks:**
   ```bash
   just check
   ```

2. **Update checklist** in `COMMENT_SYSTEM_IMPLEMENTATION_PLAN.md`:
   ```markdown
   ### Phase X: [Name]
   - [x] Item completed
   - [x] Another item completed
   ```

3. **Add translations** to both locale files:
   - `packages/excalidraw/locales/en.json`
   - `packages/excalidraw/locales/ru-RU.json`

4. **Provide phase summary:**
   ```
   ## Phase X Complete

   **Phase:** [Name]
   **Status:** ✅ Complete
   **Files Created:** X new files
   **Files Modified:** Y files
   **Checks:** Passing
   
   **Next Phase:** [Name] - [Brief description]
   ```

## Key Files Reference

### Backend
| Purpose | Reference File |
|---------|----------------|
| Module structure | `backend/src/collections/` |
| Controller pattern | `backend/src/collections/collections.controller.ts` |
| Service pattern | `backend/src/collections/collections.service.ts` |
| Permission guard | `backend/src/workspaces/workspace-role.guard.ts` |
| Field filtering | `backend/src/utils/field-filter.ts` |

### Frontend
| Purpose | Reference File |
|---------|----------------|
| API client | `frontend/excalidraw-app/auth/api/scenes.ts` |
| Types | `frontend/excalidraw-app/auth/api/types.ts` |
| Query keys | `frontend/excalidraw-app/lib/queryClient.ts` |
| React Query hook | `frontend/excalidraw-app/hooks/useScenesCache.ts` |
| Jotai atoms | `frontend/excalidraw-app/components/Settings/settingsState.ts` |
| CSS Module component | `frontend/excalidraw-app/components/SceneCard/` |

## Common Issues

### Input Fields Not Working
Always stop keyboard event propagation:
```typescript
<input
  onKeyDown={(e) => e.stopPropagation()}
  onKeyUp={(e) => e.stopPropagation()}
/>
```

### Dark Mode Styles
Use the dark mode mixin:
```scss
@use "../../styles/mixins" as *;
@include dark-mode { .myClass { background: #232329; } }
```

### Canvas Coordinates
Use Excalidraw utilities:
```typescript
import { sceneCoordsToViewportCoords, viewportCoordsToSceneCoords } from "@excalidraw/excalidraw";
```

### Permission Checks
Reuse existing guards:
```typescript
@UseGuards(JwtAuthGuard)
// Check scene access in service layer via SceneAccessService
```

