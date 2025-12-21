# CRITICAL FIX: CSS Hide/Show Pattern for Excalidraw State Preservation

> ⚠️ **IMPORTANT**: This document describes a critical architectural decision that solved a major data loss bug. Do NOT modify the CSS Hide/Show pattern without understanding this document first.

**Date Fixed:** December 22, 2025  
**Bug Duration:** ~24 hours of debugging  
**Severity:** Critical - Data Loss

---

## The Problem

When users navigated from the dashboard to a scene (or between scenes), the Excalidraw canvas would display the "Meet Excalidraw" welcome screen instead of the saved scene data. If auto-save was enabled, this would overwrite the scene with empty data, causing **permanent data loss**.

### Symptoms

1. User creates a scene with drawings
2. User saves the scene
3. User navigates to dashboard
4. User clicks on the scene to open it
5. **Bug:** Canvas shows welcome screen (0 elements) instead of saved drawings
6. If auto-save triggers → **DATA LOSS**

---

## Root Cause

The original code used **React conditional rendering** to switch between dashboard and canvas modes:

```tsx
// ❌ THE BUGGY PATTERN - DO NOT USE
if (appMode === "dashboard") {
  return <WorkspaceMainContent />;  // Dashboard rendered, Excalidraw DESTROYED
}
return <Excalidraw />;  // Canvas rendered
```

### Why This Caused Data Loss

When `appMode` changes, React completely **unmounts** one component tree and **mounts** a different one:

```
Dashboard Mode                         Canvas Mode
┌─────────────────────┐               ┌─────────────────────┐
│  WorkspaceMainContent│               │     Excalidraw      │
│     (mounted)        │  ──────────►  │    (NEW MOUNT)      │
│                      │   appMode     │   STATE IS LOST!    │
│  Excalidraw is NOT   │   changes     │                     │
│  in the DOM at all   │               │                     │
└─────────────────────┘               └─────────────────────┘
```

The race condition that caused data loss:

1. `loadSceneFromUrl()` is called
2. Scene data is fetched from API (e.g., 3 elements)
3. `excalidrawAPI.updateScene()` is called → canvas has 3 elements ✅
4. `navigateToCanvas()` is called → changes `appMode` to "canvas"
5. React re-renders → **Excalidraw UNMOUNTS and REMOUNTS**
6. On remount, Excalidraw uses `initialStatePromiseRef` (not updated)
7. Canvas shows welcome screen (0 elements) ❌
8. Auto-save triggers → saves 0 elements → **DATA LOSS**

### Debug Evidence

```json
// updateScene successfully loads 3 elements
{"message":"UPDATE existing mounted Excalidraw via updateScene","data":{"elementsCount":3}}

// Canvas has 3 elements after updateScene ✅
{"message":"AFTER updateScene - checking what canvas has now","data":{"canvasElementsCount":3}}

// BUT THEN Excalidraw REMOUNTS! ❌
{"message":"Excalidraw MOUNTED","data":{"hasAPI":true}}

// After remount, canvas has 0 elements! ❌
{"message":"onChange fired","data":{"elementsCount":0}}
```

---

## The Solution: CSS Hide/Show Pattern

Instead of conditional rendering, we **always mount both components** and use CSS `display: none` to hide the inactive one:

```tsx
// ✅ THE CORRECT PATTERN - CSS HIDE/SHOW
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

### Why This Works

| Aspect | Before (Buggy) | After (Fixed) |
|--------|----------------|---------------|
| Excalidraw lifecycle | Unmounts/remounts on mode switch | Always mounted |
| State preservation | Lost on unmount | Preserved |
| Scene data | Reset to empty | Maintained |
| `updateScene()` | Lost after remount | Always works |

### New Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      App.tsx                                 │
│                                                              │
│  ┌─────────────────────┐    ┌─────────────────────┐         │
│  │  Dashboard Content  │    │     Excalidraw      │         │
│  │  (always mounted)   │    │  (always mounted)   │         │
│  │                     │    │                     │         │
│  │  display: block     │    │  display: none      │  ◄── Dashboard mode
│  │  display: none      │    │  display: block     │  ◄── Canvas mode
│  └─────────────────────┘    └─────────────────────┘         │
│                                                              │
│  Both components stay in DOM - only visibility changes       │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Details

### Files Changed

| File | Changes |
|------|---------|
| `excalidraw-app/App.tsx` | Removed early return for dashboard, added CSS Hide/Show structure |
| `excalidraw-app/index.scss` | Added canvas container styles and pointer-events blocking |

### Key Code Sections in App.tsx

1. **Body class effect** (~line 550-565): Toggles `body.excalidraw-disabled` class when in dashboard mode
2. **Main return statement** (~line 1650+): CSS Hide/Show structure with both dashboard and canvas
3. **Excalidraw props** (~line 1745): Conditional `handleKeyboardGlobally` and `autoFocus`

### Safeguards Implemented

| Safeguard | Purpose |
|-----------|---------|
| `display: none` | Hides component visually |
| `aria-hidden="true"` | Hides from screen readers |
| `inert` attribute | Prevents ALL user interaction when hidden (focus, click, keyboard) |
| `pointer-events: none` | CSS fallback for older browsers |
| `handleKeyboardGlobally={appMode === "canvas"}` | Disables Excalidraw keyboard shortcuts when hidden |
| `autoFocus={appMode === "canvas"}` | Prevents canvas from stealing focus when hidden |
| `body.excalidraw-disabled` class | Additional CSS hook for keyboard blocking |

---

## Rules for Future Development

### DO NOT

❌ **DO NOT** change the CSS Hide/Show pattern back to conditional rendering  
❌ **DO NOT** add a `key` prop to Excalidraw that changes on mode switch (causes remount)  
❌ **DO NOT** unmount Excalidraw when switching to dashboard  
❌ **DO NOT** remove the `inert` attribute (needed for accessibility and input blocking)  

### DO

✅ **DO** keep both Dashboard and Canvas always mounted  
✅ **DO** use CSS `display: none` for visibility toggling  
✅ **DO** use `excalidrawAPI.updateScene()` to load scene data (not `initialStatePromiseRef`)  
✅ **DO** test scene navigation after any changes to App.tsx  
✅ **DO** read this document before modifying the mode switching logic  

---

## Testing Checklist

If you modify anything related to mode switching, test these scenarios:

| # | Test | Expected Result |
|---|------|-----------------|
| 1 | Create scene → Draw → Save → Dashboard → Click scene | Drawings visible |
| 2 | Open scene A → Draw → Save → Open scene B → Open scene A | Scene A drawings visible |
| 3 | Open scene → Draw → Save → Browser refresh | Drawings visible |
| 4 | Open scene → Draw → Save → Browser back → Browser forward | Drawings visible |
| 5 | Dashboard mode → Press "V" key | Nothing happens (no tool switch) |
| 6 | Dashboard mode → Type in search field | Text appears, no canvas shortcuts |
| 7 | Dashboard mode → Press Tab repeatedly | Focus stays in dashboard, not canvas |
| 8 | Rapidly switch between 3+ scenes | All scenes show correct data |

---

## Commit Reference

This fix was implemented in commit:

```
fix(critical): CSS Hide/Show pattern - CHECKPOINT for scene data preservation
```

**If you ever need to revert to a known working state** for the dashboard/canvas switching, find this commit in the git history.

---

## Lessons Learned

1. **State changes can cause component remounts** - Changing `appMode` caused React to re-render the component tree, which unmounted/remounted Excalidraw.

2. **CSS visibility is safer than conditional rendering** - For stateful components like Excalidraw, use CSS to hide rather than unmount.

3. **The `inert` attribute is powerful** - It prevents all user interaction (focus, click, keyboard) without JavaScript.

4. **Debug with runtime logs** - Static code analysis wasn't enough; runtime logs revealed the actual execution order and state changes.

5. **Auto-save needs guards** - Auto-save should not save empty canvas if the scene was previously non-empty.

---

## Related Documentation

- `/.cursor/rules/common-issues.mdc` - Issue #11 and #14 reference this fix
- `/.cursor/rules/frontend-patterns.mdc` - Scene Loading Architecture section
- `/docs/URL_ROUTING.md` - URL routing patterns

---

## Contact

If you're unsure about modifying this code, ask the team first. This fix took 24+ hours to debug and implement correctly.
