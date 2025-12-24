# MVP Release Bug Tracking

**Document Purpose:** Track and fix all bugs discovered before the first MVP release of AstraDraw.

**Status:** 🟡 In Progress  
**Target Release:** MVP v1.0.0  
**Last Updated:** 2025-12-25

---

## Summary

| Category | Total | Critical | High | Medium | Low | Fixed |
|----------|-------|----------|------|--------|-----|-------|
| Frontend | 1 | 0 | 1 | 0 | 0 | 0 |
| Backend | 0 | 0 | 0 | 0 | 0 | 0 |
| Collaboration | 3 | 3 | 0 | 0 | 0 | 3 |
| Navigation | 2 | 2 | 0 | 0 | 0 | 2 |
| Authentication | 2 | 1 | 1 | 0 | 0 | 2 |
| Infrastructure | 0 | 0 | 0 | 0 | 0 | 0 |
| UI/UX | 1 | 0 | 0 | 1 | 0 | 1 |
| **TOTAL** | **9** | **6** | **2** | **1** | **0** | **8** |

---

## Priority Definitions

- **🔴 CRITICAL** - Blocks release, data loss, security issue, complete feature breakdown
- **🟠 HIGH** - Major functionality impaired, affects core workflows, workaround difficult
- **🟡 MEDIUM** - Functionality impaired but workaround exists, affects secondary features
- **🟢 LOW** - Minor cosmetic issues, edge cases, non-blocking UX improvements

---

## Frontend Bugs

### FE-001: Multiple Scene/Collection Creation on Click
- **Status:** 🟡 In Progress
- **Priority:** 🟠 High
- **Affected Component:** WorkspaceSidebar, CreateSceneButton, CreateCollectionButton
- **Description:**
  - Clicking "Create" button multiple times creates duplicate scenes/collections because there's no loading state or debouncing to prevent multiple submissions
