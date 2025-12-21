# URL Routing Implementation

## Overview

This document describes the URL routing architecture for AstraDraw. Proper URL routing ensures:

- Browser history works correctly (back/forward buttons)
- Pages can be refreshed without losing context
- URLs can be shared and bookmarked
- No state confusion between views
- Clean separation between canvas and dashboard modes
- Scene data persistence when navigating between views

> **Related:** See [Scene Navigation](./SCENE_NAVIGATION.md) for detailed documentation on how scene loading works, including race condition handling and the "Excalidraw Plus pattern" implementation.

## URL Structure

### URL Patterns

| View | URL Pattern | Example |
|------|-------------|---------|
| Dashboard | `/workspace/{slug}/dashboard` | `/workspace/admin/dashboard` |
| Collection View | `/workspace/{slug}/collection/{collectionId}` | `/workspace/admin/collection/abc123` |
| Private Collection | `/workspace/{slug}/private` | `/workspace/admin/private` |
| Scene (Canvas) | `/workspace/{slug}/scene/{sceneId}` | `/workspace/admin/scene/xyz789` |
| Settings | `/workspace/{slug}/settings` | `/workspace/admin/settings` |
| Members | `/workspace/{slug}/members` | `/workspace/admin/members` |
| Teams & Collections | `/workspace/{slug}/teams` | `/workspace/admin/teams` |
| Profile | `/profile` | `/profile` |
| Invite Accept | `/invite/{code}` | `/invite/abc123` |
| Anonymous Mode | `/?mode=anonymous` | `/?mode=anonymous` |
| Legacy Collaboration | `/#room={roomId},{roomKey}` | `/#room=abc123,xyz789` |

### URL Hierarchy

```
/
├── /workspace/{slug}/
│   ├── /dashboard          # Dashboard home (recently modified, visited)
│   ├── /private            # Private collection view
│   ├── /collection/{id}    # Named collection view
│   ├── /scene/{id}         # Canvas/drawing view
│   ├── /settings           # Workspace settings
│   ├── /members            # Team members management
│   └── /teams              # Teams & Collections management
├── /profile                # User profile (cross-workspace)
├── /invite/{code}          # Invite link acceptance
└── /?mode=anonymous        # Anonymous drawing mode
```

## Architecture

### Router Module (`router.ts`)

The URL router is implemented in `frontend/excalidraw-app/router.ts` and provides:

#### Route Type Definition

```typescript
export type RouteType =
  | { type: "dashboard"; workspaceSlug: string }
  | { type: "collection"; workspaceSlug: string; collectionId: string }
  | { type: "private"; workspaceSlug: string }
  | { type: "scene"; workspaceSlug: string; sceneId: string }
  | { type: "settings"; workspaceSlug: string }
  | { type: "members"; workspaceSlug: string }
  | { type: "teams"; workspaceSlug: string }
  | { type: "profile" }
  | { type: "invite"; code: string }
  | { type: "anonymous" }
  | { type: "legacy-collab"; roomId: string; roomKey: string }
  | { type: "home" };
```

#### URL Parsing

```typescript
// Parse current URL and return route type
const route = parseUrl(); // Uses window.location.href by default
const route = parseUrl("https://example.com/workspace/admin/dashboard");
```

#### URL Building

```typescript
buildDashboardUrl(workspaceSlug: string): string
buildPrivateUrl(workspaceSlug: string): string
buildCollectionUrl(workspaceSlug: string, collectionId: string): string
buildSceneUrl(workspaceSlug: string, sceneId: string, roomKey?: string): string
buildSettingsUrl(workspaceSlug: string): string
buildMembersUrl(workspaceSlug: string): string
buildTeamsUrl(workspaceSlug: string): string
buildProfileUrl(): string
buildInviteUrl(code: string): string
buildAnonymousUrl(): string
```

#### Navigation Helpers

```typescript
// Push URL to history (triggers popstate event)
navigateTo(url: string, state?: object): void

// Replace current URL without adding to history
replaceUrl(url: string, state?: object): void

// Route type helpers
isWorkspaceRoute(route: RouteType): boolean
isDashboardRoute(route: RouteType): boolean
isCanvasRoute(route: RouteType): boolean
getWorkspaceSlug(route: RouteType): string | null
```

### Navigation Atoms (`settingsState.ts`)

Navigation is managed via Jotai atoms that update both app state AND push URLs:

