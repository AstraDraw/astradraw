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

### 2. ✅ RESOLVED: `App.tsx` Split into Focused Hooks

> **Resolved:** 2025-12-23 - Extracted logic into 5 focused hooks, reducing App.tsx from 2,473 to ~1,900 lines

**Was:** Single file handling URL routing, scene loading, autosave, keyboard shortcuts, workspace data, and rendering.

**Fix:** Created focused hooks:

```
excalidraw-app/hooks/
├── useAutoSave.ts           # Save state machine, debounce, retry, offline detection (~230 lines)
├── useSceneLoader.ts        # Scene loading from workspace URLs, auto-collab (~250 lines)
├── useUrlRouting.ts         # Popstate handling, URL parsing (~120 lines)
├── useKeyboardShortcuts.ts  # Ctrl+S, Cmd+P, Cmd+[, Cmd+] (~130 lines)
└── useWorkspaceData.ts      # Workspace/collections loading (~150 lines)
```

**Benefits:**
- Each hook has single responsibility
- App.tsx is now an orchestrator that wires hooks together
- Logic is testable in isolation
- Easier to understand and maintain

---

### 3. ✅ RESOLVED: Inconsistent State Management

> **Resolved:** 2025-12-23 - Migrated workspace and collections data to Jotai atoms

**Was:** Workspace and collections data was managed inconsistently with useState and prop drilling across multiple components.

**Fix:** Created centralized Jotai atoms for shared state:

```
settingsState.ts additions:
├── workspacesAtom           # List of all user workspaces
├── currentWorkspaceAtom     # Currently active workspace
├── collectionsAtom          # Collections for current workspace
├── privateCollectionAtom    # Derived: private collection
├── activeCollectionAtom     # Derived: currently selected collection
└── clearWorkspaceDataAtom   # Action: clear on logout
```

**Changes made:**
- Added 6 new atoms to `settingsState.ts`
- Updated `useWorkspaces` hook to use atoms instead of useState
- Updated `useCollections` hook to use atoms instead of useState
- Removed `useWorkspaceData` hook (functionality merged into other hooks)
- Updated 7 components to read from atoms directly:
  - `WorkspaceMainContent.tsx` - removed workspace/collections props
  - `DashboardView.tsx` - removed workspace prop
  - `CollectionView.tsx` - removed workspace prop
  - `SearchResultsView.tsx` - removed workspace prop
  - `FullModeNav.tsx` - removed collections/activeCollectionId props
  - `SidebarHeader.tsx` - removed currentWorkspace/workspaces props
  - `App.tsx` - simplified prop passing

**Benefits:**
- Single source of truth for workspace/collections data
- No prop drilling - components read directly from atoms
- Better performance - only components using specific atoms re-render
- Simpler component interfaces - fewer props to manage

---

### 4. ✅ RESOLVED: `workspaceApi.ts` Split into Modular API Structure

> **Resolved:** 2025-12-23 - Split 1,634-line file into domain-specific modules

**Was:** Single file with all API functions and duplicated error handling patterns.

**Fix:** Created modular structure with centralized error handling:

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
- Each domain file is focused (~60-150 lines each)
- Centralized error handling via `apiRequest()` helper
- `ApiError` class with status code for better error handling
- Full backward compatibility - existing imports unchanged
- Better tree-shaking potential

---

## 🟡 Medium Priority Issues

### 5. ✅ RESOLVED: Data Fetching Library (React Query)

> **Resolved:** 2025-12-23 - Added TanStack React Query v5 for data fetching

**Was:** All API calls were manual `fetch()` with duplicated error handling and custom caching.

**Fix:** Integrated TanStack React Query v5:

```
lib/
├── queryClient.ts       # QueryClient with defaults + query key factory
└── index.ts             # Re-exports

hooks/
├── useScenesCache.ts    # Rewritten with useQuery
├── useWorkspaces.ts     # Updated to use useQuery
├── useCollections.ts    # Updated to use useQuery
└── useSceneActions.ts   # Updated to use queryClient.invalidateQueries
```

**Key changes:**

