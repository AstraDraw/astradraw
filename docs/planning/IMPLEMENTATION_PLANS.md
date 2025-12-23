# AstraDraw Implementation Plans

This document contains ready-to-implement improvement plans. Each plan is designed to be completed in a single focused session.

**How to use:** Copy the prompt for the plan you want to implement and paste it into a new Cursor chat.

---

## Quick Reference

| Plan                                                        | Difficulty | Time      | Impact                              |
| ----------------------------------------------------------- | ---------- | --------- | ----------------------------------- |
| [1. useSceneActions Hook](#plan-1-usesceneactions-hook)     | 🟢 Easy    | 1-2 hours | High - removes duplicate code       |
| [2. Toast Notifications](#plan-2-toast-notifications)       | 🟢 Easy    | 2-3 hours | High - better UX                    |
| [3. Loading Skeletons](#plan-3-loading-skeletons)           | 🟢 Easy    | 2-3 hours | Medium - polished feel              |
| [4. Error Boundaries](#plan-4-error-boundaries)             | 🟢 Easy    | 1-2 hours | Medium - crash protection           |
| [5. Split WorkspaceSidebar](#plan-5-split-workspacesidebar) | 🟡 Medium  | 1-2 days  | High - maintainability              |
| [6. Split workspaceApi.ts](#plan-6-split-workspaceapits)    | 🟡 Medium  | 3-4 hours | Medium - organization               |
| [7. useCollections Hook](#plan-7-usecollections-hook)       | 🟡 Medium  | 2-3 hours | Medium - shared state               |
| [8. useWorkspaces Hook](#plan-8-useworkspaces-hook)         | 🟡 Medium  | 2-3 hours | Medium - shared state               |
| [9. Optimistic Updates](#plan-9-optimistic-updates)         | 🟡 Medium  | 3-4 hours | High - instant feedback             |
| [10. React Query Migration](#plan-10-react-query-migration) | 🔴 Hard    | 2-3 days  | Very High - replaces manual caching |

---

## Plan 1: useSceneActions Hook

**Goal:** Extract duplicate scene operations (delete, rename, duplicate) into a reusable hook.

**Why:** Currently, delete/rename/duplicate code is copy-pasted in 4 files:

- `WorkspaceSidebar.tsx`
- `DashboardView.tsx`
- `CollectionView.tsx`
- `SceneCard.tsx`

### Prompt for New Chat

````
I want to create a `useSceneActions` hook to centralize scene operations.

**Current Problem:**
Scene delete/rename/duplicate logic is duplicated in:
- WorkspaceSidebar.tsx
- DashboardView.tsx
- CollectionView.tsx
- SceneCard.tsx

**Task:**
1. Create `frontend/excalidraw-app/hooks/useSceneActions.ts`
2. The hook should provide:
   - `deleteScene(sceneId: string)` - with confirmation dialog
   - `renameScene(sceneId: string, newTitle: string)`
   - `duplicateScene(sceneId: string)` - returns the new scene
3. Each action should:
   - Call the API
   - Trigger `triggerScenesRefreshAtom` for cache invalidation
   - Handle errors gracefully
4. Update all 4 components to use this hook instead of inline logic

**Files to review:**
- @frontend/excalidraw-app/components/Workspace/WorkspaceSidebar.tsx (look for handleDeleteScene, handleRenameScene, handleDuplicateScene)
- @frontend/excalidraw-app/components/Workspace/DashboardView.tsx
- @frontend/excalidraw-app/components/Workspace/CollectionView.tsx
- @frontend/excalidraw-app/auth/workspaceApi.ts (for API functions)
- @frontend/excalidraw-app/components/Settings/settingsState.ts (for refresh atoms)

**Expected Result:**
```typescript
// In any component:
const { deleteScene, renameScene, duplicateScene } = useSceneActions();

// Usage
await deleteScene(scene.id); // Shows confirm, calls API, refreshes cache
````

```

---

## Plan 2: Toast Notifications

**Goal:** Replace `alert()` and silent operations with toast notifications.

**Why:** Users don't know if actions succeeded or failed.

### Prompt for New Chat

```

I want to add toast notifications to AstraDraw using react-hot-toast.

**Current Problem:**

- Errors shown via `alert()` (ugly, blocks UI)
- Success operations are silent (user doesn't know it worked)

**Task:**

1. Install react-hot-toast: `cd frontend && yarn add react-hot-toast`
2. Add `<Toaster />` component to App.tsx
3. Create a toast utility at `frontend/excalidraw-app/utils/toast.ts`:
   - `showSuccess(message: string)`
   - `showError(message: string)`
   - `showLoading(promise, messages)` for async operations
4. Replace alert() calls with toast notifications in:
   - Scene operations (delete, duplicate, rename)
   - Collection operations
   - Profile updates
   - Any error handlers

**Files to review:**

- @frontend/excalidraw-app/App.tsx (add Toaster)
- @frontend/excalidraw-app/components/Workspace/WorkspaceSidebar.tsx (has alert calls)
- @frontend/excalidraw-app/components/Settings/ProfilePage.tsx

**Style:** Match the app's dark/light theme. Position: bottom-right.

**Example usage after implementation:**

```typescript
import { showSuccess, showError } from "../../utils/toast";

try {
  await deleteSceneApi(sceneId);
  showSuccess(t("workspace.sceneDeleted"));
} catch (err) {
  showError(t("workspace.deleteError"));
}
```

```

---

## Plan 3: Loading Skeletons

**Goal:** Show skeleton placeholders instead of spinners while loading.

**Why:** Skeletons feel faster and more polished than spinners.

### Prompt for New Chat

```

I want to add loading skeleton components to AstraDraw.

**Current Problem:**
Components show empty space or spinning indicators while loading data.

**Task:**

1. Create skeleton components in `frontend/excalidraw-app/components/Skeletons/`:

   - `SceneCardSkeleton.tsx` - matches SceneCard dimensions
   - `CollectionItemSkeleton.tsx` - matches sidebar collection items
   - `Skeleton.tsx` - base component with shimmer animation
   - `Skeletons.scss` - shimmer animation styles

2. Replace loading spinners with skeletons in:
   - `DashboardView.tsx` - show 6 SceneCardSkeletons in grid
   - `CollectionView.tsx` - show 6 SceneCardSkeletons in grid
   - `WorkspaceSidebar.tsx` - show CollectionItemSkeletons

**Files to review:**

- @frontend/excalidraw-app/components/Workspace/SceneCard.tsx (for dimensions)
- @frontend/excalidraw-app/components/Workspace/SceneCard.scss
- @frontend/excalidraw-app/components/Workspace/DashboardView.tsx (has isLoading state)
- @frontend/excalidraw-app/components/Workspace/CollectionView.tsx

**Skeleton CSS pattern:**

```scss
.skeleton {
  background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}

@keyframes shimmer {
  0% {
    background-position: 200% 0;
  }
  100% {
    background-position: -200% 0;
  }
}

// Dark mode
.excalidraw.theme--dark,
.excalidraw-app.theme--dark {
  .skeleton {
    background: linear-gradient(90deg, #2a2a2a 25%, #3a3a3a 50%, #2a2a2a 75%);
  }
}
```

```

---

## Plan 4: Error Boundaries

**Goal:** Prevent component crashes from breaking the entire app.

**Why:** If one component throws an error, currently the whole app crashes.

### Prompt for New Chat

```

I want to add React Error Boundaries to AstraDraw.

**Current Problem:**
If any component throws an error, the entire app crashes with a white screen.

**Task:**

1. Create `frontend/excalidraw-app/components/ErrorBoundary/`:

   - `ErrorBoundary.tsx` - class component that catches errors
   - `ErrorFallback.tsx` - UI shown when error occurs
   - `ErrorBoundary.scss` - styling

2. Wrap critical sections in App.tsx:

   - WorkspaceSidebar
   - Dashboard/Canvas content area
   - AppSidebar (right sidebar)

3. The fallback should:
   - Show a friendly error message
   - Have a "Try Again" button that resets the boundary
   - Match the app's theme (dark/light)

**Files to review:**

- @frontend/excalidraw-app/App.tsx
- @frontend/excalidraw-app/components/TopErrorBoundary.tsx (existing, for reference)

**Error Boundary pattern:**

```typescript
class ErrorBoundary extends React.Component<Props, State> {
  state = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error("ErrorBoundary caught:", error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <ErrorFallback
          error={this.state.error}
          onReset={() => this.setState({ hasError: false })}
        />
      );
    }
    return this.props.children;
  }
}
```

```

---

## Plan 5: Split WorkspaceSidebar ✅ COMPLETED

> **Completed:** 2025-12-23 - Split 1,235-line file into modular components and hooks

**Goal:** Break the 1,252-line WorkspaceSidebar into smaller, focused components.

**Result:** Created modular structure:

```
components/Workspace/WorkspaceSidebar/
├── index.ts                    # Re-export for backward compatibility
├── WorkspaceSidebar.tsx        # Slim orchestrator (~310 lines)
├── SidebarHeader.tsx           # Workspace selector dropdown
├── SidebarSearch.tsx           # Search input with keyboard shortcut
├── SidebarFooter.tsx           # User avatar and notifications
├── icons.tsx                   # Shared SVG icons
└── dialogs/
    ├── CreateCollectionDialog.tsx
    ├── EditCollectionDialog.tsx
    └── CreateWorkspaceDialog.tsx

hooks/
├── useWorkspaces.ts            # Workspace loading, switching, creating
├── useCollections.ts           # Collection CRUD operations
└── useSidebarScenes.ts         # Scene loading with caching
```

**Benefits:**
- Main orchestrator reduced from 1,235 to ~310 lines
- Reusable hooks for workspace, collection, and scene management
- Dialog components extracted for better testability
- Backward compatible - same export from `components/Workspace/`

```

---

## Plan 6: Split workspaceApi.ts ✅ COMPLETED

> **Completed:** 2025-12-23 - Split into modular auth/api/ structure

**Goal:** Organize the 1,634-line API file into logical modules.

**Result:** Created modular structure:

```
auth/api/
├── client.ts           # Base fetch wrapper with ApiError class
├── types.ts            # All TypeScript interfaces (~120 lines)
├── scenes.ts           # Scene CRUD, collaboration, thumbnails
├── talktracks.ts       # Talktrack recording management
├── users.ts            # User profile, avatar
├── workspaces.ts       # Workspace CRUD, avatar
├── members.ts          # Workspace member management
├── invites.ts          # Invite link management
├── teams.ts            # Team CRUD
├── collections.ts      # Collection CRUD, team access
└── index.ts            # Re-exports all functions and types

auth/workspaceApi.ts    # Backward compat: re-exports from api/
```

**Benefits:**
- Each domain file is focused (50-165 lines)
- Centralized error handling via `apiRequest()` helper
- `ApiError` class with HTTP status code
- Full backward compatibility via re-exports

---

## Plan 7: useCollections Hook

**Goal:** Create a Jotai-based hook for collections state.

**Why:** Collections are fetched in multiple places with duplicated logic.

### Prompt for New Chat

```

I want to create a useCollections hook similar to useScenesCache.

**Current Problem:**
Collections are fetched independently in:

- WorkspaceSidebar.tsx
- TeamsCollectionsPage.tsx
- CopyMoveDialog.tsx

**Task:**

1. Create `frontend/excalidraw-app/hooks/useCollections.ts`
2. Add collections cache atom to `settingsState.ts`:
   ```typescript
   export const collectionsCacheAtom = atom<Map<string, Collection[]>>(
     new Map()
   );
   ```
3. The hook should provide:

   - `collections: Collection[]`
   - `isLoading: boolean`
   - `refetch(): void`
   - `updateCollection(id, updates): void` - optimistic update
   - `deleteCollection(id): void` - optimistic update

4. Use stale-while-revalidate pattern (show cached, fetch fresh in background)

**Files to review:**

- @frontend/excalidraw-app/hooks/useScenesCache.ts (pattern to follow)
- @frontend/excalidraw-app/components/Settings/settingsState.ts
- @frontend/excalidraw-app/components/Workspace/WorkspaceSidebar.tsx (current collection loading)
- @frontend/excalidraw-app/auth/workspaceApi.ts (listCollections function)

**Expected usage:**

```typescript
const { collections, isLoading, refetch } = useCollections(workspaceId);
```

```

---

## Plan 8: useWorkspaces Hook

**Goal:** Centralize workspace data fetching and state.

**Why:** Workspace list is fetched in multiple places.

### Prompt for New Chat

```

I want to create a useWorkspaces hook for centralized workspace state.

**Current Problem:**
Workspace data is managed with local useState in WorkspaceSidebar.

**Task:**

1. Create `frontend/excalidraw-app/hooks/useWorkspaces.ts`
2. Add workspaces atom to `settingsState.ts`:
   ```typescript
   export const workspacesAtom = atom<Workspace[]>([]);
   export const currentWorkspaceAtom = atom<Workspace | null>(null);
   ```
3. The hook should provide:

   - `workspaces: Workspace[]`
   - `currentWorkspace: Workspace | null`
   - `isLoading: boolean`
   - `setCurrentWorkspace(workspace): void`
   - `createWorkspace(data): Promise<Workspace>`
   - `refetch(): void`

4. Persist current workspace selection to localStorage

**Files to review:**

- @frontend/excalidraw-app/hooks/useScenesCache.ts (pattern to follow)
- @frontend/excalidraw-app/components/Settings/settingsState.ts
- @frontend/excalidraw-app/components/Workspace/WorkspaceSidebar.tsx (current workspace handling)
- @frontend/excalidraw-app/auth/workspaceApi.ts (listWorkspaces function)

**Expected usage:**

```typescript
const { workspaces, currentWorkspace, setCurrentWorkspace, isLoading } =
  useWorkspaces();
```

```

---

## Plan 9: Optimistic Updates

**Goal:** Update UI immediately, then sync with server.

**Why:** Makes the app feel instant.

### Prompt for New Chat

```

I want to add optimistic updates to scene operations.

**Current Problem:**
When user deletes a scene:

1. Click delete → 2. Wait for API → 3. UI updates

**Goal:**

1. Click delete → 2. UI updates immediately → 3. API call in background
   ↓ If error: rollback + show toast

**Task:**

1. Update `useSceneActions` hook (or create if not exists) with optimistic updates
2. Implement for:

   - Delete scene
   - Rename scene
   - Duplicate scene (show placeholder, replace when API returns)

3. Add rollback on error with toast notification

**Pattern:**

```typescript
const deleteScene = async (sceneId: string) => {
  // 1. Save current state for rollback
  const previousScenes = [...scenes];

  // 2. Optimistic update
  updateScenesInCache((prev) => prev.filter((s) => s.id !== sceneId));

  try {
    // 3. API call
    await deleteSceneApi(sceneId);
    showSuccess("Scene deleted");
  } catch (err) {
    // 4. Rollback on error
    updateScenesInCache(() => previousScenes);
    showError("Failed to delete scene");
  }
};
```

**Files to review:**

- @frontend/excalidraw-app/hooks/useSceneActions.ts (if exists)
- @frontend/excalidraw-app/hooks/useScenesCache.ts
- @frontend/excalidraw-app/components/Settings/settingsState.ts

**Prerequisite:** Toast notifications should be implemented first (Plan 2)

```

---

## Plan 10: React Query Migration

**Goal:** Replace manual caching with React Query.

**Why:** React Query handles caching, background refresh, error states, and more.

### Prompt for New Chat

```

I want to migrate AstraDraw's data fetching to React Query (TanStack Query).

**Current Problem:**

- Manual caching with Jotai atoms and refs
- Duplicated loading/error state handling
- No automatic background refresh
- No request deduplication

**Task:**

1. Install: `cd frontend && yarn add @tanstack/react-query`
2. Add QueryClientProvider to App.tsx
3. Create query hooks in `frontend/excalidraw-app/hooks/queries/`:
   - `useWorkspacesQuery.ts`
   - `useCollectionsQuery.ts`
   - `useScenesQuery.ts`
4. Migrate one component at a time, starting with DashboardView

**React Query pattern:**

```typescript
// hooks/queries/useScenesQuery.ts
export function useScenesQuery(workspaceId: string, collectionId?: string) {
  return useQuery({
    queryKey: ["scenes", workspaceId, collectionId],
    queryFn: () => listWorkspaceScenes(workspaceId, collectionId),
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

// Usage in component
const {
  data: scenes,
  isLoading,
  error,
} = useScenesQuery(workspaceId, collectionId);
```

**Mutations:**

```typescript
export function useDeleteSceneMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: deleteSceneApi,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["scenes"] });
    },
  });
}
```

**Files to review:**

- @frontend/excalidraw-app/App.tsx
- @frontend/excalidraw-app/hooks/useScenesCache.ts (will be replaced)
- @frontend/excalidraw-app/components/Settings/settingsState.ts (cache atoms will be removed)
- @frontend/excalidraw-app/components/Workspace/DashboardView.tsx

**Note:** This is a bigger change. Consider doing Plans 1-4 first.

```

---

## Implementation Tips

### Before Starting Any Plan

1. Make sure `just dev` is running
2. Create a git branch: `git checkout -b feature/plan-name`
3. Read the files mentioned in the plan first

### After Completing a Plan

1. Run checks: `just check-frontend`
2. Test manually in browser
3. Commit your changes
4. Update this document if needed

### If You Get Stuck

- Ask the AI to explain the concept first before implementing
- Break the task into smaller steps
- Check existing patterns in the codebase

---

## Progress Tracker

| Plan | Status | Date | Notes |
|------|--------|------|-------|
| 1. useSceneActions | ✅ Completed | 2025-12-23 | Removed ~180 lines of duplicate code |
| 2. Toast Notifications | ✅ Completed | 2025-12-23 | Replaced 11 alert() calls, removed 5 duplicate showSuccess functions |
| 3. Loading Skeletons | ✅ Completed | 2025-12-23 | Added SceneCardSkeleton, CollectionItemSkeleton with shimmer animation |
| 4. Error Boundaries | ✅ Completed | 2025-12-23 | Added ErrorBoundary with context-specific fallbacks |
| 5. Split WorkspaceSidebar | ✅ Completed | 2025-12-23 | Reduced from 1,235 to ~310 lines |
| 6. Split workspaceApi.ts | ✅ Completed | 2025-12-23 | Split into auth/api/ modules (11 files) |
| 7. useCollections Hook | ✅ Completed | 2025-12-23 | Part of WorkspaceSidebar split |
| 8. useWorkspaces Hook | ✅ Completed | 2025-12-23 | Part of WorkspaceSidebar split |
| 9. Optimistic Updates | ✅ Completed | 2025-12-23 | Via useMutation with rollback on error |
| 10. React Query | ✅ Completed | 2025-12-23 | Full integration for scenes, workspaces, collections |

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-23 | Completed Plan 10: React Query integration |
| 2025-12-23 | Completed Plan 9: Optimistic updates with useMutation |
| 2025-12-23 | Implemented Plan 3: Loading Skeletons |
| 2025-12-23 | Implemented Plan 2: Toast Notifications |
| 2025-12-23 | Implemented Plan 1: useSceneActions hook |
| 2025-12-23 | Initial plans created |

```
