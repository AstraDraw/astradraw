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

### 11b. 🔵 FUTURE: Backend Unit Tests

> **Status:** Not started - Add when implementing new backend features

**Current state:** Backend has only a placeholder e2e test. No unit tests for services.

**Recommended approach:** Add unit tests for NestJS services using Jest with mocked Prisma:

```
backend/src/comments/
├── comments.service.spec.ts    # Unit tests for CommentsService
└── comments.controller.spec.ts # Controller tests (optional)
```

**Pattern to follow:**
```typescript
// comments.service.spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { CommentsService } from './comments.service';
import { PrismaService } from '../prisma/prisma.service';
import { SceneAccessService } from '../workspace/scene-access.service';

describe('CommentsService', () => {
  let service: CommentsService;
  let prisma: jest.Mocked<PrismaService>;
  let sceneAccess: jest.Mocked<SceneAccessService>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CommentsService,
        { provide: PrismaService, useValue: { commentThread: {}, comment: {} } },
        { provide: SceneAccessService, useValue: { checkAccess: jest.fn() } },
      ],
    }).compile();

    service = module.get<CommentsService>(CommentsService);
    prisma = module.get(PrismaService);
    sceneAccess = module.get(SceneAccessService);
  });

  it('should create a thread with first comment', async () => {
    // Test implementation
  });
});
```

**Priority:** Add tests when:
- Implementing complex business logic
- Fixing bugs (write test first to reproduce)
- Before major refactoring

---

### 12. 🟡 IN PROGRESS: CSS Modules Migration with Component Folder Reorganization

> **Started:** 2025-12-23 - Full migration with component folder structure
> **Status:** Batch 1-4 complete + WorkspaceSidebar (31 components migrated), 7 remaining

**Goal:** Migrate all 38 global SCSS files to CSS Modules while reorganizing into component folders following modern React best practices.

#### What's Been Done

**Phase 0: Shared Styles Infrastructure** ✅

Created `excalidraw-app/styles/` directory with reusable SCSS:

```
styles/
├── _variables.scss    # $ui-font, spacing vars ($spacing-xs, etc.)
├── _mixins.scss       # @mixin dark-mode, @mixin within-excalidraw
├── _animations.scss   # shimmer, fadeIn, spin keyframes
└── index.scss         # Re-exports all
```

**Key mixin - Dark mode wrapper:**
```scss
// Usage: @include dark-mode { .card { background: #232329; } }
@mixin dark-mode {
  :global(.excalidraw.theme--dark),
  :global(.excalidraw-app.theme--dark) {
    @content;
  }
}
```

**Batch 1: Simple Components** ✅ (8 files migrated)

| Component | Old Location | New Location |
|-----------|--------------|--------------|
| AstradrawLogo | `components/AstradrawLogo.tsx` | `components/AstradrawLogo/` |
| AppFooter | `components/AppFooter.tsx` | `components/AppFooter/` |
| AppSidebar | `components/AppSidebar.tsx` | `components/AppSidebar/` |
| CollabError | `collab/CollabError.tsx` | `collab/CollabError/` |
| PenToolbar | `pens/PenToolbar.tsx` | `pens/PenToolbar/` |
| WorkspaceMainContent | `Workspace/WorkspaceMainContent.tsx` | `Workspace/WorkspaceMainContent/` |
| WorkspaceSidebarTrigger | `Workspace/WorkspaceSidebarTrigger.tsx` | `Workspace/WorkspaceSidebarTrigger/` |
| BoardModeNav | `Workspace/BoardModeNav.tsx` | `Workspace/BoardModeNav/` |

Each component folder contains:
```
ComponentName/
├── index.ts                    # Re-export for backward compatibility
├── ComponentName.tsx           # Component with styles import
└── ComponentName.module.scss   # CSS Module
```

**Batch 2: Settings Pages** ✅ (Complete)

- ✅ `Settings/PreferencesPage/` (153 lines)
- ✅ `Settings/ProfilePage/` (531 lines)
- ✅ `Settings/MembersPage/` (603 lines)
- ✅ `Settings/WorkspaceSettingsPage/` (427 lines)
- ✅ `Settings/TeamsCollectionsPage/` (1073 lines - largest file!)