- Installed `@tanstack/react-query` package
- Created `lib/queryClient.ts` with centralized QueryClient and type-safe query keys
- Added `QueryClientProvider` to `index.tsx`
- Rewrote `useScenesCache` to use `useQuery` (replaces 2 custom cache implementations)
- Updated `useWorkspaces` and `useCollections` to use React Query for fetching
- Removed manual cache atoms from `settingsState.ts`:
  - `scenesCacheAtom`, `setScenesCacheAtom`, `invalidateScenesCacheAtom`, `clearScenesCacheAtom`
  - `scenesRefreshAtom`, `triggerScenesRefreshAtom`
- Deleted redundant `useSidebarScenes.ts` hook

**Benefits:**

- Automatic caching with 5-minute stale time
- Request deduplication (multiple components share one request)
- Background refetching on window focus
- Simplified hooks - no manual loading/error state management
- Foundation for optimistic updates (tech debt item #8)

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

### 8. ✅ RESOLVED: Optimistic Updates

> **Resolved:** 2025-12-23 - Implemented optimistic updates using React Query's `useMutation`

**Was:** After deleting a scene, user waited for API response before UI updates.

**Fix:** Rewrote `useSceneActions` hook to use React Query's `useMutation` with optimistic updates:

```typescript
// Delete mutation with optimistic update
const deleteMutation = useMutation({
  mutationFn: deleteSceneApi,
  onMutate: async (sceneId) => {
    // Cancel outgoing refetches
    await queryClient.cancelQueries({ queryKey });
    // Snapshot previous value
    const previousScenes = queryClient.getQueryData(queryKey);
    // Optimistically remove scene
    queryClient.setQueryData(queryKey, (old) => old.filter((s) => s.id !== sceneId));
    return { previousScenes };
  },
  onError: (err, sceneId, context) => {
    // Rollback on error
    queryClient.setQueryData(queryKey, context.previousScenes);
    showError("Failed to delete scene");
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: queryKeys.scenes.all });
  },
});
```

**Changes made:**
- Rewrote `useSceneActions` hook with 3 `useMutation` hooks (delete, rename, duplicate)
- Delete and rename use optimistic updates with rollback
- Duplicate shows success toast (no optimistic update - needs server response for new ID)
- Updated interface: `workspaceId`/`collectionId` instead of `updateScenes` callback
- Added `isDeleting`, `isRenaming`, `isDuplicating` loading states
- Added mutation keys to `lib/queryClient.ts`

**Benefits:**
- UI updates immediately when user performs action
- Automatic rollback on API error
- Toast notifications for success/error
- Cleaner interface - components don't need to pass `updateScenes`

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

### 11. ✅ RESOLVED: Unit Tests for Custom Components

> **Resolved:** 2025-12-23 - Added unit tests for critical hooks and API client

**Was:** Only upstream Excalidraw tests existed. No tests for AstraDraw-specific code.

**Fix:** Created comprehensive test suite:

```
excalidraw-app/tests/
├── testUtils.tsx              # Test utilities for React Query
├── api/
│   └── client.test.ts         # API client tests (22 tests)
└── hooks/
    ├── useSceneActions.test.tsx   # Scene CRUD tests (16 tests)
    └── useScenesCache.test.tsx    # Data fetching tests (13 tests)
```

**Tests cover:**
- API client error handling (ApiError, status codes, helpers)
- Scene CRUD operations (delete, rename, duplicate)
- Optimistic updates and rollback behavior
- React Query caching and invalidation
- Loading states and error handling

**Total:** 51 new tests passing

---

### 12. ✅ RESOLVED: CSS Modules Pilot Migration

> **Resolved:** 2025-12-23 - Pilot migration of 3 components to CSS Modules

**Was:** All SCSS files were global with BEM naming conventions, risking naming conflicts.

**Fix:** Migrated 3 pilot components to CSS Modules to establish patterns:

```
components/Skeletons/
├── Skeleton.module.scss      # Shimmer animation, dark mode
├── SceneCardSkeleton.tsx     # Uses styles.sceneCardSkeleton
└── CollectionItemSkeleton.tsx

components/ErrorBoundary/
├── ErrorBoundary.module.scss # Fallback styles, variants
├── ErrorBoundary.tsx
├── SidebarErrorFallback.tsx
├── ContentErrorFallback.tsx
└── GenericErrorFallback.tsx

components/SaveStatusIndicator/
├── SaveStatusIndicator.module.scss  # Status colors, animations
└── SaveStatusIndicator.tsx
```

**Key patterns established:**

1. **Dark mode** - Use `:global()` for theme selectors:
   ```scss
   :global(.excalidraw.theme--dark),
   :global(.excalidraw-app.theme--dark) {
     .container { ... }
   }
   ```

2. **Animations** - Keyframes are locally scoped automatically

3. **Class composition** - Use template literals for multiple classes:
   ```typescript
   className={`${styles.status} ${styles.statusSaved}`}
   ```

4. **Type safety** - Added declarations to `vite-env.d.ts`:
   ```typescript
   declare module "*.module.scss" {
     const classes: { readonly [key: string]: string };
     export default classes;
   }
   ```

**Benefits:**
- Guaranteed class name uniqueness
- Better IDE autocomplete for styles
- Clear dependency between component and styles
- Foundation for broader migration if desired

**Remaining:** 38 global SCSS files in `excalidraw-app/` (optional future migration)

#### Full Migration Guide (If Proceeding)

If you decide to migrate all 38 remaining SCSS files, follow these guidelines:

**Migration Order (by complexity):**

1. **Simple components first** - Small files with no dark mode or animations
   - `AstradrawLogo.scss`, `AppFooter.scss`, `WelcomeScreenBackground.scss`

2. **Settings pages** - Self-contained, rarely change
   - `ProfilePage.scss`, `PreferencesPage.scss`, `MembersPage.scss`, etc.

3. **Workspace components** - Core UI, test thoroughly
   - `SceneCard.scss`, `DashboardView.scss`, `CollectionView.scss`

4. **Complex components last** - Large files with many interactions
   - `WorkspaceSidebar.scss` (835 lines), `FullModeNav.scss`, `LoginDialog.scss`

**Checklist per component:**

```markdown
- [ ] Rename `Component.scss` → `Component.module.scss`
- [ ] Convert BEM names to camelCase (`.scene-card__title` → `.title`)
- [ ] Wrap dark mode selectors with `:global()`
- [ ] Update component imports: `import styles from "./Component.module.scss"`
- [ ] Replace className strings with `styles.className`
- [ ] Test light mode
- [ ] Test dark mode
- [ ] Run `just check-frontend`
```

**Common patterns to handle:**

| Pattern | Before (Global) | After (CSS Modules) |
|---------|-----------------|---------------------|
| BEM element | `.card__title` | `.title` |
| BEM modifier | `.card--active` | `.cardActive` or separate `.active` |
| Dark mode | `.theme--dark .card` | `:global(.theme--dark) .card` |
| Pseudo-class | `.card:hover` | `.card:hover` (unchanged) |
| Nested hover | `.card:hover .title` | `.card:hover .title` (unchanged) |
| Animation | `@keyframes spin` | `@keyframes spin` (auto-scoped) |

**Potential issues to watch:**

1. **Cross-component styling** - If `ComponentA.scss` styles elements inside `ComponentB`, you'll need to either:
   - Move those styles to `ComponentB.module.scss`
   - Use `:global()` for the cross-component selectors
   - Pass className as prop

2. **Dynamic class names** - If you build class names dynamically:
   ```typescript
   // Before (won't work with modules)
   className={`scene-card scene-card--${status}`}
   
   // After (use object lookup)
   const statusClasses = { active: styles.active, pending: styles.pending };
   className={`${styles.card} ${statusClasses[status]}`}
   ```

3. **Third-party component styling** - Use `:global()` when overriding library styles

4. **CSS cascade order** - Dev and prod builds may order styles differently. If you see inconsistent styling, consider adding `@layer` declarations for explicit cascade control.

**Estimated effort:** 2-3 days for full migration (38 files)

**Recommendation:** Only proceed if you're experiencing actual naming conflicts or need the tree-shaking benefits. The current BEM approach works fine for most cases.

---

### 13. ✅ RESOLVED: Internationalization for AstraDraw-Specific Strings

> **Resolved:** 2025-12-23 - Audited and fixed hardcoded strings across components

**Was:** Some UI strings were hardcoded in English without translation keys.

**Fix:** Added missing translation keys and replaced hardcoded strings:

**New translation keys added:**
- `workspace.moreOptions` - "More options" / "Ещё"
- `workspace.notSet` - "Not set" / "Не указано"
- `comments.promoTitle` - "Make comments with AstraDraw" / "Комментируйте с AstraDraw"
- `comments.comingSoon` - "Coming soon" / "Скоро"

**Components updated:**
- `ErrorBoundary.tsx` - Uses `t("errorBoundary.genericMessage")` and `t("errorBoundary.retry")`
- `UserProfileDialog.tsx` - Replaced 8 hardcoded strings with translation keys
- `AppSidebar.tsx` - Comments promo text now uses translation keys
- `SceneCard.tsx` - Tooltips use `t("workspace.private")` and `t("workspace.moreOptions")`
- `SceneCardGrid.tsx` - Same tooltip updates

**Benefits:**
- Full Russian translation support for all AstraDraw UI
- Consistent use of `t()` function across components
- Removed fallback strings (e.g., `t("key") || "Fallback"`)

---

### 14. Backend API Could Return More Efficient Payloads

**Problem:** Some endpoints return more data than needed.

**Example:** `listWorkspaceScenes` returns full scene objects when we only need:

- id, title, thumbnailUrl, updatedAt, collectionId

**Solution:** Add `?fields=id,title,thumbnailUrl,updatedAt` query param support.

**Effort:** Medium (backend + frontend changes)

---

### 15. ✅ RESOLVED: Excalidraw Test Failures Caused by AstraDraw Changes

> **Resolved:** 2025-12-23 - Fixed test infrastructure and updated snapshots

**Was:** 140 tests failing (12% failure rate) due to missing providers and snapshot drift.

**Root causes fixed:**

1. **React Query integration** - Tests rendering `ExcalidrawApp` needed `QueryClientProvider`
2. **Snapshot drift** - UI changes (AstraDraw logo, custom components) caused snapshot mismatches

**Fix:** Created `renderExcalidrawApp()` wrapper in `excalidraw-app/tests/testUtils.tsx`:

```typescript
export async function renderExcalidrawApp() {
  const queryClient = createTestQueryClient();
  return await rtlRender(
    <QueryClientProvider client={queryClient}>
      <ExcalidrawApp />
    </QueryClientProvider>,
  );
}
```

**Files updated:**
- `excalidraw-app/tests/testUtils.tsx` - Added `renderExcalidrawApp()` wrapper
- `excalidraw-app/tests/LanguageList.test.tsx` - Uses new wrapper, updated assertions
- `excalidraw-app/tests/MobileMenu.test.tsx` - Uses new wrapper
- `excalidraw-app/tests/collab.test.tsx` - Uses new wrapper
- `excalidraw-app/tests/hooks/useSceneActions.test.tsx` - Fixed i18n mock to use `importOriginal`
- 134 snapshot files updated

**Test results after fix:**
- **All tests passing:** 1,083 passed | 46 skipped | 1 todo (1,130 total)
- **Test files:** 92 passed (92)

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
2. ✅ Split `workspaceApi.ts` into modules (done 2025-12-23)
3. ✅ Split `App.tsx` into focused hooks (done 2025-12-23)
4. ✅ Migrate more state to Jotai atoms (done 2025-12-23)

### Phase 3: Advanced (1-2 months)

1. ✅ Add React Query for data fetching (done 2025-12-23)
2. ✅ Add optimistic updates (done 2025-12-23)
3. ✅ Add unit tests (done 2025-12-23)

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
| 2025-12-23 | Fixed all test failures (140 tests), updated 134 snapshots |
| 2025-12-23 | Fixed localStorage mock, documented remaining test issues |
| 2025-12-23 | CSS Modules pilot migration (3 components)  |
| 2025-12-23 | Fixed internationalization for UI strings   |
| 2025-12-23 | Added unit tests for hooks and API client   |
| 2025-12-23 | Added optimistic updates to scene actions   |
| 2025-12-23 | Added React Query for data fetching         |
| 2025-12-23 | Migrated workspace/collections to Jotai     |
| 2025-12-23 | Split App.tsx into 5 focused hooks          |
| 2025-12-23 | Split workspaceApi.ts into modular API      |
| 2025-12-23 | Split WorkspaceSidebar.tsx into components  |
| 2025-12-23 | Marked Error Boundaries as resolved         |
| 2025-12-23 | Marked Loading Skeletons as resolved        |
| 2025-12-23 | Marked Toast Notifications as resolved      |
| 2025-12-23 | Marked useSceneActions hook as resolved     |
| 2025-12-23 | Initial analysis and documentation          |
