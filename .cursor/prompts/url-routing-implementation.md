# Prompt: Implement URL-Based Navigation for AstraDraw

## Task Overview

Implement proper URL-based navigation for AstraDraw, following the patterns used by Excalidraw Plus. This will fix the critical bug where scene data is lost when navigating between dashboard and canvas views.

## Required Reading

Before starting, read these documents:

1. **`/docs/URL_ROUTING.md`** - Detailed specification of URL patterns and implementation plan
2. **`/docs/ARCHITECTURE.md`** - Overall system architecture
3. **`/docs/WORKSPACE.md`** - Workspace and scene management

## Problem Statement

Currently, when users navigate from a scene to the dashboard and back:
1. The URL stays as `/workspace/{slug}/scene/{id}` even when viewing dashboard
2. The Excalidraw component unmounts when in dashboard mode
3. On returning to canvas, re-initialization causes race conditions
4. Scene data is lost or overwritten by localStorage sync

## Solution: URL-Based Navigation

Implement URL routing where each view has its own URL:

| View | URL Pattern |
|------|-------------|
| Dashboard | `/workspace/{slug}/dashboard` |
| Collection | `/workspace/{slug}/collection/{id}` |
| Private | `/workspace/{slug}/private` |
| Scene | `/workspace/{slug}/scene/{id}` |
| Settings | `/workspace/{slug}/settings` |
| Members | `/workspace/{slug}/members` |
| Teams | `/workspace/{slug}/teams` |

## Implementation Steps

### Step 1: Create URL Router Utility

Create `frontend/excalidraw-app/router.ts`:
- Define URL patterns as constants
- Create functions to parse URLs and extract parameters
- Create functions to build URLs from parameters
- Handle URL changes via `popstate` event

### Step 2: Update Navigation Atoms

Modify `frontend/excalidraw-app/components/Settings/settingsState.ts`:
- Update `navigateToDashboardAtom` to change URL
- Update `navigateToCollectionAtom` to change URL
- Update `navigateToCanvasAtom` to change URL
- Add new atoms for settings, members, teams navigation

### Step 3: Update App.tsx Initialization

Modify `frontend/excalidraw-app/App.tsx`:
- Add URL parsing on initial load
- Add `popstate` event listener for browser navigation
- Route to correct view based on URL
- Keep Excalidraw mounted but control visibility

### Step 4: Update Navigation Triggers

Update these components to use URL navigation:
- `WorkspaceSidebar.tsx` - Dashboard, collection clicks
- `DashboardView.tsx` - Scene clicks
- `CollectionView.tsx` - Scene clicks
- `WorkspaceMainContent.tsx` - View routing

### Step 5: Scene Loading from URL

When URL is `/workspace/{slug}/scene/{id}`:
1. Parse scene ID from URL
2. Fetch scene data from backend
3. Update Excalidraw canvas
4. Set `currentSceneId` state

### Step 6: Handle Edge Cases

- Invalid scene ID in URL → Show error or redirect to dashboard
- User not authenticated → Redirect to login with return URL
- Scene in different workspace → Handle workspace switch or show error

### Step 7: Fix localStorage Sync Conflict

**Important:** There's a `syncData` function in `App.tsx` (around line 894) that syncs canvas data from localStorage on visibility change. This was designed for anonymous mode but conflicts with workspace scenes.

Add a guard to skip localStorage sync when working on a workspace scene:

```typescript
const syncData = debounce(() => {
  if (isTestEnv()) return;
  
  // Skip localStorage sync when working on a workspace scene
  if (currentSceneId) return;
  
  // ... rest of sync logic for anonymous mode
}, SYNC_BROWSER_TABS_TIMEOUT);
```

Use a ref (`currentSceneIdRef`) to access the current scene ID in the closure without adding it to useEffect dependencies.

## Nginx Configuration (Already Done)

The nginx config at `frontend/nginx.conf` already supports SPA client-side routing:

```nginx
# SPA fallback - serve index.html for all routes that don't match static files
location / {
    try_files $uri $uri/ /index.html;
}
```

This means:
- All new routes (`/workspace/{slug}/dashboard`, `/workspace/{slug}/collection/{id}`, etc.) will work automatically
- Nginx serves `index.html` for any path that doesn't match a static file
- React/JavaScript handles the actual routing based on `window.location.pathname`

**No nginx changes needed** - just implement the client-side routing in JavaScript.

## Constraints

1. **Don't break existing functionality** - Anonymous mode, collaboration links must still work
2. **Backward compatibility** - Old URLs should still work (redirect if needed)
3. **No backend changes required** - Use existing API endpoints
4. **Room service unchanged** - Collaboration uses scene IDs, not URLs
5. **No nginx changes needed** - SPA fallback already configured

## Files to Modify

### Frontend (Primary)
- `excalidraw-app/App.tsx` - Main routing logic
- `excalidraw-app/components/Settings/settingsState.ts` - Navigation atoms
- `excalidraw-app/components/Workspace/WorkspaceSidebar.tsx` - Navigation triggers
- `excalidraw-app/components/Workspace/DashboardView.tsx` - Scene clicks
- `excalidraw-app/components/Workspace/CollectionView.tsx` - Scene clicks
- `excalidraw-app/components/Workspace/WorkspaceMainContent.tsx` - View routing

### Frontend (New)
- `excalidraw-app/router.ts` - URL routing utilities (optional, can inline)

### Backend
- No changes required

### Room Service
- No changes required

## Testing Scenarios

After implementation, verify:

1. **URL reflects current view**
   - Open scene → URL is `/workspace/{slug}/scene/{id}`
   - Click Dashboard → URL changes to `/workspace/{slug}/dashboard`
   - Click collection → URL changes to `/workspace/{slug}/collection/{id}`

2. **Browser navigation works**
   - Click back → Returns to previous view
   - Click forward → Goes to next view
   - Refresh page → Same view loads

3. **Scene data persists**
   - Draw on scene A
   - Go to dashboard
   - Open scene B
   - Go back to scene A → Drawings are there

4. **URLs are shareable**
   - Copy scene URL
   - Open in new tab → Scene loads correctly
   - Open in different browser (logged in) → Scene loads correctly

## Reference: Excalidraw Plus URLs

```
Dashboard:    https://app.excalidraw.com/w/AEloUCCjjMP/dashboard
Settings:     https://app.excalidraw.com/o/AEloUCCjjMP/settings
Collection:   https://app.excalidraw.com/o/AEloUCCjjMP/YjdoG4t02r
Private:      https://app.excalidraw.com/o/AEloUCCjjMP/private
Scene:        https://app.excalidraw.com/s/AEloUCCjjMP/9tF8csMGHBR
```

## Success Criteria

- [ ] All views have unique URLs
- [ ] Browser back/forward works
- [ ] Page refresh preserves view
- [ ] Scene data never lost on navigation
- [ ] Auto-save continues to work
- [ ] Collaboration still works
- [ ] Anonymous mode still works
- [ ] `just check-all` passes