#### What Remains

**Batch 2: Settings Pages** ✅ (5 files migrated, ~2,787 lines)
- ✅ `PreferencesPage.scss` (153 lines) → `PreferencesPage/PreferencesPage.module.scss`
- ✅ `ProfilePage.scss` (531 lines) → `ProfilePage/ProfilePage.module.scss`
- ✅ `MembersPage.scss` (603 lines) → `MembersPage/MembersPage.module.scss`
- ✅ `WorkspaceSettingsPage.scss` (427 lines) → `WorkspaceSettingsPage/WorkspaceSettingsPage.module.scss`
- ✅ `TeamsCollectionsPage.scss` (1073 lines) → `TeamsCollectionsPage/TeamsCollectionsPage.module.scss`

**Batch 3: Workspace Views** ✅ (8 files migrated, ~1,625 lines)
- ✅ `DashboardView.scss` (180 lines) → `DashboardView/DashboardView.module.scss`
- ✅ `CollectionView.scss` (~200 lines) → `CollectionView/CollectionView.module.scss`
- ✅ `SearchResultsView.scss` (207 lines) → `SearchResultsView/SearchResultsView.module.scss`
- ✅ `SceneCard.scss` (292 lines) → `SceneCard/SceneCard.module.scss`
- ✅ `SceneCardGrid.scss` (305 lines) → `SceneCardGrid/SceneCardGrid.module.scss`
- ✅ `UserMenu.scss` (158 lines) → `UserMenu/UserMenu.module.scss`
- ✅ `CopyMoveDialog.scss` (45 lines) → `CopyMoveDialog/CopyMoveDialog.module.scss`
- ✅ `InviteAcceptPage.scss` (238 lines) → `InviteAcceptPage/InviteAcceptPage.module.scss`

**Batch 4: Feature Components** (9 files, ~2,700 lines) ✅ **COMPLETED 2025-12-23**
- ✅ `TalktrackToolbar.scss` (147 lines) → `TalktrackToolbar/TalktrackToolbar.module.scss`
- ✅ `TalktrackSetupDialog.scss` (219 lines) → `TalktrackSetupDialog/TalktrackSetupDialog.module.scss`
- ✅ `TalktrackPanel.scss` (391 lines) → `TalktrackPanel/TalktrackPanel.module.scss`
- ✅ `PresentationControls.scss` (130 lines) → `PresentationControls/PresentationControls.module.scss`
- ✅ `PresentationPanel.scss` (513 lines) → `PresentationPanel/PresentationPanel.module.scss`
- ✅ `SlidesLayoutDialog.scss` (349 lines) → `SlidesLayoutDialog/SlidesLayoutDialog.module.scss`
- ✅ `PenSettingsModal.scss` (242 lines) → `PenSettingsModal/PenSettingsModal.module.scss`
- ✅ `StickersPanel.scss` (333 lines) → `StickersPanel/StickersPanel.module.scss`
- ✅ `EmojiPicker.scss` (327 lines) → `EmojiPicker/EmojiPicker.module.scss`

**Batch 5: Complex Components** (8 files, ~2,000 lines) - IN PROGRESS
- ✅ `WorkspaceSidebar.scss` (835 lines) → `WorkspaceSidebar/WorkspaceSidebar.module.scss` **DONE 2025-12-23**
- `FullModeNav.scss` (370 lines)
- `LoginDialog.scss` (263 lines)
- `UserProfileDialog.scss` (421 lines)
- `QuickSearchModal.scss` (396 lines)
- `ShareDialog.scss` (166 lines)
- `WelcomeScreenBackground.scss` (254 lines)
- `index.scss` (~100 lines) - Keep as global entry point

#### Per-Component Migration Process

For each component:

1. **Create folder:**
   ```bash
   mkdir -p components/Workspace/SceneCard
   ```

2. **Move files:**
   ```bash
   mv SceneCard.tsx SceneCard/SceneCard.tsx
   mv SceneCard.scss SceneCard/SceneCard.module.scss
   ```

3. **Create index.ts:**
   ```typescript
   export { SceneCard } from "./SceneCard";
   export type { SceneCardProps } from "./SceneCard";
   ```

