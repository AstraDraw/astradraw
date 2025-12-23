# State Management in AstraDraw

This document describes the state management architecture used in AstraDraw, including the use of Jotai atoms for global state and React's `useState` for component-local state.

## Overview

AstraDraw uses a hybrid state management approach:

1. **Jotai Atoms** - For global state shared across multiple components
2. **React useState** - For component-local UI state
3. **React Context** - For authentication (via `AuthProvider`)

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

Used for cross-component communication to trigger data re-fetching:

| Atom | Purpose |
|------|---------|
| `collectionsRefreshAtom` | Counter that increments when collections change |
| `triggerCollectionsRefreshAtom` | Action atom to increment collections refresh |
| `scenesRefreshAtom` | Counter that increments when scenes change |
| `triggerScenesRefreshAtom` | Action atom to increment scenes refresh |

**Usage:**
```typescript
// In component that modifies data
const triggerRefresh = useSetAtom(triggerCollectionsRefreshAtom);
await createCollection(...);
triggerRefresh(); // Notify other components

// In component that displays data
const refreshCounter = useAtomValue(collectionsRefreshAtom);
useEffect(() => {
  loadCollections();
}, [refreshCounter]); // Re-fetch when counter changes
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

| State | Purpose | Why not Jotai? |
|-------|---------|----------------|
| `errorMessage` | Error display | Component-local UI state |
| `_isOnline` | Network status tracking | Internal mechanism |
| `hasUnsavedChanges` | Autosave status indicator | Could be Jotai, but tightly coupled to save logic |
| `forceRefresh` | Force component re-render | Internal mechanism |

### In Child Components

Most child components use local `useState` for:
- Form input values
- Loading states
- Modal open/close states (unless shared)
- Temporary UI state (hover, focus, etc.)

---

## When to Use What

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
├── components/
│   ├── Settings/
│   │   ├── settingsState.ts  # Main navigation/app state atoms
│   │   └── index.ts          # Re-exports atoms
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
- [SCENES_CACHE.md](../planning/SCENES_CACHE.md) - Centralized scenes caching system

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-23 | Added centralized scenes cache with `scenesCacheAtom` |
| 2025-12-23 | Migrated `workspaceSidebarOpen` from useState to Jotai atom |
| 2025-12-23 | Initial documentation |

