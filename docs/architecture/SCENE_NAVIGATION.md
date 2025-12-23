# Scene Navigation Architecture

## Overview

This document describes the scene navigation architecture in AstraDraw, using the **CSS Hide/Show pattern** where both dashboard and canvas are always mounted, with CSS controlling visibility.

> **Status:** Implementation complete (December 2025)  
> **Critical Reference:** See `/docs/CRITICAL_CSS_HIDE_SHOW_FIX.md` for why this pattern is used

## Core Concept

**CSS Hide/Show Pattern:**
- Both Dashboard and Canvas components are **always mounted**
- CSS `display: none` toggles visibility based on `appMode`
- Excalidraw **never unmounts**, preserving all state
- Scene data is loaded via `excalidrawAPI.updateScene()`

```
┌─────────────────────────────────────────────────────────────┐
│                    AstraDraw Application                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │  Dashboard Content  │    │     Excalidraw      │        │
│  │  (always mounted)   │    │  (always mounted)   │        │
│  │                     │    │                     │        │
│  │  display: block ◄───┼────┼── Dashboard mode    │        │
│  │  display: none  ◄───┼────┼── Canvas mode       │        │
│  └─────────────────────┘    └─────────────────────┘        │
│                                                             │
│  Both components stay in DOM - only visibility changes      │
└─────────────────────────────────────────────────────────────┘
```

### Why NOT Conditional Rendering

The original implementation used conditional rendering, which caused **data loss**:

```tsx
// ❌ OLD BUGGY PATTERN - DO NOT USE
if (appMode === "dashboard") {
  return <Dashboard />;  // Excalidraw UNMOUNTS here!
}
return <Excalidraw />;   // Excalidraw REMOUNTS with stale data
```

When Excalidraw unmounts/remounts, all internal state is lost. See `/docs/CRITICAL_CSS_HIDE_SHOW_FIX.md` for the full explanation.

## URL Structure

Each view has a permanent, unique URL:

| View | URL Pattern | Example |
|------|-------------|---------|
| Dashboard | `/workspace/{slug}/dashboard` | `/workspace/admin/dashboard` |
| Collection | `/workspace/{slug}/collection/{id}` | `/workspace/admin/collection/abc123` |
| Private Collection | `/workspace/{slug}/private` | `/workspace/admin/private` |
| **Scene (Canvas)** | `/workspace/{slug}/scene/{id}` | `/workspace/admin/scene/xyz789` |
| Scene with Collab | `/workspace/{slug}/scene/{id}#key={roomKey}` | `/workspace/admin/scene/xyz789#key=abc` |

## How Scene Loading Works

### Current Implementation (CSS Hide/Show)

```
User clicks scene card
         │
         ▼
┌─────────────────────────────────────┐
│  1. navigateToSceneAtom called      │
│     - Sets currentSceneIdAtom       │
│     - Sets appModeAtom("canvas")    │
│     - Pushes URL via navigateTo()   │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  2. CSS shows canvas                │
│     display: none → display: block  │
│     (Excalidraw was already mounted)│
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  3. handlePopState fires            │
│     - Parses URL                    │
│     - Calls loadSceneFromUrl()      │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  4. Track request ID                │
│     currentLoadingSceneId = sceneId │
│     (For race condition handling)   │
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
│  7. Update canvas via API           │
│     excalidrawAPI.updateScene({     │
│       elements, appState, files     │
│     })                              │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  8. Scene is displayed              │
│     Canvas shows correct content ✅  │
└─────────────────────────────────────┘
```

### Key Difference from Old Pattern

| Aspect | Old Pattern | CSS Hide/Show |
|--------|-------------|---------------|
| Excalidraw lifecycle | Unmounts on dashboard, remounts on canvas | Always mounted |
| Scene loading | Reset `initialStatePromiseRef`, resolve with data | Call `updateScene()` directly |
| State preservation | Lost on mode switch | Preserved |
| Loading UI | Early return with spinner | Overlay on top of canvas |

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
                       Result: APPLIED via updateScene()
```

## Key Components

### CSS Hide/Show Structure (App.tsx)

```tsx
return (
  <>
    {/* Dashboard - always mounted, hidden when in canvas mode */}
    <div 
      style={{ display: appMode === "dashboard" ? "block" : "none" }}
      aria-hidden={appMode !== "dashboard"}
    >
      <WorkspaceMainContent />
    </div>
    
    {/* Canvas - ALWAYS MOUNTED, hidden when in dashboard mode */}
    <div 
      style={{ display: appMode === "canvas" ? "block" : "none" }}
      aria-hidden={appMode !== "canvas"}
      inert={appMode !== "canvas" ? true : undefined}
    >
      <Excalidraw 
        handleKeyboardGlobally={appMode === "canvas"}
        autoFocus={appMode === "canvas"}
      />
    </div>
  </>
);
```

### Navigation Atoms (settingsState.ts)

```typescript
// Navigate to dashboard - clears scene state
export const navigateToDashboardAtom = atom(null, (get, set) => {
  set(appModeAtom, "dashboard");
  set(dashboardViewAtom, "home");
  set(currentSceneIdAtom, null);
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

### Scene Loading (App.tsx)

```typescript
const loadSceneFromUrl = async (workspaceSlug: string, sceneId: string) => {
  // Track current request for race condition handling
  currentLoadingSceneId = sceneId;
  
  // Fetch scene data
  const loaded = await loadWorkspaceScene(workspaceSlug, sceneId);
  
  // Ignore stale requests
  if (currentLoadingSceneId !== sceneId) {
    return;
  }
  
  // Update already-mounted Excalidraw via API
  excalidrawAPI.updateScene({
    elements: loaded.data.elements || [],
    appState: loaded.data.appState || {},
    files: loaded.data.files || {},
  });
};
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

When deleting a scene, we use `replaceUrl()` to **replace** the deleted scene URL in browser history rather than adding a new entry. This prevents the browser Back button from returning to the deleted scene URL.

## Anonymous Mode

For unauthenticated users, the original Excalidraw behavior is preserved:

- URL: `/?mode=anonymous` or root `/`
- Canvas is shown directly (no dashboard)
- Data stored in localStorage
- No backend scene management

## Files Involved

| File | Purpose |
|------|---------|
| `App.tsx` | CSS Hide/Show structure, scene loading via `updateScene()` |
| `settingsState.ts` | Navigation atoms, app mode state |
| `router.ts` | URL parsing and building |
| `WorkspaceSidebar.tsx` | Scene list, deletion with fallback |
| `workspaceSceneLoader.ts` | Backend API for loading scene data |
| `index.scss` | CSS for canvas container and pointer-events blocking |

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
- [ ] Keyboard shortcuts only work when canvas is visible
- [ ] Dashboard inputs don't trigger canvas shortcuts

## Related Documentation

- [CRITICAL: CSS Hide/Show Fix](../troubleshooting/CRITICAL_CSS_HIDE_SHOW_FIX.md) - Why this pattern is critical
- [URL Routing](URL_ROUTING.md) - Full URL routing documentation
- [Scene Navigation Tests](../troubleshooting/SCENE_NAVIGATION_TESTS.md) - Test scenarios
