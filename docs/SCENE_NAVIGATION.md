# Scene Navigation Architecture

## Overview

This document describes the scene navigation architecture in AstraDraw, implementing the "Excalidraw Plus pattern" where the dashboard is the main application and the canvas is loaded on-demand for specific scenes.

> **Status:** Implementation complete, testing in progress (December 2025)

## Core Concept

**Dashboard-First Architecture:**
- When authenticated, users start in the **dashboard** (not the canvas)
- The canvas only renders when a **specific scene** is being viewed
- Each scene has a **unique URL** that always loads that scene's data
- Navigation between scenes works like navigating between web pages

```
┌─────────────────────────────────────────────────────────────┐
│                    AstraDraw Application                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Dashboard (Main Application)                              │
│   ├── Collections list                                      │
│   ├── Scene cards                                           │
│   ├── Settings pages                                        │
│   └── Profile                                               │
│                                                             │
│         ↓ Click scene / Create scene                        │
│                                                             │
│   Canvas (Loaded on demand)                                 │
│   ├── Excalidraw component mounted                          │
│   ├── Scene data fetched from backend                       │
│   ├── Sidebar shows collection's scenes                     │
│   └── URL reflects current scene                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## URL Structure

Each scene has a permanent, unique URL:

| View | URL Pattern | Example |
|------|-------------|---------|
| Dashboard | `/workspace/{slug}/dashboard` | `/workspace/admin/dashboard` |
| Collection | `/workspace/{slug}/collection/{id}` | `/workspace/admin/collection/abc123` |
| Private Collection | `/workspace/{slug}/private` | `/workspace/admin/private` |
| **Scene (Canvas)** | `/workspace/{slug}/scene/{id}` | `/workspace/admin/scene/xyz789` |
| Scene with Collab | `/workspace/{slug}/scene/{id}#key={roomKey}` | `/workspace/admin/scene/xyz789#key=abc` |

## How Scene Loading Works

### The Problem We Solved

Previously, the Excalidraw canvas was always mounted in the background, and a single `initialStatePromiseRef` was created once and resolved once. This caused:

1. **Race condition:** When navigating from dashboard to scene, the canvas would render with stale data before new scene data loaded
2. **Data mixing:** Rapid scene switching could cause data from different scenes to mix
3. **URL desync:** The URL wouldn't always reflect the actual scene being displayed

### The Solution

```
User clicks scene card (or navigates via URL)
         │
         ▼
┌─────────────────────────────────────┐
│  1. Set loading state               │
│     isLoadingScene = true           │
│     sceneDataLoaded = false         │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  2. Reset initialStatePromiseRef    │
│     Create NEW promise              │
│     (Old promise is abandoned)      │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  3. Track request ID                │
│     currentLoadingSceneId = sceneId │
│     (For race condition handling)   │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  4. Show loading spinner            │
│     Canvas NOT rendered yet         │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  5. Fetch scene data from backend   │
│     loadWorkspaceScene(slug, id)    │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  6. Check if request is stale       │
│     If currentLoadingSceneId !=     │
│     sceneId, IGNORE this result     │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  7. Resolve promise with scene data │
│     initialStatePromiseRef.resolve  │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  8. Update canvas                   │
│     excalidrawAPI.updateScene()     │
│     sceneDataLoaded = true          │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  9. Render Excalidraw               │
│     Canvas shows correct scene      │
└─────────────────────────────────────┘
```

### Race Condition Handling

When user rapidly switches between scenes:

```
Click Scene A → loadSceneFromUrl("scene-a") starts
                currentLoadingSceneId = "scene-a"
                
Click Scene B → loadSceneFromUrl("scene-b") starts  
                currentLoadingSceneId = "scene-b"  ← Updated!
                
Scene A data arrives → Check: "scene-a" !== "scene-b"
                       Result: IGNORED (stale request)
                       
Scene B data arrives → Check: "scene-b" === "scene-b"
                       Result: APPLIED (current request)
```

## Key Components

### State Variables (App.tsx)

```typescript
// Loading states
const [isLoadingScene, setIsLoadingScene] = useState(false);
const [sceneDataLoaded, setSceneDataLoaded] = useState(false);

// Scene tracking
const [currentSceneId, setCurrentSceneId] = useState<string | null>(null);
const currentSceneIdRef = useRef<string | null>(null);

// Initial data promise (reset for each scene)
const initialStatePromiseRef = useRef<{
  promise: ResolvablePromise<ExcalidrawInitialDataState | null>;
}>({ promise: null! });
```

### Navigation Atoms (settingsState.ts)

```typescript
// Navigate to dashboard - clears scene state
export const navigateToDashboardAtom = atom(null, (get, set) => {
  set(appModeAtom, "dashboard");
  set(dashboardViewAtom, "home");
  set(currentSceneIdAtom, null);        // Clear scene
  set(currentSceneTitleAtom, "Untitled");
  // Push URL...
});

// Navigate to scene - triggers scene loading
export const navigateToSceneAtom = atom(null, (get, set, params) => {
  set(currentSceneIdAtom, params.sceneId);
  set(currentSceneTitleAtom, params.title);
  set(appModeAtom, "canvas");
  // Push URL - triggers popstate handler
});
```