- **Steps to Reproduce:**
  1. Open a shared workspace
  2. Click "Create Scene" or "Create Collection" button
  3. Click again before the first creation completes (UI doesn't show loading state)
  4. Multiple duplicate items are created
- **Expected Behavior:**
  - Button should show loading state after first click
  - Subsequent clicks should be ignored until creation completes
  - Only one item should be created
- **Actual Behavior:**
  - Each click triggers a new API call
  - Multiple duplicate items are created (observed 8 duplicate collections in backend logs)
- **Environment:**
  - Browser: All
  - OS: All
  - Deployment: Local dev
- **Evidence from Debug Logs:**
  - Backend logs show 8 identical `CollectionsService.Created collection Shared1` entries at `10:18:46 PM`
- **Hypotheses Under Investigation:**
  - **Hypothesis A:** No debounce/throttle on create button click handler
  - **Hypothesis B:** No `isCreating` loading state to disable button during API call
  - **Hypothesis C:** React state updates causing multiple re-renders that trigger multiple calls
- **Assigned To:** AI Agent
- **Fixed In:** [Pending]

---

## Backend Bugs

### BE-001: [Bug Title]
- **Status:** 🔴 Open
- **Priority:** 🔴 Critical / 🟠 High / 🟡 Medium / 🟢 Low
- **Affected Endpoint/Service:** [API endpoint or service name]
- **Description:**
  - [Clear description of the bug]
- **Steps to Reproduce:**
  1. [Step 1]
  2. [Step 2]
  3. [Step 3]
- **Expected Behavior:**
  - [What should happen]
- **Actual Behavior:**
  - [What actually happens]
- **API Details:**
  - Endpoint: `[POST /api/v1/example]`
  - Request: `[Sample request body]`
  - Response: `[Actual response]`
  - Error Logs: `[Server logs if applicable]`
- **Additional Context:**
  - [Database state, related services, timing issues]
- **Assigned To:** [AI Agent / Manual]
- **Fixed In:** [Commit hash / PR number]

---

## Collaboration Bugs

*(No open bugs - see Fixed Bugs Archive)*

---

## Authentication Bugs

### AUTH-001: [Bug Title]
- **Status:** 🔴 Open
- **Priority:** 🔴 Critical / 🟠 High / 🟡 Medium / 🟢 Low
- **Affected Feature:** [Login/Logout/OIDC/JWT/Permissions/etc.]
- **Description:**
  - [Clear description of the bug]
- **Steps to Reproduce:**
  1. [Step 1]
  2. [Step 2]
  3. [Step 3]
- **Expected Behavior:**
  - [What should happen]
- **Actual Behavior:**
  - [What actually happens]
- **Auth Context:**
  - Auth method: [Local/OIDC/Both]
  - User role: [ADMIN/MEMBER/VIEWER]
  - Session state: [Fresh login/existing session/expired]
- **Additional Context:**
  - [JWT token info, cookies, OIDC logs]
- **Assigned To:** [AI Agent / Manual]
- **Fixed In:** [Commit hash / PR number]

---

## Infrastructure Bugs

### INFRA-001: [Bug Title]
- **Status:** 🔴 Open
- **Priority:** 🔴 Critical / 🟠 High / 🟡 Medium / 🟢 Low
- **Affected Service:** [Docker/Traefik/Database/Storage/etc.]
- **Description:**
  - [Clear description of the bug]
- **Steps to Reproduce:**
  1. [Step 1]
  2. [Step 2]
  3. [Step 3]
- **Expected Behavior:**
  - [What should happen]
- **Actual Behavior:**
  - [What actually happens]
- **Infrastructure Context:**
  - Service: [PostgreSQL/MinIO/Traefik/etc.]
  - Docker compose: [dev/prod]
  - Environment: [Local/Production]
- **Additional Context:**
  - [Container logs, network issues, volume problems]
- **Assigned To:** [AI Agent / Manual]
- **Fixed In:** [Commit hash / PR number]

---

## UI/UX Bugs

### UI-001: [Bug Title]
- **Status:** 🔴 Open
- **Priority:** 🔴 Critical / 🟠 High / 🟡 Medium / 🟢 Low
- **Affected Component:** [Component/Page Name]
- **Description:**
  - [Clear description of the bug]
- **Steps to Reproduce:**
  1. [Step 1]
  2. [Step 2]
  3. [Step 3]
- **Expected Behavior:**
  - [What should happen]
- **Actual Behavior:**
  - [What actually happens]
- **Visual Context:**
  - Theme: [Light/Dark/Both]
  - Screen size: [Desktop/Tablet/Mobile]
  - Element: [Button/Modal/Input/etc.]
- **Additional Context:**
  - [Screenshots, CSS issues, layout problems]
- **Assigned To:** [AI Agent / Manual]
- **Fixed In:** [Commit hash / PR number]

---

## Fixed Bugs Archive

### ✅ COLLAB-001: Scene Data Lost When Switching Scenes in Shared Workspace
- **Fixed Date:** 2025-12-24
- **Fixed In:** Multiple commits (8 fixes total)
- **Original Priority:** 🔴 Critical
- **Original Description:**
  - When working in a shared workspace with collaboration enabled, drawing on a scene and then switching to another scene resulted in data loss. Upon returning to the original scene, only the Excalidraw welcome screen was shown instead of the saved drawing.

#### Root Causes Identified

This bug had **8 interconnected root causes** that required systematic debugging with runtime instrumentation:

| # | Root Cause | Why It Happened | Impact |
|---|------------|-----------------|--------|
| 1 | Elements not captured before `stopCollaboration` | `excalidrawAPI.getSceneElementsIncludingDeleted()` was called inside `stopCollaboration` after scene might have been cleared | Empty array saved instead of actual elements |
| 2 | `saveCollabRoomToStorage` not awaited | `stopCollaboration` called `saveCollabRoomToStorage` without `await`, then immediately destroyed socket | Save interrupted, portal cleared before save completed |
| 3 | Data loaded from wrong source | `useSceneLoader` loaded data from backend API (`scene.data`) instead of room storage for collaboration scenes | Stale data from database shown instead of latest from room storage |
| 4 | Stale `currentWorkspaceSlugAtom` | Components used `currentWorkspaceSlugAtom` which wasn't synced with `currentWorkspaceAtom` | API calls to wrong workspace endpoint, 403 errors |
| 5 | Empty canvas saved for `isAutoCollab` | `startCollaboration` saved current canvas elements for `isAutoCollab` scenes, but canvas was empty at that moment | Overwrote room storage with empty array |
| 6 | Save before data loaded | `roomDataLoaded` flag didn't exist, so `stopCollaboration` saved even when data hadn't loaded from room storage yet | Empty canvas saved, overwriting real data |
| 7 | Loaded data not applied to canvas | `startCollaboration` returned elements but `useSceneLoader` didn't call `updateScene()` to apply them | Canvas remained empty despite data being loaded |
| 8 | UI blocked during scene switch | `await stopCollaboration()` blocked UI for 5+ seconds | Poor UX, users thought app was frozen |

#### Detailed Fix Descriptions

**Fix 1: Capture elements before stopCollaboration**
```typescript
// useSceneLoader.ts - BEFORE
if (collabAPI?.isCollaborating()) {
  await collabAPI.stopCollaboration(false);
}

// useSceneLoader.ts - AFTER  
if (collabAPI?.isCollaborating()) {
  const elementsToSave = excalidrawAPI.getSceneElementsIncludingDeleted();
  collabAPI.stopCollaboration(false, elementsToSave);
}
```
**Why:** Elements must be captured synchronously BEFORE any async operations or scene updates. Inside `stopCollaboration`, the scene might already be cleared.

**Fix 2: Await saveCollabRoomToStorage before destroying socket**
```typescript
// Collab.tsx - BEFORE
this.saveCollabRoomToStorage(elements);
this.destroySocketClient(); // Called immediately!

// Collab.tsx - AFTER
await this.saveCollabRoomToStorage(elements);
this.destroySocketClient(); // Now waits for save
```
**Why:** `saveCollabRoomToStorage` is async. Without await, `destroySocketClient()` clears `portal.socket` and `portal.roomId` before the save completes.

**Fix 3: Load collaboration scenes from room storage**
```typescript
// useSceneLoader.ts - BEFORE
if (loaded.data) {
  // Always loaded from backend API
  const sceneData = await loadFromBlob(decodeBase64ToBlob(loaded.data));
  excalidrawAPI.updateScene({ elements: sceneData.elements });
}
// Then started collaboration...

// useSceneLoader.ts - AFTER
if (isCollabScene) {
  // For collab scenes, SKIP backend data - load from room storage
  const sceneData = await collabAPI.startCollaboration({...});
  if (sceneData?.elements) {
    excalidrawAPI.updateScene({ elements: sceneData.elements });
  }
} else {
  // Non-collab: load from backend API
}
```
**Why:** Room storage (`/api/v2/rooms/{roomId}`) is the source of truth for collaboration scenes. Backend API (`scene.data`) may have stale data.

**Fix 4: Use workspace.slug directly instead of atom**
```typescript
// CollectionView.tsx, WorkspaceSidebar.tsx - BEFORE
const workspaceSlug = useAtomValue(currentWorkspaceSlugAtom);

// AFTER
const workspace = useAtomValue(currentWorkspaceAtom);
const workspaceSlug = workspace?.slug;
```
**Why:** `currentWorkspaceSlugAtom` wasn't always synced when workspace changed. Using `workspace?.slug` directly ensures consistency.

**Fix 5: Don't save empty canvas for isAutoCollab**
```typescript
// Collab.tsx startCollaboration - BEFORE
} else {
  // For new rooms OR auto-collab
  const elements = this.excalidrawAPI.getSceneElements();
  this.saveCollabRoomToStorage(elements); // Saved empty array!
}

// AFTER
} else if (!isAutoCollab) {
  // Only for NEW rooms, not auto-collab
  const elements = this.excalidrawAPI.getSceneElements();
  this.saveCollabRoomToStorage(elements);
}
// Auto-collab: data will be loaded from room storage, don't save
```
**Why:** For `isAutoCollab` scenes, canvas is empty when `startCollaboration` is called. Saving would overwrite the actual data in room storage.

**Fix 6: Add roomDataLoaded flag**
```typescript
// Collab.tsx - NEW
private roomDataLoaded: boolean = false;

// In initializeRoom:
this.roomDataLoaded = true;

// In stopCollaboration:
if (this.roomDataLoaded) {
  await this.saveCollabRoomToStorage(elements);
} else {
  // Skip save - data wasn't loaded yet
}
this.roomDataLoaded = false;
```
**Why:** Prevents saving empty canvas when user switches scenes before room data has loaded from storage.

**Fix 7: Apply loaded scene data to canvas**
```typescript
// useSceneLoader.ts - BEFORE
const sceneData = await collabAPI.startCollaboration({...});
// sceneData returned but NOT applied to canvas!

// AFTER
const sceneData = await collabAPI.startCollaboration({...});
if (sceneData?.elements) {
  excalidrawAPI.updateScene({
    elements: sceneData.elements,
    captureUpdate: CaptureUpdateAction.IMMEDIATELY,
  });
}
```
**Why:** `startCollaboration` loads elements from room storage and returns them, but they need to be explicitly applied to the canvas.

**Fix 8: Non-blocking stopCollaboration**
```typescript
// useSceneLoader.ts - BEFORE
await collabAPI.stopCollaboration(false, elementsToSave);
// Blocked UI for 5+ seconds!

// AFTER
collabAPI.stopCollaboration(false, elementsToSave).catch(console.error);
// Fire and forget - elements already captured synchronously
```
**Why:** Elements are captured synchronously before the call. The actual save can happen in the background while the new scene loads.

#### Key Architectural Lessons

1. **Room storage is source of truth for collaboration scenes** - Never load from `scene.data` when `canCollaborate` is true
2. **Capture state synchronously before async operations** - Don't rely on state being available inside async callbacks
3. **Await async operations that have side effects** - Or ensure side effects complete before cleanup
4. **Use derived state from single source** - Don't maintain separate atoms that can become desynchronized
5. **Don't save during initialization** - Only save when data has been loaded and user has made changes
6. **Apply loaded data explicitly** - Returning data from a function doesn't automatically update UI

#### Files Modified

| File | Changes |
|------|---------|
| `frontend/excalidraw-app/hooks/useSceneLoader.ts` | Capture elements before stop, load from room storage, apply to canvas, non-blocking save |
| `frontend/excalidraw-app/collab/Collab.tsx` | Accept elements parameter, await save, roomDataLoaded flag, skip save for isAutoCollab |
| `frontend/excalidraw-app/components/Workspace/CollectionView/CollectionView.tsx` | Use workspace.slug directly |
| `frontend/excalidraw-app/components/Workspace/WorkspaceSidebar/WorkspaceSidebar.tsx` | Use workspace.slug directly |

#### Testing Verification

After all fixes, debug logs showed:
- Scene switching: **~40-90ms** (was 5+ seconds)
- Elements saved correctly: `elementsCount: 7` (was 0)
- Data loaded from room storage: `initializeRoom:loaded` with correct element count
- No more 403 errors from wrong workspace slug

---

### ✅ NAV-001: Page Refresh Shows Welcome Screen Instead of Scene Content
- **Fixed Date:** 2025-12-24
- **Fixed In:** App.tsx `loadSceneFromWorkspaceUrl` refactored
- **Original Priority:** 🔴 Critical
- **Original Description:**
  - When refreshing a page with a scene URL (e.g., `/workspace/test-new/scene/abc123`), the correct workspace was loaded but the scene showed the Excalidraw welcome screen instead of the actual drawing content. Manually switching scenes in the sidebar would then display the content correctly.

#### Root Cause

The `loadSceneFromWorkspaceUrl` function in `App.tsx` (used for initial page load) had **different logic** from `loadScene` in `useSceneLoader.ts` (used for scene switching).

| Function | Where Used | Data Source for Collab Scenes |
|----------|------------|-------------------------------|
| `loadSceneFromWorkspaceUrl` | Initial page load, refresh | Backend API (`scene.data`) ❌ |
| `loadScene` (useSceneLoader) | Scene switching | Room storage ✅ |

For collaboration scenes, `loadSceneFromWorkspaceUrl` was:
1. Loading scene data from backend API (`scene.data`)
2. Applying it to canvas
3. **Then** starting collaboration

This meant the older backend data was applied first, and then `startCollaboration` was called but its returned data wasn't applied to the canvas (same issue as COLLAB-001 Fix #7).

#### Fix

Unified the logic in `loadSceneFromWorkspaceUrl` to match `useSceneLoader`:

```typescript
// App.tsx loadSceneFromWorkspaceUrl - BEFORE
const loaded = await loadWorkspaceScene(workspaceSlug, sceneId);

// Load from backend API (wrong for collab!)
if (loaded.data) {
  const blob = decodeBase64ToBlob(loaded.data);
  const sceneData = await loadFromBlob(blob, null, null);
  excalidrawAPI.updateScene({ elements: sceneData.elements });
}

// Then start collaboration (but don't use its data!)
if (loaded.roomId && loaded.roomKey) {
  await collabAPI.startCollaboration({ roomId, roomKey });
}

// App.tsx loadSceneFromWorkspaceUrl - AFTER
const loaded = await loadWorkspaceScene(workspaceSlug, sceneId);

const isCollabScene = loaded.access.canCollaborate && loaded.roomId && loaded.roomKey;

if (isCollabScene) {
  // Load from room storage (correct!)
  const sceneData = await collabAPI.startCollaboration({
    roomId: loaded.roomId,
    roomKey,
    isAutoCollab: true,
  });
  
  // Apply loaded data to canvas
  if (sceneData?.elements) {
    excalidrawAPI.updateScene({
      elements: sceneData.elements,
      captureUpdate: CaptureUpdateAction.IMMEDIATELY,
    });
  }
} else {
  // Non-collab: load from backend API
  if (loaded.data) {
    const blob = decodeBase64ToBlob(loaded.data);
    const sceneData = await loadFromBlob(blob, null, null);
    excalidrawAPI.updateScene({ elements: sceneData.elements });
  }
}
```

#### Key Lesson

**Maintain consistency between initial load and navigation paths.** When fixing bugs in one code path (scene switching), ensure the same logic is applied to all paths that perform the same operation (initial page load).

#### Files Modified

| File | Changes |
|------|---------|
| `frontend/excalidraw-app/App.tsx` | Refactored `loadSceneFromWorkspaceUrl` to load collab scenes from room storage |

#### Testing Verification

After fix, debug logs showed:
- `loadSceneFromWorkspaceUrl:collab` - Starting collaboration for scene
- `loadSceneFromWorkspaceUrl:collabLoaded` - `elementsCount: 4` (was 0)
- Scene content displays correctly on page refresh

---

### ✅ COLLAB-003: Data Contamination When Switching Between Collab Scenes
- **Fixed Date:** 2025-12-25
- **Fixed In:** `36039fe` - fix: collaboration race conditions and workspace navigation
- **Original Priority:** 🔴 Critical
- **Original Description:**
  - When quickly switching between scenes in a shared collection, drawings from Scene A would appear on Scene B. This was data contamination where the previous scene's content was being saved to the new scene's room storage.

#### Root Causes Identified

| # | Root Cause | Why It Happened | Impact |
|---|------------|-----------------|--------|
| 1 | Throttled save fired after room switch | `queueSaveToStorage` was throttled to 20 seconds, could fire after switching to new room | Old data saved to new room |
| 2 | `syncElements` called during transitions | `onChange` callback triggered `syncElements` while portal was in inconsistent state | Elements broadcast to wrong room |
| 3 | Canvas not cleared for auto-collab | `startCollaboration` only called `resetScene()` for non-auto-collab scenes | Old elements reconciled into new scene |

#### Fixes Applied

**Fix 1: Cancel pending saves when switching rooms**
```typescript
// Collab.tsx startCollaboration - BEFORE
if (this.portal.socket) {
  this.queueSaveToStorage.flush(); // Flushed old data to wrong room!
  this.destroySocketClient();
}

// AFTER
if (this.portal.socket) {
  this.queueBroadcastAllElements.cancel(); // Cancel, don't flush!
  this.queueSaveToStorage.cancel();
  this.destroySocketClient();
}
```

**Fix 2: Guard syncElements with portal.isOpen()**
```typescript
// Collab.tsx - BEFORE
syncElements = (elements: readonly OrderedExcalidrawElement[]) => {
  this.broadcastElements(elements);
  this.queueSaveToStorage();
};

// AFTER
syncElements = (elements: readonly OrderedExcalidrawElement[]) => {
  if (!this.portal.isOpen()) {
    return; // Don't sync during room transitions
  }
  this.broadcastElements(elements);
  this.queueSaveToStorage();
};
```

**Fix 3: Clear canvas for all existing room joins**
```typescript
// Collab.tsx startCollaboration - BEFORE
if (existingRoomLinkData && !isAutoCollab) {
  this.excalidrawAPI.resetScene(); // Only for non-auto-collab
}

// AFTER
if (existingRoomLinkData) {
  this.excalidrawAPI.resetScene(); // For ALL existing room joins
}
```

#### Key Lesson

**Cancel, don't flush, pending operations when switching contexts.** Flushing a throttled save after the room has changed saves data to the wrong destination.

---

### ✅ COLLAB-004: Stale Scene Content Visible During Scene Loading
- **Fixed Date:** 2025-12-25
- **Fixed In:** `36039fe` - fix: collaboration race conditions and workspace navigation
- **Original Priority:** 🔴 Critical
- **Original Description:**
  - When switching scenes, the previous scene's content remained visible for 2-3 seconds while the new scene loaded. Users could accidentally start drawing on the empty canvas, thinking it was the new scene.

#### Root Cause

The canvas wasn't cleared when starting to load a new scene. Users saw:
1. Old scene content (2-3 seconds)
2. New scene loads
3. Content suddenly changes

This was confusing and allowed users to draw on an empty canvas during the loading period.

#### Fix Applied

**Use Excalidraw's built-in isLoading state**
```typescript
// useSceneLoader.ts - BEFORE
if (!isInitialLoad) {
  excalidrawAPI.resetScene(); // Shows welcome screen, drawing enabled!
}

// AFTER
if (!isInitialLoad) {
  excalidrawAPI.updateScene({
    elements: [], // Clear elements
    appState: { isLoading: true }, // Disable drawing, show loading
  });
}

// After scene loads
excalidrawAPI.updateScene({
  elements: sceneData.elements,
  appState: { isLoading: false }, // Re-enable drawing
});
```

#### Key Lesson

**Use framework's built-in loading states.** Excalidraw's `isLoading: true` disables all drawing tools and shows a loading indicator - much better than showing an empty canvas.

---

### ✅ NAV-002: Workspace Switching Doesn't Update URL or Clear State
- **Fixed Date:** 2025-12-25
- **Fixed In:** `36039fe` - fix: collaboration race conditions and workspace navigation
- **Original Priority:** 🔴 Critical
- **Original Description:**
  - When switching from a collaborative scene to a different workspace (e.g., private workspace), the URL didn't change, the old scene remained visible, and the sidebar showed an incorrect "Untitled" collection.

#### Root Cause

The `switchWorkspace` function in `useWorkspaces.ts` only updated `currentWorkspaceAtom` but didn't:
1. Clear `currentSceneIdAtom`
2. Clear `activeCollectionIdAtom`
3. Navigate to the new workspace's dashboard

#### Fix Applied

**Create handleSwitchWorkspace wrapper in WorkspaceSidebar**
```typescript
// WorkspaceSidebar.tsx - NEW
const handleSwitchWorkspace = useCallback(
  (workspace: Workspace) => {
    // Clear current scene state
    setCurrentSceneId(null);
    setCurrentSceneTitle("Untitled");
    setIsAutoCollabScene(false);
    
    // Clear active collection (will be set to private by useCollections)
    setActiveCollectionId(null);
    
    // Update workspace slug
    setCurrentWorkspaceSlug(workspace.slug);
    
    // Switch workspace
    switchWorkspace(workspace);
    
    // Navigate to dashboard
    navigateToDashboard();
  },
  [/* deps */],
);
```

#### Key Lesson

**Clear related state when switching contexts.** Workspace switch must clear scene and collection state, not just update the workspace reference.

---

### ✅ AUTH-001: Private Content Visible After Logout
- **Fixed Date:** 2025-12-25
- **Fixed In:** `36039fe` - fix: collaboration race conditions and workspace navigation
- **Original Priority:** 🟠 High
- **Original Description:**
  - When a user logged out while viewing a private scene, the scene content remained visible on the anonymous Excalidraw screen. This was a privacy/security concern.

#### Root Cause

The `logout` function in `AuthContext.tsx` only called `logoutApi()` and cleared the user state. It didn't:
1. Clear the canvas
2. Stop active collaboration
3. Reset the URL

#### Fix Applied

**Add logoutSignalAtom and subscribe in App.tsx**
```typescript
// settingsState.ts - NEW
export const logoutSignalAtom = atom(0);

export const clearWorkspaceDataAtom = atom(null, (get, set) => {
  set(workspacesAtom, []);
  set(currentWorkspaceAtom, null);
  set(collectionsAtom, []);
  set(activeCollectionIdAtom, null);
  set(currentWorkspaceSlugAtom, null);
  set(currentSceneIdAtom, null);
  set(currentSceneTitleAtom, "Untitled");
  set(isAutoCollabSceneAtom, false);
  set(logoutSignalAtom, (prev) => prev + 1); // Signal logout
});

// AuthContext.tsx
const logout = useCallback(() => {
  logoutApi();
  setUser(null);
  appJotaiStore.set(clearWorkspaceDataAtom); // Clear all state
}, []);

// App.tsx - Subscribe to logout signal
useEffect(() => {
  if (logoutSignal > 0 && logoutSignal !== logoutSignalRef.current) {
    logoutSignalRef.current = logoutSignal;
    excalidrawAPI?.resetScene();
    window.history.pushState({}, "", "/");
    collabAPI?.isCollaborating() && collabAPI.stopCollaboration(false);
  }
}, [logoutSignal, excalidrawAPI, collabAPI]);
```

#### Key Lesson

**Clear sensitive state on logout.** Use a signal atom pattern when the logout handler doesn't have access to all required APIs (like `excalidrawAPI`).

---

### ✅ UI-001: Team-Related UI Visible in Personal Workspaces
- **Fixed Date:** 2025-12-25
- **Fixed In:** `36039fe` - fix: collaboration race conditions and workspace navigation
- **Original Priority:** 🟡 Medium
- **Original Description:**
  - Personal workspaces showed "Team Members" and "Teams & Collections" menu items in the sidebar, and a "Team Members" section on the dashboard. This was confusing since personal workspaces don't support collaboration.

#### Fix Applied

**Hide team UI for PERSONAL workspaces**
```typescript
// FullModeNav.tsx
{!isPersonalWorkspace && (
  <>
    <button onClick={onMembersClick}>Team Members</button>
    <button onClick={onTeamsCollectionsClick}>Teams & Collections</button>
  </>
)}

// DashboardView.tsx
{workspace?.type !== "PERSONAL" && (
  <section>
    <h2>Team Members</h2>
    {/* ... */}
  </section>
)}
```

#### Key Lesson

**Adapt UI to context.** Personal workspaces have different capabilities than shared workspaces - the UI should reflect this.

---

### ✅ AUTH-002: Scene Data Lost After Logout Due to Autosave Race Condition
- **Fixed Date:** 2025-12-25
- **Fixed In:** `isLoggingOutAtom` flag to prevent autosave during logout
- **Original Priority:** 🔴 Critical
- **Original Description:**
  - When a user logged out while viewing a private scene, the logout effect cleared the canvas for privacy (AUTH-001 fix). However, the autosave mechanism would then save the empty canvas to the backend, corrupting the scene data. When the user logged back in and opened the same scene, it was empty.

#### Root Cause

Race condition between logout canvas clearing and autosave:

| Step | What Happened | Problem |
|------|---------------|---------|
| 1 | `clearWorkspaceDataAtom` sets `currentSceneIdAtom = null` | Jotai atom updated |
| 2 | `logoutSignal` fires, App.tsx clears canvas | `updateScene({ elements: [] })` |
| 3 | `onChange` handler fires with empty elements | Normal Excalidraw behavior |
| 4 | `useAutoSave` still has old `currentSceneId` | Hook state not synced with atom |
| 5 | `markUnsaved()` called, triggers autosave | Empty canvas saved to backend! |

The issue was that `useAutoSave` received `currentSceneId` from `useSceneLoader`'s internal state, NOT from the Jotai atom. When `clearWorkspaceDataAtom` set `currentSceneIdAtom` to `null`, the hook's internal state wasn't updated.

#### Fix Applied

**Add `isLoggingOutAtom` flag with defense in depth:**

```typescript
// settingsState.ts - NEW
export const isLoggingOutAtom = atom(false);

export const clearWorkspaceDataAtom = atom(null, (get, set) => {
  // Set logout flag FIRST to prevent autosave
  set(isLoggingOutAtom, true);
  // ... rest of clearing logic
  set(logoutSignalAtom, (prev) => prev + 1);
});

// App.tsx - Clear flag after canvas is cleared
useEffect(() => {
  if (logoutSignal > 0 && logoutSignal !== logoutSignalRef.current) {
    // ... clear canvas ...
    
    // Clear logout flag after canvas is cleared
    setTimeout(() => {
      appJotaiStore.set(isLoggingOutAtom, false);
    }, 0);
  }
}, [logoutSignal, excalidrawAPI, collabAPI]);

// App.tsx - Guard onChange handler
const isLoggingOut = appJotaiStore.get(isLoggingOutAtom);
if (currentSceneId && !collabAPI?.isCollaborating() && !isLoggingOut) {
  markUnsaved(currentData);
}

// useAutoSave.ts - Defense in depth
const performSave = useCallback(async (): Promise<boolean> => {
  if (!currentSceneId || !excalidrawAPI || isLoggingOut) {
    return false;
  }
  // ...
}, [currentSceneId, excalidrawAPI, isLoggingOut]);
```

**Also fixed:** "Leave site?" warning appearing during logout or in dashboard mode:
```typescript
// App.tsx beforeunload handler
const unloadHandler = (event: BeforeUnloadEvent) => {
  const currentIsLoggingOut = appJotaiStore.get(isLoggingOutAtom);
  if (currentIsLoggingOut || appMode === "dashboard") {
    return; // Don't show warning
  }
  // ... rest of handler
};
```

#### Key Lessons

1. **Use explicit flags for multi-step operations** - When an operation spans multiple effects/hooks, use a flag to coordinate them
2. **Defense in depth** - Guard at multiple levels (onChange + useAutoSave) to prevent race conditions
3. **Check operation context in event handlers** - `beforeunload` should consider app state (logout, dashboard mode)

#### Files Modified

| File | Changes |
|------|---------|
| `frontend/excalidraw-app/components/Settings/settingsState.ts` | Added `isLoggingOutAtom`, set flag in `clearWorkspaceDataAtom` |
| `frontend/excalidraw-app/components/Settings/index.ts` | Export `isLoggingOutAtom` |
| `frontend/excalidraw-app/App.tsx` | Check flag in onChange, clear flag after logout, guard beforeunload |
| `frontend/excalidraw-app/hooks/useAutoSave.ts` | Added `isLoggingOut` option to skip saves during logout |

---

## Notes for AI Agent

When fixing bugs from this document:

1. **Read the entire document first** to understand all bugs and potential interactions
2. **Prioritize by severity**: Critical → High → Medium → Low
3. **Group related bugs** that can be fixed together
4. **Update the summary table** as you fix bugs
5. **Move fixed bugs** to the "Fixed Bugs Archive" section
6. **Update status** from 🔴 Open → 🟡 In Progress → ✅ Fixed
7. **Test fixes thoroughly** before marking as complete
8. **Check for regressions** after each fix
9. **Update documentation** if the fix changes behavior
10. **Run `just check` and `just check-backend`** after all fixes

### Testing Checklist for Fixes

- [ ] Bug no longer reproduces with original steps
- [ ] No new console errors introduced
- [ ] No TypeScript errors (`just check-frontend` / `just check-backend`)
- [ ] No linter warnings
- [ ] Related features still work correctly
- [ ] Dark mode tested (if UI change)
- [ ] Mobile responsiveness checked (if UI change)
- [ ] Collaboration features tested (if collab change)
- [ ] Different user roles tested (if auth/permissions change)

---

## Release Criteria

Before marking MVP as release-ready:

- [x] All 🔴 CRITICAL bugs fixed (COLLAB-001 fixed)
- [ ] All 🟠 HIGH bugs fixed or documented as known issues
- [ ] 🟡 MEDIUM bugs evaluated (fix or defer to v1.1)
- [ ] 🟢 LOW bugs evaluated (defer to future releases)
- [ ] All fixes tested in production-like environment
- [ ] Smoke test of core workflows completed
- [ ] Documentation updated for any behavioral changes
