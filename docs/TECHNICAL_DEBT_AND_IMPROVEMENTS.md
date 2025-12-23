# AstraDraw Technical Debt & Improvement Opportunities

This document analyzes the AstraDraw-specific codebase (not upstream Excalidraw) and identifies areas for improvement. Use this as a guide for future refactoring and feature development.

## Overview

AstraDraw adds enterprise features on top of Excalidraw:
- User authentication (OIDC + local)
- Workspaces with scene management
- Collections and teams
- Talktrack video recordings
- Presentation mode
- Custom pens
- GIPHY/Stickers

The codebase has grown organically, and some patterns could be improved for maintainability and performance.

---

## 🔴 High Priority Issues

### 1. `WorkspaceSidebar.tsx` is Too Large (1,252 lines)

**Problem:** This single file handles:
- Workspace selection and management
- Collection CRUD operations
- Scene list and operations
- Search functionality
- Login dialog state
- Multiple context menus
- Keyboard shortcuts

**Impact:** Hard to maintain, test, and understand.

**Recommended Solution:**
```
components/Workspace/
├── WorkspaceSidebar/
│   ├── index.tsx              # Main orchestrator (~200 lines)
│   ├── WorkspaceSelector.tsx  # Workspace dropdown
│   ├── CollectionList.tsx     # Collections navigation
│   ├── SceneList.tsx          # Scene cards in sidebar
│   ├── SidebarSearch.tsx      # Search input
│   ├── SidebarFooter.tsx      # User menu, settings
│   ├── hooks/
│   │   ├── useWorkspaces.ts   # Workspace data fetching
│   │   ├── useCollections.ts  # Collection operations
│   │   └── useSceneActions.ts # Scene CRUD
│   └── WorkspaceSidebar.scss
```

**Effort:** Medium (2-3 days)

---

### 2. `App.tsx` is Massive (2,436 lines)

**Problem:** The main App component handles too many responsibilities:
- URL routing and navigation
- Scene loading and saving
- Collaboration setup
- Keyboard shortcuts
- Auto-save logic
- Multiple dialogs and modals

**Impact:** Changes risk breaking unrelated features. Hard to reason about.

**Recommended Solution:**
```
excalidraw-app/
├── App.tsx                    # Slim orchestrator (~300 lines)
├── AppProviders.tsx           # All providers wrapped
├── AppRouting.tsx             # URL handling
├── AppKeyboardShortcuts.tsx   # Keyboard handlers
├── hooks/
│   ├── useSceneLoader.ts      # Scene loading logic
│   ├── useAutoSave.ts         # Auto-save logic (already exists partially)
│   ├── useCollaboration.ts    # Collab setup
│   └── useAppNavigation.ts    # Navigation state
```

**Effort:** High (1 week)

---

### 3. Inconsistent State Management

**Problem:** The codebase uses multiple state patterns:
- Jotai atoms (navigation, sidebar, cache)
- React useState (most components)
- Refs for caching (WorkspaceSidebar)
- Props drilling (some places)

**Examples:**
```typescript
// Pattern 1: Jotai atom (good for shared state)
const workspaceSidebarOpen = useAtomValue(workspaceSidebarOpenAtom);

// Pattern 2: Local state with prop drilling
const [scenes, setScenes] = useState<WorkspaceScene[]>([]);
// Then passed down through 3 component levels

// Pattern 3: Ref for caching (inconsistent with Jotai cache)
const scenesCacheRef = useRef<Map<string, WorkspaceScene[]>>(new Map());
```

**Recommended Solution:**
1. **Document when to use what** (done in STATE_MANAGEMENT.md)
2. **Migrate more shared state to Jotai** - workspaces, collections, current user
3. **Use the new `useScenesCache` hook consistently** across all components

**Effort:** Medium (ongoing)

---

### 4. `workspaceApi.ts` is Too Large (1,634 lines)

**Problem:** Single file with all API functions. No error handling abstraction.

**Recommended Solution:**
```
auth/
├── api/
│   ├── client.ts              # Base fetch wrapper with error handling
│   ├── workspaces.ts          # Workspace CRUD
│   ├── collections.ts         # Collection CRUD
│   ├── scenes.ts              # Scene CRUD
│   ├── teams.ts               # Team CRUD
│   ├── members.ts             # Member management
│   ├── invites.ts             # Invite links
│   └── index.ts               # Re-exports all
├── types.ts                   # All TypeScript interfaces
└── hooks/
    ├── useWorkspaces.ts       # React Query/SWR wrapper
    ├── useCollections.ts
    └── useScenes.ts
```

