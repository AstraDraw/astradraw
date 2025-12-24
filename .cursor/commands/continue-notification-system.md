# Continue Notification System Implementation

You are helping continue work on the Notification System feature from `docs/planning/NOTIFICATION_SYSTEM_IMPLEMENTATION_PLAN.md`.

> **Note:** This is a continuation of the Comment System (Phase 7). The Comment System (Phases 1-6) must be complete before implementing notifications.

## Step 1: Review the Implementation Plan

Read the current state:
```
@docs/planning/NOTIFICATION_SYSTEM_IMPLEMENTATION_PLAN.md
```

Also review the research document for UI/UX details:
```
@docs/planning/NOTIFICATION_SYSTEM_RESEARCH.md
```

Check Comment System status (notifications depend on it):
```
@docs/planning/COMMENT_SYSTEM_IMPLEMENTATION_PLAN.md
```

## Step 2: Select a Phase

Ask the user which phase to work on, or suggest based on dependencies:

**Phase 1: Backend - Database & Module** (No dependencies)
- [ ] Prisma schema migration (Notification model + enum)
- [ ] NestJS notifications module
- [ ] List notifications endpoint (cursor pagination)
- [ ] Unread count endpoint
- [ ] Mark as read endpoints

**Phase 2: Backend - Comment Integration** (Depends on Phase 1)
- [ ] Inject NotificationsService into CommentsService
- [ ] Trigger MENTION notifications on @mentions
- [ ] Trigger COMMENT notifications for thread participants
- [ ] getThreadParticipants helper

**Phase 3: Frontend - API & State** (Depends on Phase 1)
- [ ] API client `auth/api/notifications.ts`
- [ ] TypeScript interfaces
- [ ] Query keys + mutation keys in `queryClient.ts`
- [ ] React Query hooks (useNotifications, useUnreadCount)
- [ ] Jotai atoms

**Phase 4: Frontend - Bell & Popup** (Depends on Phase 3)
- [ ] NotificationBell component
- [ ] NotificationBadge component
- [ ] NotificationPopup component
- [ ] NotificationItemSkeleton (loading state)
- [ ] Update SidebarFooter

**Phase 5: Frontend - Notifications Page** (Depends on Phase 4)
- [ ] Add route to router.ts
- [ ] NotificationsPage component
- [ ] NotificationTimelineItem component
- [ ] UnreadBadge component
- [ ] Infinite scroll

**Phase 6: Translations** (Can be done alongside any phase)
- [ ] Add strings to en.json
- [ ] Add strings to ru-RU.json

## Step 3: Implementation Approach

### For Backend Work (Phases 1-2)
1. Create Prisma migration first
2. Run `npx prisma migrate dev`
3. Create module structure in `backend/src/notifications/`
4. Follow existing patterns from `backend/src/comments/`
5. Test endpoints with curl

### For Frontend Work (Phases 3-5)
1. Follow patterns from existing code:
   - API client: `auth/api/comments.ts`
   - Hooks: `hooks/useCommentThreads.ts`
   - Atoms: `components/Comments/commentsState.ts`
   - Components: Use CSS Modules with folder structure

2. Key patterns to follow:
   ```typescript
   // API client
   import { apiRequest } from "./client";
   
   // React Query hooks
   import { useQuery, useInfiniteQuery, useMutation, useQueryClient } from "@tanstack/react-query";
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

2. **Update checklist** in `NOTIFICATION_SYSTEM_IMPLEMENTATION_PLAN.md`:
   ```markdown
   ### Phase X: [Name] ✅
   - [x] Item completed
   - [x] Another item completed
   ```

3. **Add implementation status** below acceptance criteria in the plan:
   ```markdown
   ### Implementation Status ✅

   **Completed:** YYYY-MM-DD

   **Files Created:**
   - `path/to/file.ts` - Brief description

   **Files Modified:**
   - `path/to/file.ts` - What was changed
   ```

4. **Add to changelog table** at bottom of `NOTIFICATION_SYSTEM_IMPLEMENTATION_PLAN.md`:
   ```markdown
   | YYYY-MM-DD | Phase X: Brief description of what was completed |
   ```

5. **Update CHANGELOG.md** for affected repos:
   - Backend changes: `backend/CHANGELOG.md`
   - Frontend changes: `frontend/CHANGELOG.md`
   ```markdown
   ## [0.X.X] - YYYY-MM-DD

   ### Added
   - **Notification System Phase X** - Brief description
   ```

6. **Add translations** to both locale files (if UI strings added):
   - `packages/excalidraw/locales/en.json`
   - `packages/excalidraw/locales/ru-RU.json`

7. **Update Comment System plan** - Mark Phase 7 items as complete:
   ```markdown
   ### Phase 7: Notification Integration ✅
   - [x] Create notifications on @mention
   - [x] Create notifications on new comment
   ```

8. **Provide phase summary:**
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
| Module structure | `backend/src/comments/` |
| Controller pattern | `backend/src/comments/comments.controller.ts` |
| Service pattern | `backend/src/comments/comments.service.ts` |
| Prisma schema | `backend/prisma/schema.prisma` |

### Frontend
| Purpose | Reference File |
|---------|----------------|
| API client | `frontend/excalidraw-app/auth/api/comments.ts` |
| Types | `frontend/excalidraw-app/auth/api/types.ts` |
| Query keys | `frontend/excalidraw-app/lib/queryClient.ts` |
| React Query hook | `frontend/excalidraw-app/hooks/useCommentThreads.ts` |
| Jotai atoms | `frontend/excalidraw-app/components/Comments/commentsState.ts` |
| Skeleton pattern | `frontend/excalidraw-app/components/Skeletons/` |

## Common Issues

### Unread Count Not Updating
Ensure mutations invalidate the unread count query:
```typescript
queryClient.invalidateQueries({ queryKey: queryKeys.notifications.unreadCount });
```

### Popup Not Closing on Outside Click
Use click-outside hook or check event target:
```typescript
useEffect(() => {
  const handleClickOutside = (e: MouseEvent) => {
    if (popupRef.current && !popupRef.current.contains(e.target as Node)) {
      onClose();
    }
  };
  document.addEventListener("mousedown", handleClickOutside);
  return () => document.removeEventListener("mousedown", handleClickOutside);
}, [onClose]);
```

### Infinite Scroll Not Triggering
Ensure the intersection observer target is visible:
```typescript
import { useInView } from "react-intersection-observer";

const { ref, inView } = useInView();

useEffect(() => {
  if (inView && hasNextPage && !isFetchingNextPage) {
    fetchNextPage();
  }
}, [inView, hasNextPage, isFetchingNextPage, fetchNextPage]);
```

### Dark Mode Styles
Use the dark mode mixin:
```scss
@use "../../styles/mixins" as *;
@include dark-mode { .myClass { background: #232329; } }
```

## Notification Types Reference

| Type | Icon | Message | Trigger |
|------|------|---------|---------|
| COMMENT | 💬 | "{User} posted a comment in {Scene}" | New comment on thread |
| MENTION | @ | "{User} mentioned you in {Scene}" | User @mentioned |

## Deep Link Format

Notification click-through uses:
```
/workspace/{slug}/scene/{sceneId}?thread={threadId}&comment={commentId}
```