4. **Convert SCSS:**
   ```scss
   // Before (BEM global)
   .scene-card { &__title { } &--active { } }
   .excalidraw.theme--dark { .scene-card { } }
   
   // After (CSS Module with mixin)
   @use "../../../styles/mixins" as *;
   .card { }
   .title { }
   .active { }
   @include dark-mode { .card { } }
   ```

5. **Update component:**
   ```typescript
   // Before
   import "./SceneCard.scss";
   className="scene-card"
   
   // After
   import styles from "./SceneCard.module.scss";
   className={styles.card}
   ```

6. **Delete old files** and verify imports still work via index.ts

7. **Run checks:**
   ```bash
   just check-frontend
   ```

#### Key Patterns Established

**1. Dark mode mixin:**
```scss
@use "../../../styles/mixins" as *;
@include dark-mode { .card { background: #232329; } }
```

**2. Dynamic class names:**
```typescript
className={`${styles.card} ${isActive ? styles.active : ""}`}
```

**3. Size variants (AstradrawLogo example):**
```scss
.logo { }
.mobile { .icon { height: var(--logo-icon--mobile); } }
.small { .icon { height: var(--logo-icon--small); } }
```
```typescript
const sizeClasses = { mobile: styles.mobile, small: styles.small, ... };
className={`${styles.logo} ${sizeClasses[size]}`}
```

**4. Default exports for backward compatibility:**
```typescript
// index.ts
export { default, default as CollabError, collabErrorIndicatorAtom } from "./CollabError";
```

#### Estimated Remaining Effort

| Batch | Files | Lines | Time |
|-------|-------|-------|------|
| ~~Batch 2 (Settings)~~ | ~~5~~ | ~~~2,787~~ | ✅ Done |
| ~~Batch 3 (Workspace)~~ | ~~8~~ | ~~~1,625~~ | ✅ Done |
| ~~Batch 4 (Features)~~ | ~~9~~ | ~~~2,700~~ | ✅ Done |
| Batch 5 (Complex) | 7 | ~1,165 | 2 hours |
| **Total Remaining** | **7** | **~1,165** | **~2 hours** |

Note: WorkspaceSidebar (835 lines) completed 2025-12-23.

#### Files Already Using CSS Modules (33 total)

From pilot + Batch 1 + Batch 2 + Batch 3 + Batch 4 + WorkspaceSidebar:
- `components/Skeletons/Skeleton.module.scss`
- `components/ErrorBoundary/ErrorBoundary.module.scss`
- `components/SaveStatusIndicator/SaveStatusIndicator.module.scss`
- `components/AstradrawLogo/AstradrawLogo.module.scss`
- `components/AppFooter/AppFooter.module.scss`
- `components/AppSidebar/AppSidebar.module.scss`
- `collab/CollabError/CollabError.module.scss`
- `pens/PenToolbar/PenToolbar.module.scss`
- `Workspace/WorkspaceMainContent/WorkspaceMainContent.module.scss`
- `Workspace/WorkspaceSidebarTrigger/WorkspaceSidebarTrigger.module.scss`
- `Workspace/BoardModeNav/BoardModeNav.module.scss`
- `Settings/PreferencesPage/PreferencesPage.module.scss`
- `Settings/ProfilePage/ProfilePage.module.scss`
- `Settings/MembersPage/MembersPage.module.scss`
- `Settings/WorkspaceSettingsPage/WorkspaceSettingsPage.module.scss`
- `Settings/TeamsCollectionsPage/TeamsCollectionsPage.module.scss`
- `Workspace/DashboardView/DashboardView.module.scss`
- `Workspace/CollectionView/CollectionView.module.scss`
- `Workspace/SearchResultsView/SearchResultsView.module.scss`
- `Workspace/SceneCard/SceneCard.module.scss`
- `Workspace/SceneCardGrid/SceneCardGrid.module.scss`
- `Workspace/UserMenu/UserMenu.module.scss`
- `Workspace/CopyMoveDialog/CopyMoveDialog.module.scss`
- `Workspace/InviteAcceptPage/InviteAcceptPage.module.scss`
- `Workspace/WorkspaceSidebar/WorkspaceSidebar.module.scss`
- `Talktrack/TalktrackToolbar/TalktrackToolbar.module.scss`
- `Talktrack/TalktrackSetupDialog/TalktrackSetupDialog.module.scss`
- `Talktrack/TalktrackPanel/TalktrackPanel.module.scss`
- `Presentation/PresentationControls/PresentationControls.module.scss`
- `Presentation/PresentationPanel/PresentationPanel.module.scss`
- `Presentation/SlidesLayoutDialog/SlidesLayoutDialog.module.scss`
- `pens/PenSettingsModal/PenSettingsModal.module.scss`
- `Stickers/StickersPanel/StickersPanel.module.scss`
- `EmojiPicker/EmojiPicker.module.scss`