**Effort:** Medium (2-3 days)

---

## 🟡 Medium Priority Issues

### 5. No Data Fetching Library

**Problem:** All API calls are manual `fetch()` with duplicated error handling.

**Current Pattern:**
```typescript
const loadScenes = async () => {
  setIsLoading(true);
  try {
    const data = await listWorkspaceScenes(workspaceId);
    setScenes(data);
  } catch (err) {
    console.error("Failed to load:", err);
  } finally {
    setIsLoading(false);
  }
};
```

**Recommended Solution:** Use **React Query** or **SWR**:
```typescript
const { data: scenes, isLoading, error } = useQuery(
  ['scenes', workspaceId, collectionId],
  () => listWorkspaceScenes(workspaceId, collectionId),
  { staleTime: 5 * 60 * 1000 }
);
```

**Benefits:**
- Automatic caching (replaces our manual cache)
- Background refetching
- Error/loading states built-in
- Request deduplication
- Optimistic updates

**Effort:** High (1 week) - but big long-term payoff

---

### 6. Duplicate Scene Operations in Multiple Components

**Problem:** Delete/Rename/Duplicate scene logic is duplicated in:
- `WorkspaceSidebar.tsx`
- `DashboardView.tsx`
- `CollectionView.tsx`
- `SceneCard.tsx`

**Recommended Solution:** Create a single hook:
```typescript
// hooks/useSceneActions.ts
export function useSceneActions(options: { onSuccess?: () => void }) {
  const triggerRefresh = useSetAtom(triggerScenesRefreshAtom);
  
  const deleteScene = async (sceneId: string) => {
    if (!confirm(t("workspace.confirmDeleteScene"))) return;
    await deleteSceneApi(sceneId);
    triggerRefresh();
    options.onSuccess?.();
  };
  
  const renameScene = async (sceneId: string, newTitle: string) => {
    await updateSceneApi(sceneId, { title: newTitle });
    triggerRefresh();
  };
  
  const duplicateScene = async (sceneId: string) => {
    const newScene = await duplicateSceneApi(sceneId);
    triggerRefresh();
    return newScene;
  };
  
  return { deleteScene, renameScene, duplicateScene };
}
```

**Effort:** Low (1 day)

---

### 7. No Loading Skeletons

**Problem:** Components show empty space or spinners while loading.

**Recommended Solution:** Add skeleton components:
```typescript
// components/Skeletons/SceneCardSkeleton.tsx
export const SceneCardSkeleton = () => (
  <div className="scene-card scene-card--skeleton">
    <div className="scene-card__thumbnail skeleton-shimmer" />
    <div className="scene-card__title skeleton-shimmer" />
  </div>
);

// Usage
{isLoading ? (
  <>
    <SceneCardSkeleton />
    <SceneCardSkeleton />
    <SceneCardSkeleton />
  </>
) : (
  scenes.map(scene => <SceneCard key={scene.id} scene={scene} />)
)}
```

**Effort:** Low (1-2 days)

---

### 8. No Optimistic Updates

**Problem:** After deleting a scene, user waits for API response before UI updates.

**Current Flow:**
```
User clicks delete → API call → Wait... → UI updates
```

**Recommended Flow:**
```
User clicks delete → UI updates immediately → API call in background
                                            ↓
                              If error: Rollback UI + show error
```

**Implementation:**
```typescript
const deleteScene = async (sceneId: string) => {
  // Optimistic update
  const previousScenes = scenes;
  updateScenes(prev => prev.filter(s => s.id !== sceneId));
  
  try {
    await deleteSceneApi(sceneId);
  } catch (err) {
    // Rollback on error
    updateScenes(previousScenes);
    toast.error("Failed to delete scene");
  }
};
```

**Effort:** Medium (2 days)

---

### 9. Missing Error Boundaries

**Problem:** If a component crashes, the whole app crashes.

**Recommended Solution:**
```typescript
// components/ErrorBoundary.tsx
<ErrorBoundary fallback={<ErrorFallback />}>
  <WorkspaceSidebar />
</ErrorBoundary>

<ErrorBoundary fallback={<DashboardErrorFallback />}>
  <DashboardView />
</ErrorBoundary>
```

