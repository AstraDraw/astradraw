# Excalidraw Fork Architecture

This document explains AstraDraw's relationship with the Excalidraw codebase and provides guidance on where to implement new features.

## Overview

AstraDraw is built on a **fully controlled fork** of Excalidraw. The key insight is:

> `frontend/packages/excalidraw/` is **local source code**, not an external npm dependency.

This means we can modify any file in the Excalidraw packages directly, rather than working around limitations.

## How It Works

### Package Structure

```
frontend/
├── excalidraw-app/           # AstraDraw-specific features
│   ├── components/           # Workspace, Comments, Talktrack, etc.
│   ├── auth/                 # Authentication, API client
│   └── hooks/                # App-level hooks
│
├── packages/                 # ← CONTROLLED FORK (we own this)
│   ├── excalidraw/           # Core React component & UI
│   ├── element/              # Element types, rendering
│   ├── common/               # Shared constants, utilities
│   ├── math/                 # Geometry utilities
│   └── utils/                # Export utilities
│
└── node_modules/
    └── @excalidraw/          # ← Symlinks to packages/* (Yarn Workspaces)
```

### Import Resolution

When you see imports like:

```typescript
import { Excalidraw } from "@excalidraw/excalidraw";
import { sceneCoordsToViewportCoords } from "@excalidraw/common";
```

These resolve to **local files**, not npm packages:

- `@excalidraw/excalidraw` → `packages/excalidraw/`
- `@excalidraw/common` → `packages/common/`
- `@excalidraw/element` → `packages/element/`

**Yarn Workspaces** creates symlinks in `node_modules/@excalidraw/*` pointing to `packages/*`.

**Vite aliases** resolve imports directly to source files during development.

---

## Decision Framework

When implementing a new feature, ask:

### Is this a core drawing/UI feature?

**YES → Modify `packages/excalidraw/` directly**

Examples:
- New element types
- Canvas rendering changes
- Toolbar modifications
- Keyboard shortcuts via action system
- State that affects drawing behavior

### Is this AstraDraw-specific integration?

**NO → Implement in `excalidraw-app/`**

Examples:
- Backend API integration
- Authentication
- Workspace management
- Features that require backend data

### Decision Tree

```
┌─────────────────────────────────────────────────────────┐
│              Where should I implement this?             │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
         ┌────────────────────────────────┐
         │ Does it modify core Excalidraw │
         │ behavior (canvas, tools, UI)?  │
         └────────────────────────────────┘
                    │           │
                   YES          NO
                    │           │
                    ▼           ▼
        ┌───────────────┐  ┌─────────────────────────┐
        │  Modify       │  │ Does it need backend    │
        │  packages/    │  │ data or authentication? │
        │  excalidraw/  │  └─────────────────────────┘
        └───────────────┘           │           │
                                   YES          NO
                                    │           │
                                    ▼           ▼
                        ┌───────────────┐  ┌───────────────┐
                        │  Implement in │  │  Consider if  │
                        │  excalidraw-  │  │  it should be │
                        │  app/         │  │  in packages/ │
                        └───────────────┘  └───────────────┘
```

---

## Case Studies

### Good Pattern: Sidebar Composition

**Feature:** Custom sidebar tabs (Comments, Stickers, Talktrack, Presentation)

**Implementation:** Uses Excalidraw's composition API correctly

```typescript
// excalidraw-app/components/AppSidebar/AppSidebar.tsx
import { DefaultSidebar, Sidebar } from "@excalidraw/excalidraw";

export const AppSidebar = () => (
  <DefaultSidebar>
    <DefaultSidebar.TabTriggers>
      <Sidebar.TabTrigger tab="comments">{messageCircleIcon}</Sidebar.TabTrigger>
      <Sidebar.TabTrigger tab="stickers">{stickerIcon}</Sidebar.TabTrigger>
      {/* ... */}
    </DefaultSidebar.TabTriggers>
    <Sidebar.Tab tab="comments">
      <CommentsSidebar />
    </Sidebar.Tab>
    {/* ... */}
  </DefaultSidebar>
);
```

**Why this is correct:**
- Uses Excalidraw's `DefaultSidebar.TabTriggers` tunnel API
- Custom content injected into existing infrastructure
- No modification to core needed - the extension point exists

---

### Good Pattern: Custom Pens

**Feature:** Predefined pen presets with custom colors/sizes

