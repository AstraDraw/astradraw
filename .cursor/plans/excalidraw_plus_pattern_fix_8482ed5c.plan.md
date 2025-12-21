---
name: Excalidraw Plus Pattern Fix
overview: Implement the Excalidraw Plus navigation pattern to fix scene reset bug
todos:
  - id: backend-private-collection
    content: Create private collection when shared workspace is created
    status: completed
  - id: add-loading-state
    content: Add isLoadingScene and sceneDataLoaded state to App.tsx
    status: completed
  - id: update-initial-load
    content: Redirect authenticated users from root URL to dashboard
    status: completed
  - id: update-scene-loader
    content: Update loadSceneFromUrl to manage loading states
    status: completed
  - id: conditional-render
    content: Add conditional rendering - show loading while fetching scene
    status: completed
  - id: update-delete-handler
    content: Update scene deletion to fallback to another scene or dashboard
    status: completed
  - id: clear-scene-on-dashboard
    content: Clear currentSceneId when navigating to dashboard
    status: completed
  - id: testing
    content: Test all navigation scenarios
    status: pending
---

# Fix Scene Reset Bug with Excalidraw Plus Pattern

## Overview

Implement the Excalidraw Plus navigation pattern where authenticated users always start in dashboard mode, and the canvas only renders when a scene is explicitly loaded. This eliminates the race condition causing scene data to reset.

## Current Problem

When navigating from dashboard to a scene, there's a race condition:

1. `navigateToSceneAtom` sets `appMode` to `"canvas"` immediately
2. Excalidraw component renders with stale `initialStatePromiseRef` data
3. Scene data loads AFTER the canvas already rendered with wrong data

## Solution: Canvas Only With Scene

The canvas should only be shown when:

- User is authenticated AND
- A scene is being loaded/has been loaded AND
- Scene data fetch is complete

For unauthenticated users, anonymous mode works as before (canvas shown directly).

## Implementation

### 0. Backend: Create Private Collection for Shared Workspaces

**Problem:** Currently, only personal workspaces get a private collection. Shared workspaces don't, which breaks the "New scene" button fallback.

**Fix:** Update [workspaces.service.ts](backend/src/workspaces/workspaces.service.ts) `createSharedWorkspace` method to also create a private collection for the creator:

```typescript
async createSharedWorkspace(userId: string, dto: CreateWorkspaceDto): Promise<WorkspaceWithRole> {
  const slug = dto.slug || (await this.generateSlug(dto.name));
  
  const workspace = await this.prisma.workspace.create({
    data: {
      name: dto.name,
      slug,
      avatarUrl: dto.avatarUrl,
      type: WorkspaceType.SHARED,
      members: {
        create: {
          userId,
          role: WorkspaceRole.ADMIN,
        },
      },
      // Create a private collection for the creator
      collections: {
        create: {
          name: 'Private',
          icon: '🔒',
          isPrivate: true,
          userId,
        },
      },
    },
    // ...
  });
}
```

### 1. Add Scene Loading State

In [App.tsx](frontend/excalidraw-app/App.tsx), add a loading state to track when scene data is being fetched:

```typescript
const [isLoadingScene, setIsLoadingScene] = useState(false);
const [sceneDataLoaded, setSceneDataLoaded] = useState(false);
```

### 2. Modify Initial Load for Authenticated Users

When user is authenticated and URL is root (`/`), redirect to dashboard instead of showing empty canvas:

```typescript
// In the initialization effect
if (isAuthenticated && initialRoute.type === "home") {
  // Redirect to dashboard instead of showing empty canvas
  navigateToDashboard();
  return;
}
```

### 3. Update loadSceneFromUrl Function

Set loading state before fetching, and mark data as loaded after:

```typescript
const loadSceneFromUrl = async (workspaceSlug, sceneId) => {
  setIsLoadingScene(true);
  setSceneDataLoaded(false);
  try {
    const loaded = await loadWorkspaceScene(workspaceSlug, sceneId);
    // ... existing scene loading logic ...
    excalidrawAPI.updateScene({ elements, appState });
    setSceneDataLoaded(true);
  } finally {
    setIsLoadingScene(false);
  }
};
```

### 4. Conditional Canvas Rendering

Only render Excalidraw when we have scene data:

```typescript
// In render, show loading state while fetching scene
if (appMode === "canvas" && isLoadingScene) {
  return <LoadingSpinner message={t("workspace.loadingScene")} />;
}

// Only render Excalidraw when scene data is loaded
if (appMode === "canvas" && !sceneDataLoaded && currentSceneId) {
  return <LoadingSpinner />;
}
```

### 5. Scene Deletion Fallback Logic

In [WorkspaceSidebar.tsx](frontend/excalidraw-app/components/Workspace/WorkspaceSidebar.tsx) and [BoardModeNav.tsx](frontend/excalidraw-app/components/Workspace/BoardModeNav.tsx), update delete handler:

```typescript
const handleDeleteScene = async (sceneId: string) => {
  await deleteSceneApi(sceneId);
  
  // Find another scene in the same collection
  const remainingScenes = scenes.filter(s => s.id !== sceneId);
  
  if (remainingScenes.length > 0) {
    // Navigate to another scene in the collection
    navigateToScene({ sceneId: remainingScenes[0].id, ... });
  } else {
    // No scenes left, go to dashboard
    navigateToDashboard();
  }
};
```

### 6. Reset Scene State on Dashboard Navigation

When navigating to dashboard, clear scene state:

```typescript
// In navigateToDashboardAtom
set(currentSceneIdAtom, null);
set(currentSceneTitleAtom, "Untitled");
// Also reset sceneDataLoaded in App.tsx
```

### 7. Handle New Scene Creation

The existing `handleNewScene` already creates the scene first, then navigates. Just ensure it sets `sceneDataLoaded` to true after creating.

## Files to Modify

| File | Changes |

|------|---------|

| [workspaces.service.ts](backend/src/workspaces/workspaces.service.ts) | Create private collection when shared workspace is created |

| [App.tsx](frontend/excalidraw-app/App.tsx) | Add loading states, conditional rendering, update initialization |

| [settingsState.ts](frontend/excalidraw-app/components/Settings/settingsState.ts) | Clear scene ID on dashboard navigation |

| [WorkspaceSidebar.tsx](frontend/excalidraw-app/components/Workspace/WorkspaceSidebar.tsx) | Update delete handler with fallback logic |

| [BoardModeNav.tsx](frontend/excalidraw-app/components/Workspace/BoardModeNav.tsx) | Update delete handler with fallback logic |

## User Experience Summary

```
Unauthenticated User:
  / (root) → Anonymous canvas (unchanged behavior)

Authenticated User:
  / (root) → Redirect to /workspace/{slug}/dashboard
  Dashboard → Shows scenes, collections
  "New scene" → Creates in private collection (every workspace has one)
  Click scene → Loading spinner → Canvas with scene data
  Delete scene → Fallback to another scene OR dashboard
  Browser back → Previous view (dashboard or scene)
```

## Testing Checklist

- [ ] Login redirects to dashboard (not empty canvas)
- [ ] Clicking scene from dashboard loads scene correctly
- [ ] Scene data persists when navigating dashboard → scene → dashboard → same scene
- [ ] Deleting scene navigates to another scene in collection
- [ ] Deleting last scene in collection navigates to dashboard
- [ ] Browser back/forward works correctly
- [ ] Anonymous mode still works (shows canvas directly)
- [ ] Creating new scene works correctly
- [ ] New shared workspace has private collection
- [ ] "New scene" button works in shared workspaces