---

### 13. ✅ ANALYZED: Real-Time Collaboration Performance (Socket.io)

> **Analyzed:** 2025-12-23 - Profiled on LAN, excellent performance confirmed
> **Status:** No changes needed. Current implementation performs well.

**Issue:** During local testing, collaborator cursors appeared to move with some lag. Investigated whether Socket.io should be replaced with alternatives.

#### Profiling Results (LAN Test - 2025-12-23)

**Test Environment:**
- Mac (WiFi) ↔ Router ↔ Windows (Ethernet)
- Duration: 321 seconds
- Total messages: 2,095 cursor/state updates
- Messages per second: 6.5

**Latency Summary:**

| Metric | Value | Assessment |
|--------|-------|------------|
| Average latency | 0.26ms | ✅ Excellent |
| P95 latency | 0.50ms | ✅ Excellent |
| P99 latency | 0.70ms | ✅ Excellent |
| Max latency | 4.20ms | ✅ Acceptable |

**Detailed Timings:**

| Operation | Avg (ms) | P95 (ms) | P99 (ms) |
|-----------|----------|----------|----------|
| Total processing | 0.26 | 0.50 | 0.70 |
| Decryption (WebCrypto) | 0.14 | 0.30 | 0.40 |
| Encryption (outgoing) | 0.39 | 0.90 | 1.70 |
| updateScene | 0.02 | 0.10 | 0.10 |
| Map cloning | 0.01 | 0.10 | 0.10 |

**Conclusion:** Client-side processing is extremely fast (<1ms for 99% of messages). The perceived lag was likely caused by:
1. WiFi network jitter (5-20ms)
2. Intentional throttling (`CURSOR_SYNC_TIMEOUT = 33ms` = ~30fps)
3. Browser paint cycles (~16ms at 60fps)

#### Current Implementation

The room-service is a minimal relay server (~155 lines) using Socket.io 4.6.1:

```
room-service/src/index.ts
├── transports: ["websocket", "polling"]  # WebSocket preferred, polling fallback
├── socket.volatile.broadcast              # For cursor positions (can drop packets)
├── Encrypted payloads                     # Web Crypto API for all messages
├── Room-based architecture                # Isolation between collaboration sessions
└── CURSOR_SYNC_TIMEOUT = 33ms             # ~30fps throttle on client
```

#### Alternatives Evaluated

| Factor | Socket.io (Current) | Raw `ws` | Yjs + y-websocket |
|--------|---------------------|----------|-------------------|
| **Migration effort** | 0 | Medium (2-3 days) | High (1-2 weeks) |
| **Cursor smoothness** | ~50-100ms | ~5-10ms | ~10-20ms |
| **Conflict resolution** | Manual (version tracking) | Manual | **Automatic CRDT** |
| **Offline support** | ❌ | ❌ | ✅ |
| **Excalidraw compatibility** | ✅ Native | 🟡 Needs adapter | 🟡 Needs refactor |
| **Bundle size impact** | 0 | -47kb | +20kb |
| **Reconnection handling** | ✅ Built-in | ❌ Manual | ✅ Built-in |

#### Decision: Keep Socket.io - No Changes Needed

**Rationale:**
- Profiling confirmed excellent performance (<1ms P99)
- Socket.io is battle-tested and already integrated with Excalidraw
- Encryption overhead is negligible (0.14ms avg)
- React updates are fast (0.02ms avg)
- No bottlenecks identified in client-side processing

#### Future Consideration: Yjs Migration

Consider Yjs **only if** these features become requirements:
- **Offline editing** with automatic sync on reconnect
- **Conflict-free concurrent edits** (eliminate version tracking)
- **Better UX on unreliable networks** (mobile, poor WiFi)

