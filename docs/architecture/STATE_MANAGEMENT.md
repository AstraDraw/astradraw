# State Management in AstraDraw

This document describes the state management architecture used in AstraDraw, including the use of Jotai atoms for global state and React's `useState` for component-local state.

## Overview

AstraDraw uses a hybrid state management approach:

1. **React Query** - For server state (API data: scenes, workspaces, collections)
2. **Jotai Atoms** - For client state shared across components (navigation, selection, UI)
3. **React useState** - For component-local UI state
4. **React Context** - For authentication (via `AuthProvider`)

### Why Jotai?

Jotai was chosen over other state management solutions because:

- **Atomic model** - Each piece of state is independent, avoiding unnecessary re-renders
- **No boilerplate** - Simple API with `atom()`, `useAtom()`, `useAtomValue()`, `useSetAtom()`
- **TypeScript-first** - Excellent type inference
- **Derived state** - Easy to create computed atoms
- **Action atoms** - Write-only atoms for encapsulating state updates with side effects

---

## Jotai Atoms Reference

### Navigation & App Mode

| Atom | Type | Purpose |
|------|------|---------|
| `appModeAtom` | `"canvas" \| "dashboard"` | Main app mode - determines what content is shown |
| `dashboardViewAtom` | `DashboardView` | Which view is active in dashboard mode |
| `sidebarModeAtom` | `"board" \| "full"` | Derived from appMode - sidebar display mode |
| `activeCollectionIdAtom` | `string \| null` | Currently selected collection |
| `isPrivateCollectionAtom` | `boolean` | Whether viewing private collection |
| `currentWorkspaceSlugAtom` | `string \| null` | Active workspace slug for URL routing |
| `currentSceneIdAtom` | `string \| null` | Currently open scene ID |
| `currentSceneTitleAtom` | `string` | Currently open scene title |
| `isAutoCollabSceneAtom` | `boolean` | Whether current scene has auto-collaboration |

**File:** `excalidraw-app/components/Settings/settingsState.ts`

### Workspace & Collections Data

| Atom | Type | Purpose |
|------|------|---------|
| `workspacesAtom` | `WorkspaceData[]` | List of all user workspaces |
| `currentWorkspaceAtom` | `WorkspaceData \| null` | Currently active workspace |
| `collectionsAtom` | `CollectionData[]` | Collections for current workspace |
| `privateCollectionAtom` | `CollectionData \| null` | Derived: private collection from list |
| `activeCollectionAtom` | `CollectionData \| null` | Derived: currently selected collection |
| `clearWorkspaceDataAtom` | action | Clear all workspace data (e.g., on logout) |

**Usage:**
```typescript
// Read workspace data
const workspace = useAtomValue(currentWorkspaceAtom);
const collections = useAtomValue(collectionsAtom);

// Write workspace data (typically via hooks)
const setWorkspace = useSetAtom(currentWorkspaceAtom);
setWorkspace(newWorkspace);

// Use derived atoms for computed values
const privateCollection = useAtomValue(privateCollectionAtom);
const activeCollection = useAtomValue(activeCollectionAtom);
```

**Note:** The `useWorkspaces` and `useCollections` hooks manage these atoms internally. Components should prefer using these hooks for CRUD operations, and read directly from atoms for display.

**File:** `excalidraw-app/components/Settings/settingsState.ts`

### Navigation Action Atoms

These are write-only atoms that encapsulate navigation logic including URL updates:

| Atom | Parameters | Action |
|------|------------|--------|
| `navigateToDashboardAtom` | none | Go to dashboard home |
| `navigateToCollectionAtom` | `{ collectionId, isPrivate? }` | Go to collection view |
| `navigateToCanvasAtom` | none | Switch to canvas mode |
| `navigateToSceneAtom` | `{ sceneId, title?, workspaceSlug? }` | Open a scene |
| `navigateToProfileAtom` | none | Go to profile page |
| `navigateToPreferencesAtom` | none | Go to preferences |
| `navigateToWorkspaceSettingsAtom` | none | Go to workspace settings |
| `navigateToMembersAtom` | none | Go to members page |
| `navigateToTeamsCollectionsAtom` | none | Go to teams & collections |

**Usage:**
```typescript
const navigateToCollection = useSetAtom(navigateToCollectionAtom);

// Navigate to a collection
navigateToCollection({ collectionId: "abc123", isPrivate: false });
```

