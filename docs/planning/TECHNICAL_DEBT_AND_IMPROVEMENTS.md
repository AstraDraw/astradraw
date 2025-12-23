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

### 1. ✅ RESOLVED: `WorkspaceSidebar.tsx` Split into Smaller Components

> **Resolved:** 2025-12-23 - Split 1,235-line file into modular components and hooks

**Was:** Single file handling workspace management, collection CRUD, scene loading, search, dialogs, and UI orchestration.

**Fix:** Created modular structure:

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
const {
  data: scenes,
  isLoading,
  error,
} = useQuery(
  ["scenes", workspaceId, collectionId],
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

### 6. ✅ RESOLVED: Duplicate Scene Operations in Multiple Components

> **Resolved:** 2025-12-23 - Implemented `useSceneActions` hook

**Was:** Delete/Rename/Duplicate scene logic was duplicated in 4 files (~180 lines of duplicate code).

**Fix:** Created `hooks/useSceneActions.ts` hook that provides:

- `deleteScene(sceneId)` - with confirmation dialog
- `renameScene(sceneId, newTitle)` - with optional callback for title updates
- `duplicateScene(sceneId)` - returns the new scene

**Usage:**

```typescript
const { deleteScene, renameScene, duplicateScene } = useSceneActions({
  updateScenes,
  onSceneRenamed: (sceneId, newTitle) => {
    /* optional callback */
  },
});
```

**Files updated:**

- `DashboardView.tsx` - removed ~45 lines
- `CollectionView.tsx` - removed ~45 lines
- `SearchResultsView.tsx` - removed ~45 lines
- `WorkspaceSidebar.tsx` - removed ~55 lines

---

### 7. ✅ RESOLVED: Loading Skeletons

> **Resolved:** 2025-12-23 - Implemented skeleton loading components

**Was:** Components showed empty space or spinners while loading.

**Fix:** Created skeleton components in `components/Skeletons/`:

- `SceneCardSkeleton.tsx` - Matches SceneGridCard dimensions (260px min-width, 16:10 thumbnail)
- `CollectionItemSkeleton.tsx` - Matches FullModeNav collection item dimensions
- `Skeleton.scss` - Base shimmer animation with dark mode support

**Usage:**

```typescript
import { SceneCardSkeletonGrid, CollectionItemSkeletonList } from "../Skeletons";

// In DashboardView/CollectionView:
if (isLoading) {
  return <SceneCardSkeletonGrid count={6} />;
}

// In FullModeNav:
{isCollectionsLoading ? (
  <CollectionItemSkeletonList count={4} />
) : (
  collections.map((c) => <CollectionItem key={c.id} collection={c} />)
)}
```

**Files updated:**
- `DashboardView.tsx` - Uses `SceneCardSkeletonGrid`
- `CollectionView.tsx` - Uses `SceneCardSkeletonGrid`
- `FullModeNav.tsx` - Uses `CollectionItemSkeletonList`
- `WorkspaceSidebar.tsx` - Added `isCollectionsLoading` state

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
  updateScenes((prev) => prev.filter((s) => s.id !== sceneId));

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

### 9. ✅ RESOLVED: Missing Error Boundaries

> **Resolved:** 2025-12-23 - Implemented granular error boundaries for key components

**Was:** If a component crashed, the whole app showed the error splash page.

**Fix:** Created reusable ErrorBoundary component with context-specific fallbacks:

```
components/ErrorBoundary/
├── index.ts                    # Exports
├── ErrorBoundary.tsx           # Main class component with reset capability
├── ErrorBoundary.scss          # Styles with dark mode support
├── SidebarErrorFallback.tsx    # Compact fallback for sidebar
├── ContentErrorFallback.tsx    # Fallback for main content area
└── GenericErrorFallback.tsx    # Reusable generic fallback
```

**Usage:**

```typescript
import { ErrorBoundary, SidebarErrorFallback } from "./components/ErrorBoundary";

<ErrorBoundary
  fallback={(props) => <SidebarErrorFallback {...props} />}
  onError={(error) => console.error("[WorkspaceSidebar] Error:", error)}
>
  <WorkspaceSidebar />
</ErrorBoundary>
```

**Components wrapped:**
- `WorkspaceSidebar` - Uses `SidebarErrorFallback`
- `WorkspaceMainContent` - Uses `ContentErrorFallback` with "Go Home" action

**Features:**
- Reset capability (retry button)
- Dark mode support
- Error details expandable
- Translation keys in `en.json` and `ru-RU.json`

---

### 10. ✅ RESOLVED: No Toast Notifications

> **Resolved:** 2025-12-23 - Implemented toast notification system using `react-hot-toast`

**Was:** Errors shown via `alert()`, success not shown at all.

**Fix:** Created centralized toast utility at `excalidraw-app/utils/toast.ts`:

```typescript
import { showSuccess, showError, showLoading } from "../../utils/toast";

// On success
showSuccess(t("workspace.sceneDeleted"));

// On error
showError(t("workspace.deleteSceneError"));

// Loading state (for async operations)
showLoading(deleteSceneApi(sceneId), {
  loading: "Deleting...",
  success: "Scene deleted",
  error: "Failed to delete",
});
```

**Changes made:**

- Installed `react-hot-toast` package
- Created `utils/toast.ts` with `showSuccess`, `showError`, `showLoading`
- Added `<Toaster />` to App.tsx with dark/light theme support
- Replaced 11 `alert()` calls across 5 files
- Removed 5 duplicated local `showSuccess()` functions
- Added translation keys for collection errors

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
2. ✅ Create `useSceneActions` hook to deduplicate code (done 2025-12-23)
3. ✅ Add toast notifications (done 2025-12-23)
4. ✅ Add loading skeletons (done 2025-12-23)
5. ✅ Add error boundaries (done 2025-12-23)

### Phase 2: Architecture (2-4 weeks)

1. ✅ Split `WorkspaceSidebar.tsx` into smaller components (done 2025-12-23)
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

- ❌ Large monolithic files (1,000+ lines)
- ✅ Small focused components (100-300 lines)

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

- [STATE_MANAGEMENT.md](../architecture/STATE_MANAGEMENT.md) - When to use Jotai vs useState
- [SCENES_CACHE.md](SCENES_CACHE.md) - How the scenes cache works
- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - Overall system architecture

---

## Changelog

| Date       | Changes                                     |
| ---------- | ------------------------------------------- |
| 2025-12-23 | Split WorkspaceSidebar.tsx into components  |
| 2025-12-23 | Marked Error Boundaries as resolved         |
| 2025-12-23 | Marked Loading Skeletons as resolved        |
| 2025-12-23 | Marked Toast Notifications as resolved      |
| 2025-12-23 | Marked useSceneActions hook as resolved     |
| 2025-12-23 | Initial analysis and documentation          |