**NOT recommended for performance reasons** - current implementation is already fast.

#### If Performance Issues Arise in the Future

If profiling shows degraded performance (P95 > 10ms), consider these optimizations:

**1. Batch cursor updates with RAF**
```typescript
// Collab.tsx - Add batching to updateCollaborator
private pendingCollaboratorUpdates = new Map<SocketId, Partial<Collaborator>>();

updateCollaborator = (socketId: SocketId, updates: Partial<Collaborator>) => {
  this.pendingCollaboratorUpdates.set(socketId, {
    ...this.pendingCollaboratorUpdates.get(socketId),
    ...updates,
  });
  this.flushCollaboratorUpdates();
};

private flushCollaboratorUpdates = throttleRAF(() => {
  if (this.pendingCollaboratorUpdates.size === 0) return;
  
  const collaborators = new Map(this.collaborators);
  for (const [socketId, updates] of this.pendingCollaboratorUpdates) {
    collaborators.set(socketId, { 
      ...collaborators.get(socketId), 
      ...updates,
      isCurrentUser: socketId === this.portal.socket?.id,
    });
  }
  this.pendingCollaboratorUpdates.clear();
  this.collaborators = collaborators;
  this.excalidrawAPI.updateScene({ collaborators });
});
```

**2. Adjust throttle** (trade-off: more bandwidth for smoother cursor)
```typescript
// app_constants.ts - Try 60fps instead of 30fps
export const CURSOR_SYNC_TIMEOUT = 16; // Was 33
```

**3. Unencrypted volatile channel for cursors** (security trade-off)
- Cursor positions are ephemeral and non-sensitive
- Could skip encryption for `MOUSE_LOCATION` messages only

#### Files Involved

| File | Purpose |
|------|---------|
| `room-service/src/index.ts` | WebSocket relay server |
| `frontend/excalidraw-app/collab/Portal.tsx` | Socket connection, message broadcasting |
| `frontend/excalidraw-app/collab/Collab.tsx` | Collaboration state, cursor handling |
| `frontend/excalidraw-app/collab/collabProfiling.ts` | Performance profiling utility |
| `frontend/excalidraw-app/app_constants.ts` | `CURSOR_SYNC_TIMEOUT` setting |

#### Performance Profiling (for AI-Assisted Analysis)

A profiling utility is available to measure actual bottlenecks. Use this before implementing optimizations.

**How to collect profiling data:**

1. Start the dev environment: `just dev`
2. Open AstraDraw in two browser windows
3. Join the same collaboration room in both
4. In browser console (receiving side), enable profiling:
   ```javascript
   window.COLLAB_PROFILING = true;
   ```
5. Move cursor around in the other window for 30-60 seconds
6. Copy the report to clipboard:
   ```javascript
   window.COLLAB_PROFILING_COPY();
   ```
7. Paste the markdown report into a chat with AI for analysis

**Available commands:**

| Command | Description |
|---------|-------------|
| `window.COLLAB_PROFILING = true` | Enable profiling |
| `window.COLLAB_PROFILING = false` | Disable profiling |
| `window.COLLAB_PROFILING_STATS()` | Show stats table in console |
| `window.COLLAB_PROFILING_EXPORT()` | Download JSON report file |
| `window.COLLAB_PROFILING_COPY()` | Copy markdown report to clipboard |
| `window.COLLAB_PROFILING_CLEAR()` | Clear all collected data |

**Example profiling report:**

```markdown
## Collaboration Performance Analysis

**Duration:** 45.2 seconds
**Total cursor/state updates received:** 1350
**Messages per second:** 29.9

### Latency Summary
- Average: 8.45ms
- P95: 15.23ms
- P99: 22.18ms

### Bottleneck Analysis
- ⚠️ **Decryption is slow** (avg 3.21ms). Consider unencrypted volatile channel for cursors.
- ⚠️ **updateScene is slow** (avg 4.89ms). Consider RAF batching.

### Recommendation
🟡 **Moderate latency.** Consider RAF batching if cursor feels laggy.

### Detailed Timings

| Label | Count | Avg (ms) | P95 (ms) | P99 (ms) |
|-------|-------|----------|----------|----------|
| client-broadcast:total | 1350 | 8.45 | 15.23 | 22.18 |
| client-broadcast:decrypt | 1350 | 3.21 | 5.12 | 7.89 |
| updateCollaborator:updateScene | 1350 | 4.89 | 9.45 | 14.23 |
| ... | ... | ... | ... | ... |
```