### Conditional Rendering (App.tsx)

```typescript
// Show loading spinner while scene is being fetched
const shouldShowSceneLoading =
  appMode === "canvas" &&
  !isLegacyMode &&
  (isLoadingScene || (!sceneDataLoaded && currentSceneId));

if (shouldShowSceneLoading) {
  return <LoadingSpinner />;
}

// Show dashboard when in dashboard mode
if (appMode === "dashboard" && !isLegacyMode) {
  return <Dashboard />;
}

// Show canvas only when scene data is loaded
return <Excalidraw initialData={initialStatePromiseRef.current.promise} />;
```

## Scene Deletion Behavior

When a scene is deleted:

1. **If deleted scene is currently open:**
   - Check if there are other scenes in the collection
   - If yes → Navigate to another scene (using `replaceUrl`)
   - If no → Navigate to dashboard (using `replaceUrl`)

2. **If deleted scene is not currently open:**
   - Just remove from list, no navigation needed

**Critical: Using `replaceUrl` instead of `navigateTo`**

When deleting a scene, we use `replaceUrl()` instead of `navigateTo()` (which uses `pushState`). This **replaces** the deleted scene URL in browser history rather than adding a new entry. This prevents the browser Back button from returning to the deleted scene URL.

```typescript
const handleDeleteScene = async (sceneId: string) => {
  await deleteSceneApi(sceneId);
  const remainingScenes = scenes.filter((s) => s.id !== sceneId);
  
  if (currentSceneId === sceneId) {
    if (remainingScenes.length > 0) {
      // Use replaceUrl to replace deleted scene URL in history
      setCurrentSceneId(remainingScenes[0].id);
      setCurrentSceneTitle(remainingScenes[0].title);
      replaceUrl(buildSceneUrl(workspaceSlug, remainingScenes[0].id));
    } else {
      // Use replaceUrl to replace deleted scene URL with dashboard
      setAppMode("dashboard");
      setDashboardView("home");
      setCurrentSceneId(null);
      replaceUrl(buildDashboardUrl(workspaceSlug));
    }
  }
};
```

**Same for error handling:** When a scene fails to load (e.g., deleted scene accessed via Back button), we also use `replaceUrl` to redirect to dashboard without leaving the invalid URL in history.

## Anonymous Mode

For unauthenticated users, the original Excalidraw behavior is preserved:

- URL: `/?mode=anonymous` or root `/`
- Canvas is shown directly (no dashboard)
- Data stored in localStorage
- No backend scene management

```typescript
const [isLegacyMode, setIsLegacyMode] = useState<boolean>(() => {
  const params = new URLSearchParams(window.location.search);
  return (
    params.get("mode") === "anonymous" ||
    !!window.location.hash.match(LEGACY_ROOM_PATTERN)
  );
});
```

## Files Involved

| File | Purpose |
|------|---------|
| `App.tsx` | Main component, scene loading logic, conditional rendering |
| `settingsState.ts` | Navigation atoms, app mode state |
| `router.ts` | URL parsing and building |
| `WorkspaceSidebar.tsx` | Scene list, deletion with fallback |
| `workspaceSceneLoader.ts` | Backend API for loading scene data |

## Comparison with Room Service

| Aspect | Room Service (Collaboration) | Workspace Scenes |
|--------|------------------------------|------------------|
| URL | `/#room={roomId},{roomKey}` | `/workspace/{slug}/scene/{id}` |
| Data source | WebSocket real-time sync | Backend API fetch |
| State | Shared between collaborators | Personal (unless collaborating) |
| Persistence | Room server | PostgreSQL + MinIO |
| Switching | Connect to different room | Fetch different scene data |

Both work the same conceptually: **URL = specific data**. Navigating to a URL loads that specific content.

## Testing Checklist

- [ ] Login redirects to dashboard (not empty canvas)
- [ ] Clicking scene from dashboard loads correct scene
- [ ] Scene data persists: dashboard → scene → dashboard → same scene
- [ ] Rapid scene switching loads correct final scene
- [ ] Deleting current scene navigates to another scene
- [ ] Deleting last scene in collection navigates to dashboard
- [ ] Browser back/forward works correctly
- [ ] Bookmarked scene URLs load correctly
- [ ] Anonymous mode still works
- [ ] Creating new scene works correctly
- [ ] URL always reflects current view

## Known Issues / Future Improvements

1. **Initial load optimization:** Could preload scene data while showing loading spinner
2. **Scene caching:** Could cache recently viewed scenes to speed up back navigation
3. **Optimistic UI:** Could show scene card thumbnail while full data loads

## Related Documentation

- [URL Routing](./URL_ROUTING.md) - Full URL routing documentation
- [Workspace](./WORKSPACE.md) - Workspace and scene management
- [Architecture](./ARCHITECTURE.md) - Overall system architecture