**File:** `excalidraw-app/components/Settings/settingsState.ts`

### Refresh Trigger Atoms

> **Note:** As of 2025-12-23, scenes use React Query for data fetching. The `scenesRefreshAtom` and `triggerScenesRefreshAtom` have been removed. Use `queryClient.invalidateQueries()` instead.

Collections still use refresh trigger atoms:

| Atom | Purpose |
|------|---------|
| `collectionsRefreshAtom` | Counter that increments when collections change |
| `triggerCollectionsRefreshAtom` | Action atom to increment collections refresh |

**Usage:**
```typescript
// For collections (still uses Jotai trigger)
const triggerRefresh = useSetAtom(triggerCollectionsRefreshAtom);
await createCollection(...);
triggerRefresh();

// For scenes (use React Query invalidation)
import { useQueryClient } from "@tanstack/react-query";
import { queryKeys } from "../lib/queryClient";

const queryClient = useQueryClient();
await deleteScene(sceneId);
queryClient.invalidateQueries({ queryKey: queryKeys.scenes.all });
```

**File:** `excalidraw-app/components/Settings/settingsState.ts`

### Search Atoms

| Atom | Type | Purpose |
|------|------|---------|
| `quickSearchOpenAtom` | `boolean` | Controls Quick Search modal visibility |
| `searchQueryAtom` | `string` | Dashboard search query (shared between sidebar and results) |

**File:** `excalidraw-app/components/Settings/settingsState.ts`

### Workspace Sidebar Atoms

| Atom | Type | Purpose |
|------|------|---------|
| `workspaceSidebarOpenAtom` | `boolean` | Sidebar open state (persisted to localStorage) |
| `toggleWorkspaceSidebarAtom` | action | Toggle sidebar open/closed |
| `openWorkspaceSidebarAtom` | action | Open sidebar |
| `closeWorkspaceSidebarAtom` | action | Close sidebar |

**Usage:**
```typescript
// Read state
const isOpen = useAtomValue(workspaceSidebarOpenAtom);

// Toggle (e.g., from keyboard shortcut)
const toggle = useSetAtom(toggleWorkspaceSidebarAtom);
toggle();

// Open (e.g., after login)
const open = useSetAtom(openWorkspaceSidebarAtom);
open();

// Close (e.g., when switching to canvas)
const close = useSetAtom(closeWorkspaceSidebarAtom);
close();
```

**Note:** Navigation atoms (`navigateToDashboardAtom`, `navigateToCollectionAtom`) automatically open the sidebar when navigating to dashboard views.

**File:** `excalidraw-app/components/Settings/settingsState.ts`

### Collaboration Atoms

| Atom | Type | Purpose |
|------|------|---------|
| `collabAPIAtom` | `CollabAPI \| null` | Collaboration API instance |
| `isCollaboratingAtom` | `boolean` | Whether currently in collaboration session |
| `isOfflineAtom` | `boolean` | Whether offline |
| `activeRoomLinkAtom` | `string \| null` | Active collaboration room link |
| `collabErrorIndicatorAtom` | `ErrorIndicator` | Collaboration error state |

**File:** `excalidraw-app/collab/Collab.tsx`, `excalidraw-app/collab/CollabError.tsx`

### Presentation Mode Atoms

| Atom | Type | Purpose |
|------|------|---------|
| `presentationModeAtom` | `boolean` | Is presentation mode active |
| `currentSlideAtom` | `number` | Current slide index |
| `slidesAtom` | `ExcalidrawFrameLikeElement[]` | Array of slides (frames) |
| `isLaserActiveAtom` | `boolean` | Is laser pointer active |
| `slideOrderAtom` | `string[]` | Custom slide order |
| `originalThemeAtom` | `"light" \| "dark" \| null` | Theme before presentation |
| `originalFrameRenderingAtom` | `FrameRenderingState \| null` | Frame rendering state before presentation |

**File:** `excalidraw-app/components/Presentation/usePresentationMode.ts`

### Comment System Atoms

| Atom | Type | Purpose |
|------|------|---------|
| `selectedThreadIdAtom` | `string \| null` | Currently selected thread for popup |
| `isCommentModeAtom` | `boolean` | Comment creation mode active |
| `commentFiltersAtom` | `ThreadFilters` | Sidebar filter/sort settings |
| `isCommentsSidebarOpenAtom` | `boolean` (derived) | Whether comments tab is open |