**AI prompt for analysis:**

> I've collected collaboration profiling data from AstraDraw. Please analyze this report and recommend whether we should:
> 1. Implement RAF batching for cursor updates
> 2. Use unencrypted channel for volatile cursor data
> 3. Keep current implementation
>
> Here's the profiling report:
> [paste report]

---

### 14. ✅ RESOLVED: Internationalization for AstraDraw-Specific Strings

> **Note:** Section numbers 14-16 were renumbered from 13-15 after adding collaboration analysis.

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

### 15. ✅ RESOLVED: Efficient API Payloads with Field Filtering

> **Resolved:** 2025-12-23 - Added `?fields=` query parameter to scenes and collections endpoints

**Was:** List endpoints returned full objects when the frontend only needed a subset:
- Scenes: 12 fields returned, 6 used (~50% overhead)
- Collections: 13 fields returned, 8 used (~40% overhead)

**Fix:** Added `?fields=` query parameter support to filter response fields:

```
GET /workspace/scenes?workspaceId=xxx&fields=id,title,thumbnailUrl,updatedAt,isPublic,canEdit
GET /workspaces/:id/collections?fields=id,name,icon,isPrivate,sceneCount,canWrite,isOwner
```

**Implementation:**

1. **Reusable utility** at `backend/src/utils/field-filter.ts`:
   - `parseFields()` - Parses comma-separated fields, validates against allowed list
   - `filterResponse()` - Filters object to include only requested fields
   - `filterResponseArray()` - Filters array of objects

2. **Backend endpoints updated:**
   - `GET /workspace/scenes` - Accepts `?fields=` parameter
   - `GET /workspaces/:id/collections` - Accepts `?fields=` parameter

3. **Frontend hooks updated:**
   - `useScenesCache` - Requests only fields needed for scene cards
   - `useCollections` - Requests only fields needed for sidebar/nav

**Usage pattern for future endpoints:**

```typescript
// Backend controller
import { parseFields, filterResponseArray } from '../utils/field-filter';

const ALLOWED_FIELDS = ['id', 'name', 'email'] as const;

@Get('users')
async listUsers(@Query('fields') fieldsParam?: string) {
  const fields = parseFields(fieldsParam, ALLOWED_FIELDS);
  const users = await this.service.list();
  return filterResponseArray(users.map(u => this.toResponse(u)), fields);
}

// Frontend API function
export async function listUsers(options?: { fields?: string[] }) {
  const params = new URLSearchParams();
  if (options?.fields?.length) {
    params.append("fields", options.fields.join(","));
  }
  return apiRequest(`/users?${params.toString()}`, { ... });
}
```

**Benefits:**
- ~50% smaller payloads for scene list views
- ~40% smaller payloads for collection list views
- Backward compatible - existing clients work unchanged
- Reusable pattern for other endpoints if needed

---

### 16. ✅ RESOLVED: Excalidraw Test Failures Caused by AstraDraw Changes

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
| 2025-12-23 | CSS Modules migration: WorkspaceSidebar (835 lines) - Batch 5 started |
| 2025-12-23 | Comment System: Phase 1 Backend complete (schema, module, endpoints) |
| 2025-12-23 | Added backend unit tests as future task (item 11b) |
| 2025-12-23 | CSS Modules migration: Batch 3 complete (8 Workspace View components) |
| 2025-12-23 | Collaboration profiling: LAN test confirmed excellent performance (<1ms P99), no changes needed |
| 2025-12-23 | Added collaboration profiling utility with AI-exportable reports |
| 2025-12-23 | Added collaboration performance analysis: keep Socket.io, optimize cursor batching |
| 2025-12-23 | CSS Modules migration: Batch 1 complete (8 components), shared styles infrastructure |
| 2025-12-23 | Added efficient payloads with `?fields=` parameter for scenes and collections |
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