```typescript
// State atoms
currentWorkspaceSlugAtom    // Current workspace slug
currentSceneIdAtom          // Current scene ID (null when not editing)
currentSceneTitleAtom       // Current scene title
activeCollectionIdAtom      // Active collection ID
isPrivateCollectionAtom     // Whether active collection is private
appModeAtom                 // "canvas" | "dashboard"
dashboardViewAtom           // "home" | "collection" | "profile" | "workspace" | "members" | "teams-collections"

// Navigation action atoms (push URLs automatically)
navigateToDashboardAtom     // → /workspace/{slug}/dashboard
navigateToCollectionAtom    // → /workspace/{slug}/collection/{id} or /workspace/{slug}/private
navigateToSceneAtom         // → /workspace/{slug}/scene/{id}
navigateToProfileAtom       // → /profile
navigateToWorkspaceSettingsAtom  // → /workspace/{slug}/settings
navigateToMembersAtom       // → /workspace/{slug}/members
navigateToTeamsCollectionsAtom   // → /workspace/{slug}/teams
navigateToCanvasAtom        // Only changes appMode, URL set by scene loading
```

### URL Synchronization (`App.tsx`)

The main app component handles:

1. **Initial URL parsing** - On mount, parse URL and set initial state
2. **Popstate handling** - Listen for browser back/forward navigation
3. **Scene loading** - Load scene data when URL contains scene ID
4. **State sync** - Keep Jotai atoms in sync with URL

```typescript
// URL sync effect in App.tsx
useEffect(() => {
  const handlePopState = async (event: PopStateEvent) => {
    const route = parseUrl();
    // Handle route type and update state accordingly
  };

  window.addEventListener("popstate", handlePopState);
  return () => window.removeEventListener("popstate", handlePopState);
}, [/* dependencies */]);
```

## Data Flow

### Navigation from Dashboard to Scene

The navigation flow uses URL-driven state management. When a user clicks on a scene card, the navigation atom pushes a URL change, which triggers the `popstate` handler to load the scene.

```
User clicks scene card (DashboardView, CollectionView, or WorkspaceSidebar)
  → navigateToSceneAtom({ workspaceSlug, sceneId, title })
    → Sets Jotai atoms (currentSceneIdAtom, currentSceneTitleAtom, appModeAtom)
    → Calls navigateTo(buildSceneUrl(workspaceSlug, sceneId))
      → pushState + dispatch popstate event
        → handlePopState catches the event
          → parseUrl() detects route.type === "scene"
          → Calls loadSceneFromUrlRef.current(workspaceSlug, sceneId)
            → loadWorkspaceScene() fetches scene metadata + data from API
            → Updates Excalidraw canvas with scene elements
            → Sets local state (currentSceneId, currentSceneTitle, etc.)
            → Starts collaboration if scene has roomId and user has access
            → navigateToCanvas() switches to canvas mode
```

**Key points:**
- Scene loading is centralized in `loadSceneFromUrl()` function in `App.tsx`
- The function is stored in a ref (`loadSceneFromUrlRef`) so it can be called from `handlePopState`
- Components (DashboardView, CollectionView, WorkspaceSidebar) don't load scene data directly
- They only call `navigateToSceneAtom` which triggers the URL change

### Navigation from Scene to Dashboard

```
User clicks "Dashboard" in sidebar
  → navigateToDashboard()
    → set appModeAtom("dashboard")
    → set dashboardViewAtom("home")
    → navigateTo(buildDashboardUrl(workspaceSlug))
      → pushState + dispatch popstate event
```

### Browser Back/Forward

```
User clicks browser back button
  → popstate event fires
  → handlePopState callback in App.tsx
    → parseUrl() to get route type
    → If scene route AND sceneId changed:
      → setCurrentWorkspaceSlugAtom(route.workspaceSlug)
      → navigateToCanvas()
      → loadSceneFromUrlRef.current(workspaceSlug, sceneId)
        → Full scene loading (same as clicking scene card)
    → If dashboard route:
      → handleUrlRoute(route) updates dashboard state
```

## localStorage Sync Guard

**Critical fix**: The `syncData` function in `App.tsx` syncs canvas data from localStorage on visibility change. This was designed for anonymous mode but conflicts with workspace scenes, causing data loss.

A guard was added to skip localStorage sync when working on a workspace scene:

```typescript
const syncData = debounce(() => {
  if (isTestEnv()) return;

  // Skip localStorage sync when working on a workspace scene
  // This prevents overwriting scene data with stale localStorage data
  if (currentSceneIdRef.current) return;

  // ... rest of sync logic for anonymous mode only
}, SYNC_BROWSER_TABS_TIMEOUT);
```

This ensures:
- Anonymous mode continues to sync across browser tabs
- Workspace scenes are loaded/saved only via backend API
- No race condition between localStorage and backend data

## Backward Compatibility

The following patterns continue to work:

| Pattern | Behavior |
|---------|----------|
| `/?mode=anonymous` | Anonymous drawing mode |
| `/#room={roomId},{roomKey}` | Legacy collaboration links |
| `/invite/{code}` | Invite link acceptance |
| `/workspace/{slug}/scene/{id}` | Direct scene URLs (existing) |
| `/workspace/{slug}/scene/{id}#key={roomKey}` | Scene with collaboration key |

## Nginx Configuration

No changes needed - the nginx config at `frontend/nginx.conf` already supports SPA client-side routing:

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

All routes are handled by the React app since nginx serves `index.html` for any path that doesn't match a static file.