**File:** `excalidraw-app/components/Comments/commentsState.ts`

### Other Atoms

| Atom | Type | File | Purpose |
|------|------|------|---------|
| `authUserAtom` | `AuthUser \| null` | app-jotai.ts | Authenticated user data |
| `appLangCodeAtom` | `string` | language-state.ts | App language code |
| `shareDialogStateAtom` | `ShareDialogState` | ShareDialog.tsx | Share dialog state |
| `localStorageQuotaExceededAtom` | `boolean` | LocalData.ts | Storage quota exceeded flag |

---

## Local State (useState)

Some state is intentionally kept as local `useState` because it's:
- Only used within a single component
- UI-specific and doesn't need to be shared
- Temporary/transient state

### In App.tsx

App.tsx uses extracted hooks for most logic. Remaining local state:

| State | Purpose | Why not Jotai? |
|-------|---------|----------------|
| `errorMessage` | Error display | Component-local UI state |
| `isLegacyMode` | Legacy collab mode detection | Internal mechanism |
| `pendingInviteCode` | Invite URL handling | Temporary state |
| `forceRefresh` | Force component re-render | Internal mechanism |

### App.tsx Hooks

Logic has been extracted into focused hooks in `excalidraw-app/hooks/`:

| Hook | Manages |
|------|---------|
| `useAutoSave` | Save status, debounce, retry, offline detection |
| `useSceneLoader` | Scene loading, scene state (id, title, access) |
| `useUrlRouting` | Popstate, URL parsing, dashboard navigation |
| `useKeyboardShortcuts` | Ctrl+S, Cmd+P, Cmd+[, Cmd+] |
| `useWorkspaceData` | Workspace, collections, private collection ID |

### In Child Components

Most child components use local `useState` for:
- Form input values
- Loading states
- Modal open/close states (unless shared)
- Temporary UI state (hover, focus, etc.)

---

## React Query (Server State)

React Query handles all API data fetching with automatic caching, deduplication, and background refetching.

### Query Client Setup

```typescript
// lib/queryClient.ts
import { QueryClient } from "@tanstack/react-query";

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      gcTime: 30 * 60 * 1000,   // 30 minutes
      retry: 2,
      refetchOnWindowFocus: true,
    },
  },
});

// Type-safe query keys
export const queryKeys = {
  scenes: {
    all: ["scenes"] as const,
    list: (workspaceId: string, collectionId?: string | null) =>
      ["scenes", workspaceId, collectionId ?? "all"] as const,
  },
  workspaces: {
    all: ["workspaces"] as const,
    list: () => ["workspaces"] as const,
  },
  collections: {
    all: ["collections"] as const,
    list: (workspaceId: string) => ["collections", workspaceId] as const,
  },
};
```

### Data Fetching Hooks

| Hook | Query Key | Data Source |
|------|-----------|-------------|
| `useScenesCache` | `queryKeys.scenes.list(workspaceId, collectionId)` | `listWorkspaceScenes()` |
| `useWorkspaces` | `queryKeys.workspaces.list()` | `listWorkspaces()` |
| `useCollections` | `queryKeys.collections.list(workspaceId)` | `listCollections()` |
| `useSceneActions` | Uses `useMutation` | Scene CRUD with optimistic updates |
| `useCommentThreads` | `queryKeys.commentThreads.list(sceneId)` | `listThreads()` |
| `useCommentMutations` | Uses `useMutation` | Thread/comment CRUD with optimistic updates |

**Usage:**
```typescript
// In components - use the hooks
const { scenes, isLoading } = useScenesCache({
  workspaceId: workspace?.id,
  collectionId: activeCollectionId,
  enabled: !!workspace?.id,
});

// Scene actions with optimistic updates (UI updates immediately, rolls back on error)
const { deleteScene, renameScene, duplicateScene, isDeleting } = useSceneActions({
  workspaceId: workspace?.id,
  collectionId: activeCollectionId,
});

// Delete - UI updates immediately, rolls back if API fails
await deleteScene(sceneId);

// Rename - UI updates immediately, rolls back if API fails
await renameScene(sceneId, "New Title");

// Duplicate - waits for API (needs new scene ID)
const newScene = await duplicateScene(sceneId);
```

### Outside React Components

For code outside React components (e.g., utility functions), import the queryClient directly:

```typescript
import { queryClient, queryKeys } from "../lib/queryClient";

// After mutation
queryClient.invalidateQueries({ queryKey: queryKeys.scenes.all });
```