**Implementation:** Extends `AppState.customPens` (added to core types)

```typescript
// packages/excalidraw/types.ts - Added customPens to AppState
export interface AppState {
  // ... existing state
  customPens?: PenPreset[];
}

// excalidraw-app/pens/PenToolbar.tsx - Uses the state
const customPens = appState.customPens || [];
```

**Why this is correct:**
- Extended core types to support the feature
- UI implementation in app layer (AstraDraw-specific toolbar)
- State flows through normal Excalidraw channels

---

### Improvable Pattern: Comment Markers

**Feature:** Comment thread markers displayed on canvas

**Current implementation:** DOM overlay outside Excalidraw's render pipeline

```typescript
// excalidraw-app/components/Comments/ThreadMarkersLayer/ThreadMarkersLayer.tsx
export function ThreadMarkersLayer({ sceneId, excalidrawAPI }) {
  const [appState, setAppState] = useState<AppState | null>(null);
  
  // Manually subscribe to scroll/zoom changes
  useEffect(() => {
    const unsubscribe = excalidrawAPI.onScrollChange(() => {
      setAppState(excalidrawAPI.getAppState());
    });
    return unsubscribe;
  }, [excalidrawAPI]);
  
  // Manually calculate viewport positions
  const position = sceneCoordsToViewportCoords(
    { sceneX: thread.x, sceneY: thread.y },
    appState,
  );
  
  // Render as DOM overlay
  return (
    <div className={styles.layer}>
      {threads.map((thread) => (
        <ThreadMarker key={thread.id} x={position.x} y={position.y} />
      ))}
    </div>
  );
}
```

**Why this could be improved:**

1. **Position lag** - DOM updates lag behind canvas rendering
2. **Z-ordering issues** - Markers always render above all elements
3. **Manual subscription** - Reinvents what Excalidraw already does for collaborators

**Better approach:** Render markers in canvas (like collaborator cursors)

```typescript
// packages/excalidraw/clients.ts - How collaborators are rendered
export const renderRemoteCursors = ({
  context,
  renderConfig,
  appState,
}) => {
  for (const [socketId, pointer] of renderConfig.remotePointerViewportCoords) {
    // Draw directly on canvas context
    context.fillStyle = background;
    context.beginPath();
    context.moveTo(x, y);
    // ... cursor shape
    context.fill();
  }
};

// Called from packages/excalidraw/renderer/interactiveScene.ts
renderRemoteCursors({ context, renderConfig, appState, ... });
```

**Potential improvement:**
- Add `commentMarkers` to `InteractiveCanvasRenderConfig`
- Create `renderCommentMarkers()` similar to `renderRemoteCursors()`
- Markers render in sync with canvas, proper z-ordering

---

### Improvable Pattern: excalidrawAPI Prop Drilling

**Issue:** Many components receive `excalidrawAPI` just to access state or call methods

```typescript
// Current - prop drilling through multiple layers
<ThreadMarkersLayer excalidrawAPI={excalidrawAPI} />
<PresentationPanel excalidrawAPI={excalidrawAPI} />
<StickersPanel excalidrawAPI={excalidrawAPI} />
<CommentCreationOverlay excalidrawAPI={excalidrawAPI} />
```

**Why this happens:** Components need to call `getAppState()`, `updateScene()`, `scrollToContent()`, etc.

**Better approach:** Export hooks from `packages/excalidraw/`

```typescript
// packages/excalidraw/hooks/useAppState.ts (potential addition)
export function useAppState() {
  const appState = useUIAppState(); // Already exists internally
  return appState;
}

// Then components can use:
function ThreadMarkersLayer() {
  const appState = useAppState(); // No prop needed
  // ...
}
```

**Note:** Some internal hooks like `useUIAppState` already exist but aren't exported. Exporting them would reduce prop drilling.

---

## Anti-Patterns to Avoid

### 1. "I can't change Excalidraw"

❌ **Wrong thinking:**
> "This is Excalidraw code, I can't modify it. Let me work around it."

✅ **Correct thinking:**
> "This is OUR code. If the feature belongs in core, I'll add it there."

### 2. Importing Internal Hooks in App Layer

❌ **Problematic:**
```typescript
// excalidraw-app/components/MyComponent.tsx
import { useExcalidrawActionManager } from "@excalidraw/excalidraw/components/App";
```

✅ **Better:** If you need internal functionality, either:
- Export it properly from `packages/excalidraw/index.tsx`
- Or implement the feature in `packages/excalidraw/` where it has natural access