## Files Overview

| File | Purpose |
|------|---------|
| `excalidraw-app/router.ts` | URL routing utilities (parseUrl, buildUrl, navigateTo) |
| `excalidraw-app/components/Settings/settingsState.ts` | Navigation atoms with URL support |
| `excalidraw-app/App.tsx` | URL sync hook, scene loading via `loadSceneFromUrl()`, state management |
| `excalidraw-app/components/Workspace/WorkspaceSidebar.tsx` | Sidebar navigation, uses `navigateToSceneAtom` directly |
| `excalidraw-app/components/Workspace/DashboardView.tsx` | Dashboard with scene navigation, uses `navigateToSceneAtom` directly |
| `excalidraw-app/components/Workspace/CollectionView.tsx` | Collection view with scene navigation, uses `navigateToSceneAtom` directly |
| `excalidraw-app/components/Workspace/WorkspaceMainContent.tsx` | Dashboard content router, renders view based on `dashboardViewAtom` |
| `excalidraw-app/components/Workspace/FullModeNav.tsx` | Full navigation with collection click handlers |

## Testing Checklist

- [x] Dashboard URL loads dashboard view
- [x] Collection URL loads collection view
- [x] Private collection URL works (`/workspace/{slug}/private`)
- [x] Scene URL loads scene with data
- [x] Browser back button returns to previous view
- [x] Browser forward button goes to next view
- [x] Page refresh preserves current view
- [x] URLs can be shared and opened in new tab
- [x] Scene auto-save works after navigation
- [x] Scene data persists after dashboard → scene navigation
- [x] Anonymous mode still works
- [x] Legacy collaboration links still work
- [x] Invite links still work

## Common Issues

### Scene Data Loss

**Problem**: Scene data is lost when navigating between dashboard and canvas.

**Causes**:
1. localStorage sync overwrites backend data
2. URL doesn't change, causing state confusion
3. Excalidraw component re-initializes

**Solution**: 
- Added localStorage sync guard for workspace scenes
- All navigation now updates URLs
- State is derived from URL on popstate

### URL Not Updating

**Problem**: URL stays the same when navigating between views.

**Solution**: All navigation atoms now call `navigateTo()` which uses `history.pushState()` and dispatches a `popstate` event.

### Browser Back Not Working

**Problem**: Browser back button doesn't navigate correctly.

**Solution**: Added `popstate` event listener in `App.tsx` that parses the URL and updates app state accordingly.

### "Failed to open scene" When Clicking Scene from Dashboard

> ⚠️ **Work in Progress (December 2025)**: This fix is functional but needs further testing across all scenarios (collections, teams, different navigation paths). The approach is correct but edge cases may exist.

**Problem**: After creating a new scene and returning to the dashboard, clicking on the scene shows "Failed to open scene" error and the URL doesn't update (stays at `/workspace/{slug}/dashboard`).

**Root Causes Identified**:
1. **Infinite loop bug**: `handleUrlRoute` called navigation atoms that pushed URLs, triggering `popstate`, which called `handleUrlRoute` again → stack overflow
2. **Scene loading not triggered**: `handlePopState` didn't set `appMode` to canvas or call scene loading
3. **Initial URL not handled**: Page load with dashboard URL showed canvas instead of dashboard
4. Scene loading logic was fragmented across multiple components

**Current Fix** (December 2025):

1. **`handleUrlRoute` now sets state directly** - no URL pushing to avoid infinite loops:
```typescript
case "dashboard":
  setAppMode("dashboard");  // Direct state set, NOT navigateToDashboard()
  setDashboardView("home");
  break;
```

2. **`handlePopState` sets canvas mode before loading scenes**:
```typescript
if (route.type === "scene") {
  setAppMode("canvas");  // Switch UI immediately
  setCurrentWorkspaceSlugAtom(route.workspaceSlug);
  if (loadSceneFromUrlRef.current) {
    await loadSceneFromUrlRef.current(route.workspaceSlug, route.sceneId);
  }
}
```

3. **Initial URL handling on page load**:
```typescript
const initialRoute = parseUrl();
if (initialRoute.type !== "scene") {
  handleUrlRoute(initialRoute);  // Sets dashboard mode for dashboard URLs
}
```

4. **Centralized scene loading** via `loadSceneFromUrl()` in `App.tsx`, stored in ref

**Key Principle**: URL navigation should be one-way:
- **User action** → Navigation atom → Push URL → Dispatch popstate
- **Popstate handler** → Parse URL → Set state directly (NO URL push)

**Testing Needed**:
- [ ] Dashboard → Scene → Back button
- [ ] Collection view → Scene → Back button
- [ ] Private collection → Scene
- [ ] Teams/Collections page navigation
- [ ] Profile page navigation
- [ ] Settings pages navigation
- [ ] Direct URL access to all route types
- [ ] Browser refresh on each route type
- [ ] Creating new scenes from different contexts