**Effort:** Low (1 day)

---

### 10. No Toast Notifications

**Problem:** Errors shown via `alert()`, success not shown at all.

**Recommended Solution:** Add toast library (react-hot-toast or similar):
```typescript
import toast from 'react-hot-toast';

// On success
toast.success("Scene deleted");

// On error
toast.error("Failed to delete scene");

// Loading state
toast.promise(deleteSceneApi(sceneId), {
  loading: 'Deleting...',
  success: 'Scene deleted',
  error: 'Failed to delete',
});
```

**Effort:** Low (1 day)

---

## 🟢 Low Priority / Nice to Have

### 11. No Unit Tests for Custom Components

**Problem:** Only upstream Excalidraw tests exist. No tests for:
- WorkspaceSidebar
- DashboardView
- CollectionView
- useScenesCache hook

**Recommended:** Add tests for critical paths:
- Scene CRUD operations
- Navigation between views
- Authentication flow

**Effort:** Medium (ongoing)

---

### 12. CSS Could Use CSS Modules or Styled Components

**Problem:** Global SCSS files can have naming conflicts.

**Current:**
```scss
// WorkspaceSidebar.scss
.workspace-sidebar { ... }
.workspace-sidebar__header { ... }
```

**Alternative:** CSS Modules
```scss
// WorkspaceSidebar.module.scss
.sidebar { ... }
.header { ... }

// Component
import styles from './WorkspaceSidebar.module.scss';
<div className={styles.sidebar}>
```

**Effort:** High (not recommended unless refactoring anyway)

---

### 13. No Internationalization for AstraDraw-Specific Strings

**Problem:** Some strings are hardcoded in Russian, some in English.

**Files to check:**
- Settings pages
- Workspace components
- Error messages

**Effort:** Medium (2-3 days)

---

### 14. Backend API Could Return More Efficient Payloads

**Problem:** Some endpoints return more data than needed.

**Example:** `listWorkspaceScenes` returns full scene objects when we only need:
- id, title, thumbnailUrl, updatedAt, collectionId

**Solution:** Add `?fields=id,title,thumbnailUrl,updatedAt` query param support.

**Effort:** Medium (backend + frontend changes)

---

## 📋 Recommended Improvement Order

### Phase 1: Quick Wins (1-2 weeks)
1. ✅ Add scenes cache (done)
2. Create `useSceneActions` hook to deduplicate code
3. Add toast notifications
4. Add loading skeletons
5. Add error boundaries

### Phase 2: Architecture (2-4 weeks)
1. Split `WorkspaceSidebar.tsx` into smaller components
2. Split `workspaceApi.ts` into modules
3. Migrate more state to Jotai atoms

### Phase 3: Advanced (1-2 months)
1. Add React Query for data fetching
2. Split `App.tsx` into smaller modules
3. Add optimistic updates
4. Add unit tests

---

## 🎯 Key Principles to Follow

### 1. Single Responsibility
Each component/file should do ONE thing well.
- ❌ `WorkspaceSidebar.tsx` (1,252 lines, does everything)
- ✅ `SceneList.tsx` (100 lines, just renders scene list)

### 2. Colocate Related Code
Keep related code together.
```
components/Workspace/
├── SceneCard/
│   ├── SceneCard.tsx
│   ├── SceneCard.scss
│   ├── SceneCard.test.tsx
│   └── index.ts
```

### 3. Lift State Appropriately
- **Local state:** Form inputs, UI toggles
- **Jotai atoms:** Shared across components, needs persistence
- **React Query:** Server state (API data)

### 4. DRY (Don't Repeat Yourself)
Extract common patterns into hooks:
```typescript
// Instead of duplicating in 4 components:
const { deleteScene, renameScene } = useSceneActions();
```

### 5. Fail Gracefully
- Error boundaries catch crashes
- Toast notifications inform users
- Optimistic updates with rollback

---

## Related Documentation

- [STATE_MANAGEMENT.md](STATE_MANAGEMENT.md) - When to use Jotai vs useState
- [SCENES_CACHE.md](SCENES_CACHE.md) - How the scenes cache works
- [ARCHITECTURE.md](ARCHITECTURE.md) - Overall system architecture

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-23 | Initial analysis and documentation |