### 3. Using updateScene() to Work Around Missing Features

❌ **Workaround:**
```typescript
// Forcing state changes through updateScene
excalidrawAPI.updateScene({
  appState: { someHackyState: true }
});
```

✅ **Better:** Add proper state and actions to `packages/excalidraw/`

### 4. Heavy DOM Overlays for Canvas Features

❌ **Current approach for comments:**
```typescript
// Absolute positioned div tracking canvas pan/zoom
<div style={{ position: 'absolute', left: viewportX, top: viewportY }}>
  <CommentMarker />
</div>
```

✅ **Better:** Render on canvas context (like collaborator cursors)

---

## Extension Points in Excalidraw

These are the **intended** ways to extend Excalidraw:

### 1. Sidebar Tabs

```typescript
<DefaultSidebar>
  <DefaultSidebar.TabTriggers>
    <Sidebar.TabTrigger tab="myTab">{icon}</Sidebar.TabTrigger>
  </DefaultSidebar.TabTriggers>
  <Sidebar.Tab tab="myTab">
    <MyContent />
  </Sidebar.Tab>
</DefaultSidebar>
```

### 2. Main Menu Items

```typescript
<Excalidraw>
  <MainMenu>
    <MainMenu.Item onSelect={handleClick}>
      My Custom Item
    </MainMenu.Item>
  </MainMenu>
</Excalidraw>
```

### 3. Welcome Screen

```typescript
<Excalidraw>
  <WelcomeScreen>
    <WelcomeScreen.Center>
      <CustomLogo />
    </WelcomeScreen.Center>
  </WelcomeScreen>
</Excalidraw>
```

### 4. Footer

```typescript
<Excalidraw>
  <Footer>
    <CustomFooterContent />
  </Footer>
</Excalidraw>
```

### 5. UIOptions Prop

```typescript
<Excalidraw
  UIOptions={{
    canvasActions: {
      toggleTheme: true,
      export: { onExportToBackend },
    },
  }}
/>
```

### 6. renderTopRightUI Prop

```typescript
<Excalidraw
  renderTopRightUI={() => (
    <SaveStatusIndicator />
  )}
/>
```

---

## When to Modify Core vs Use Extension Points

| Scenario | Approach |
|----------|----------|
| Add sidebar tab with custom content | Use `DefaultSidebar.TabTriggers` |
| Add main menu item | Use `MainMenu.Item` |
| Change how elements render | Modify `packages/element/` |
| Add new element type | Modify `packages/element/` |
| Add canvas overlay (cursors, markers) | Modify `packages/excalidraw/renderer/` |
| Add keyboard shortcut | Add action to `packages/excalidraw/actions/` |
| Add toolbar button | Modify `packages/excalidraw/components/` |
| Integrate with backend API | Implement in `excalidraw-app/` |
| Add authentication | Implement in `excalidraw-app/` |

---

## File Reference

### Core Packages (We Own These)

| Path | Purpose |
|------|---------|
| `packages/excalidraw/components/App.tsx` | Main app component, state management |
| `packages/excalidraw/components/LayerUI.tsx` | UI layer composition |
| `packages/excalidraw/renderer/interactiveScene.ts` | Canvas rendering pipeline |
| `packages/excalidraw/clients.ts` | Collaborator cursor rendering |
| `packages/excalidraw/actions/` | Keyboard shortcuts, toolbar actions |
| `packages/excalidraw/types.ts` | TypeScript types for state |
| `packages/element/src/types.ts` | Element type definitions |

### App Layer (AstraDraw-Specific)

| Path | Purpose |
|------|---------|
| `excalidraw-app/App.tsx` | Main orchestrator |
| `excalidraw-app/components/Workspace/` | Sidebar, dashboard, scenes |
| `excalidraw-app/components/Comments/` | Comment system |
| `excalidraw-app/components/Talktrack/` | Video recording |
| `excalidraw-app/components/Presentation/` | Slideshow mode |
| `excalidraw-app/auth/` | Authentication, API client |

---

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - System overview
- [STATE_MANAGEMENT.md](STATE_MANAGEMENT.md) - React Query + Jotai patterns
- [TECHNICAL_DEBT_AND_IMPROVEMENTS.md](../planning/TECHNICAL_DEBT_AND_IMPROVEMENTS.md) - Improvement opportunities