---

## When to Use What

### Use React Query When:

1. **Fetching data from the API**
   - Scenes, workspaces, collections, user profiles
   - Any data that comes from the backend

2. **You need caching and deduplication**
   - Multiple components showing same data share one request
   - Data stays fresh with background refetching

3. **You need loading/error states**
   - React Query provides `isLoading`, `error`, `isRefetching` automatically

### Use Jotai Atom When:

1. **Multiple components need the same state**
   ```typescript
   // Bad: Prop drilling
   <Parent state={x} setState={setX}>
     <Child state={x} setState={setX}>
       <GrandChild state={x} setState={setX} />
     </Child>
   </Parent>
   
   // Good: Jotai atom
   const xAtom = atom(initialValue);
   // Any component can use it directly
   const [x, setX] = useAtom(xAtom);
   ```

2. **State needs to be accessed from action atoms**
   ```typescript
   // Navigation atoms need to read/write multiple state pieces
   export const navigateToCollectionAtom = atom(null, (get, set, params) => {
     set(activeCollectionIdAtom, params.collectionId);
     set(appModeAtom, "dashboard");
     set(dashboardViewAtom, "collection");
   });
   ```

3. **State changes should trigger effects in unrelated components**
   ```typescript
   // Refresh triggers notify all subscribed components
   const triggerRefresh = useSetAtom(triggerCollectionsRefreshAtom);
   triggerRefresh(); // All components watching collectionsRefreshAtom re-render
   ```

4. **State is part of the URL/routing**
   - `currentWorkspaceSlugAtom`
   - `currentSceneIdAtom`
   - `activeCollectionIdAtom`

### Use useState When:

1. **State is truly component-local**
   ```typescript
   // Form input that's only used in this component
   const [inputValue, setInputValue] = useState("");
   ```

2. **State is temporary/transient**
   ```typescript
   // Loading state for a specific API call
   const [isLoading, setIsLoading] = useState(false);
   ```

3. **State doesn't need to survive component unmount**
   ```typescript
   // Modal open state that resets on unmount
   const [isOpen, setIsOpen] = useState(false);
   ```

---

## Patterns

### Reading Atom Values

```typescript
// Read-only (no re-render on write)
const value = useAtomValue(myAtom);

// Read and write
const [value, setValue] = useAtom(myAtom);

// Write-only (no re-render on read)
const setValue = useSetAtom(myAtom);
```

### Derived Atoms

```typescript
// Computed value based on other atoms
export const sidebarModeAtom = atom<SidebarMode>((get) => {
  const appMode = get(appModeAtom);
  return appMode === "canvas" ? "board" : "full";
});
```

### Action Atoms (Write-Only)

```typescript
// Encapsulate complex state updates
export const navigateToDashboardAtom = atom(null, (get, set) => {
  const workspaceSlug = get(currentWorkspaceSlugAtom);
  set(appModeAtom, "dashboard");
  set(dashboardViewAtom, "home");
  
  if (workspaceSlug) {
    navigateTo(buildDashboardUrl(workspaceSlug));
  }
});
```

### Atom with localStorage Persistence

```typescript
// Initialize from localStorage
const STORAGE_KEY = "astradraw_workspace_sidebar_open";

export const workspaceSidebarOpenAtom = atom<boolean>(
  typeof window !== "undefined"
    ? localStorage.getItem(STORAGE_KEY) === "true"
    : false
);

// Action atoms handle localStorage sync (preferred pattern)
export const openWorkspaceSidebarAtom = atom(null, (get, set) => {
  set(workspaceSidebarOpenAtom, true);
  if (typeof window !== "undefined") {
    localStorage.setItem(STORAGE_KEY, "true");
  }
});

export const closeWorkspaceSidebarAtom = atom(null, (get, set) => {
  set(workspaceSidebarOpenAtom, false);
  if (typeof window !== "undefined") {
    localStorage.setItem(STORAGE_KEY, "false");
  }
});
```

---

## Migration Guide: useState to Jotai

When migrating a `useState` to a Jotai atom:

### Step 1: Create the Atom

```typescript
// In settingsState.ts (or appropriate file)
export const myStateAtom = atom<MyType>(initialValue);
```

### Step 2: Export from Index

```typescript
// In index.ts
export { myStateAtom } from "./settingsState";
```

### Step 3: Replace useState Usage

```typescript
// Before
const [myState, setMyState] = useState(initialValue);

// After
const [myState, setMyState] = useAtom(myStateAtom);
// Or if read-only:
const myState = useAtomValue(myStateAtom);
// Or if write-only:
const setMyState = useSetAtom(myStateAtom);
```

### Step 4: Remove Props

```typescript
// Before
<ChildComponent myState={myState} setMyState={setMyState} />

// After
<ChildComponent /> // Child reads atom directly
```

### Step 5: Update Action Atoms (if needed)

```typescript
// Action atoms can now access the new atom
export const someActionAtom = atom(null, (get, set) => {
  const myState = get(myStateAtom);
  set(myStateAtom, newValue);
});
```

---

## File Organization

```
excalidraw-app/
├── app-jotai.ts              # Jotai provider setup, authUserAtom
├── lib/                      # Shared utilities
│   ├── queryClient.ts        # React Query client + query keys + mutation keys
│   └── index.ts              # Re-exports
├── hooks/                    # Extracted logic hooks
│   ├── useAutoSave.ts        # Save state machine, debounce, retry
│   ├── useSceneLoader.ts     # Scene loading from workspace URLs
│   ├── useUrlRouting.ts      # Popstate, URL parsing
│   ├── useKeyboardShortcuts.ts  # Global keyboard handlers
│   ├── useSceneActions.ts    # Scene CRUD with optimistic updates (useMutation)
│   ├── useScenesCache.ts     # Scenes fetching (React Query)
│   ├── useCollections.ts     # Collection operations (React Query)
│   ├── useWorkspaces.ts      # Workspace operations (React Query)
│   ├── useCommentThreads.ts  # Comment thread fetching + mutations (React Query)
│   └── useCommentSync.ts     # WebSocket sync for comments
├── auth/api/                 # Modular API client
│   ├── client.ts             # Base fetch wrapper
│   ├── types.ts              # TypeScript interfaces
│   ├── scenes.ts             # Scene CRUD
│   ├── comments.ts           # Comment thread/reply CRUD
│   └── ...                   # Other domain modules
├── components/
│   ├── Settings/
│   │   ├── settingsState.ts  # Navigation/UI state atoms (Jotai)
│   │   └── index.ts          # Re-exports atoms
│   ├── Comments/
│   │   ├── commentsState.ts  # Comment UI state atoms (Jotai)
│   │   └── ...               # Comment components
│   └── Presentation/
│       └── usePresentationMode.ts  # Presentation atoms
├── collab/
│   ├── Collab.tsx            # Collaboration atoms
│   └── CollabError.tsx       # Collab error atom
├── share/
│   └── ShareDialog.tsx       # Share dialog atom
└── data/
    └── LocalData.ts          # Storage quota atom
```

---

## Related Documentation

- [URL_ROUTING.md](URL_ROUTING.md) - How navigation atoms interact with URLs
- [CRITICAL_CSS_HIDE_SHOW_FIX.md](../troubleshooting/CRITICAL_CSS_HIDE_SHOW_FIX.md) - Why appMode uses CSS hide/show
- [QUICK_SEARCH.md](../features/QUICK_SEARCH.md) - Quick Search atoms usage
- [TECHNICAL_DEBT_AND_IMPROVEMENTS.md](../planning/TECHNICAL_DEBT_AND_IMPROVEMENTS.md) - React Query migration and established patterns

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-24 | Added Comment System atoms and hooks documentation |
| 2025-12-24 | Updated file organization with auth/api/ and Comments/ folders |
| 2025-12-24 | Fixed broken reference to archived SCENES_CACHE.md |
| 2025-12-23 | Added optimistic updates to `useSceneActions` using `useMutation` |
| 2025-12-23 | Added React Query for server state (scenes, workspaces, collections) |
| 2025-12-23 | Removed manual cache atoms (`scenesCacheAtom`, `scenesRefreshAtom`) |
| 2025-12-23 | Added `lib/queryClient.ts` with QueryClient and query key factory |
| 2025-12-23 | Added workspace/collections atoms (workspacesAtom, currentWorkspaceAtom, collectionsAtom, etc.) |
| 2025-12-23 | Documented App.tsx hooks (useAutoSave, useSceneLoader, etc.) |
| 2025-12-23 | Migrated `workspaceSidebarOpen` from useState to Jotai atom |
| 2025-12-23 | Initial documentation |

