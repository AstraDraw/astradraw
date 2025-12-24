# Fork Architecture Refactoring Plan

This document provides detailed implementation plans for leveraging AstraDraw's controlled Excalidraw fork to improve existing implementations that were built as "workarounds" in `excalidraw-app/` but could be implemented more elegantly directly in `packages/excalidraw/`.

**Reference:** [FORK_ARCHITECTURE.md](../architecture/FORK_ARCHITECTURE.md) for background on fork ownership.

---

## Overview

### Why These Refactorings Matter

AstraDraw's `packages/excalidraw/` is a fully controlled fork, not an external dependency. This means we can:

1. **Add features to the core** instead of working around it
2. **Use internal APIs** that aren't exported
3. **Extend the render pipeline** for custom overlays
4. **Integrate with the action system** for consistent keyboard handling

Three existing implementations would benefit from this approach:

| Feature | Current Approach | Better Approach | Impact |
|---------|------------------|-----------------|--------|
| Comment Markers | DOM overlay with manual position tracking | Canvas rendering like collaborator cursors | High |
| Presentation Mode | Jotai atoms + window event listeners | Core action system + AppState | Medium |
| API Access | `excalidrawAPI` prop drilling (155 uses) | Export internal hooks | Medium |

---

## 1. Reduce excalidrawAPI Prop Drilling

> **Priority:** First (foundation for other work)
> **Effort:** 1 day
> **Risk:** Low

### Current Implementation

The `excalidrawAPI` prop is passed through component trees to access Excalidraw functionality:

```typescript
// Current pattern - prop drilling
function ParentComponent({ excalidrawAPI }: { excalidrawAPI: ExcalidrawImperativeAPI }) {
  return <ChildComponent excalidrawAPI={excalidrawAPI} />;
}

function ChildComponent({ excalidrawAPI }: { excalidrawAPI: ExcalidrawImperativeAPI }) {
  const appState = excalidrawAPI.getAppState();
  // ...
}
```

**Usage statistics:**
- 155 uses of `excalidrawAPI.` across 20 files
- Most common methods: `getAppState()`, `updateScene()`, `scrollToContent()`, `setActiveTool()`

### Problem

1. **Tight coupling** - Components depend on receiving the full API even when they only need one method
2. **Complex interfaces** - Props get cluttered with `excalidrawAPI`
3. **Testing difficulty** - Must mock the entire API for unit tests
4. **Prop threading** - Parent components must receive and forward the prop even if they don't use it

### Proposed Solution

Export existing internal hooks from `packages/excalidraw/index.tsx`:

```typescript
// packages/excalidraw/index.tsx - Add these exports

// Already exists internally at components/App.tsx:540
export { useApp } from "./components/App";

// Already exists at context/ui-appState.ts
export { useUIAppState } from "./context/ui-appState";
```

Then migrate components to use hooks:

```typescript
// After - using hooks
import { useApp, useUIAppState } from "@excalidraw/excalidraw";

function ChildComponent() {
  const app = useApp();
  const appState = useUIAppState();
  
  // Access methods directly
  const handleClick = () => app.scrollToContent(element);
}
```

### Files to Modify

| File | Change |
|------|--------|
| `packages/excalidraw/index.tsx` | Add exports for `useApp`, `useUIAppState` |
| `packages/excalidraw/components/App.tsx` | Ensure `useApp` is exported (already is) |

### Step-by-Step Implementation

#### Step 1: Export hooks from packages/excalidraw/index.tsx

```typescript
// Add near line 288 (after useEditorInterface export)
export { useApp, useAppProps } from "./components/App";
export { useUIAppState } from "./context/ui-appState";
```

#### Step 2: Gradual migration (can be done incrementally)

Start with components that only use `getAppState()`:

**Priority 1 - Simple cases (only read state):**
- `ThreadMarkersLayer.tsx` - Uses `excalidrawAPI.getAppState()`
- `CommentsSidebar.tsx` - Uses `excalidrawAPI.getAppState()`
- `NewThreadPopup.tsx` - Uses `excalidrawAPI.getAppState()`

**Priority 2 - Medium cases (read + simple actions):**
- `PenToolbar.tsx` - Uses `getAppState()`, `setActiveTool()`
- `StickersPanel.tsx` - Uses `getAppState()`, `updateScene()`

**Priority 3 - Complex cases (multiple methods):**
- `usePresentationMode.ts` - Uses many methods, refactor after presentation actions
- `Collab.tsx` - Core collaboration, requires careful migration

#### Step 3: Example migration

Before:
```typescript
// ThreadMarkersLayer.tsx
export function ThreadMarkersLayer({
  sceneId,
  excalidrawAPI,
}: ThreadMarkersLayerProps) {
  const [appState, setAppState] = useState<AppState | null>(null);

  useEffect(() => {
    if (!excalidrawAPI) return;
    setAppState(excalidrawAPI.getAppState());
    const unsubscribe = excalidrawAPI.onScrollChange(() => {
      setAppState(excalidrawAPI.getAppState());
    });
    return unsubscribe;
  }, [excalidrawAPI]);
  // ...
}
```

After (INCORRECT - doesn't work for scroll/zoom tracking):
```typescript
// ❌ This approach DOES NOT WORK for components tracking pan/zoom!
// ThreadMarkersLayer.tsx
import { useUIAppState } from "@excalidraw/excalidraw";

export function ThreadMarkersLayer({ sceneId }: ThreadMarkersLayerProps) {
  // useUIAppState does NOT update on scrollX/scrollY/zoom changes!
  const appState = useUIAppState();
  // Markers will NOT move during pan/zoom
}
```

After (CORRECT - for components that need scroll/zoom reactivity):
```typescript
// ✅ Components tracking pan/zoom MUST use subscriptions
// ThreadMarkersLayer.tsx
export function ThreadMarkersLayer({ sceneId, excalidrawAPI }: ThreadMarkersLayerProps) {
  const [appState, setAppState] = useState<AppState | null>(null);

  // Subscribe to scroll/zoom changes
  useEffect(() => {
    if (!excalidrawAPI) return;
    setAppState(excalidrawAPI.getAppState());
    const unsubscribe = excalidrawAPI.onScrollChange(() => {
      setAppState(excalidrawAPI.getAppState());
    });
    return unsubscribe;
  }, [excalidrawAPI]);

  // Also subscribe to offset changes (sidebar open/close)
  useEffect(() => {
    if (!excalidrawAPI) return;
    let lastOffsetLeft = excalidrawAPI.getAppState().offsetLeft;
    
    const unsubscribe = excalidrawAPI.onChange(() => {
      const current = excalidrawAPI.getAppState();
      if (current.offsetLeft !== lastOffsetLeft) {
        lastOffsetLeft = current.offsetLeft;
        setAppState(current);
      }
    });
    return unsubscribe;
  }, [excalidrawAPI]);
  // ...
}
```

### Benefits

1. **Cleaner interfaces** - No `excalidrawAPI` prop needed
2. **Better encapsulation** - Components only access what they need
3. **Easier testing** - Can mock individual hooks
4. **Reduced coupling** - Components don't depend on parent passing prop
5. **Foundation** - Enables cleaner implementation of other refactorings

### Caveats

- `useApp` and `useUIAppState` only work inside Excalidraw's component tree
- Components rendered outside (e.g., portals to document.body) still need the API prop
- Migration should be gradual to avoid breaking changes

> ⚠️ **CRITICAL LIMITATION DISCOVERED:**
> 
> **`useApp().state` is NOT reactive!** Components that access `app.state` directly will NOT re-render when state changes. This makes `useApp()` unsuitable for components that need to track `scrollX`, `scrollY`, `zoom`, or `offsetLeft`/`offsetTop`.
> 
> For reactive state access, components must still use:
> - `excalidrawAPI.onScrollChange()` for scroll/zoom changes
> - `excalidrawAPI.onChange()` for general state changes (including `offsetLeft`/`offsetTop`)
> 
> See **"Lessons Learned & Caveats"** section at the end of this document for details.

---

## 2. Presentation Mode Actions

> **Priority:** Second
> **Effort:** 1-2 days
> **Risk:** Medium

### Current Implementation

Presentation mode is implemented in `excalidraw-app/components/Presentation/usePresentationMode.ts` (386 lines):

```typescript
// Current approach - Jotai atoms + window event listeners
export const presentationModeAtom = atom(false);
export const currentSlideAtom = atom(0);
export const slidesAtom = atom<ExcalidrawFrameLikeElement[]>([]);

export const usePresentationMode = ({ excalidrawAPI }) => {
  // Keyboard handling via useEffect
  useEffect(() => {
    if (!isPresentationMode) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      switch (e.key) {
        case "ArrowRight":
        case " ":
          e.preventDefault();
          nextSlide();
          break;
        case "Escape":
          e.preventDefault();
          endPresentation();
          break;
        // ...
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [isPresentationMode, nextSlide, prevSlide, endPresentation]);
  // ...
};
```

### Problem

1. **Bypasses action system** - Keyboard shortcuts don't go through Excalidraw's unified action handling
2. **Not in command palette** - Users can't discover presentation shortcuts
3. **Potential conflicts** - May conflict with core shortcuts (e.g., Space for panning)
4. **State fragmentation** - Presentation state in Jotai, not AppState
5. **No undo integration** - Actions aren't captured in history

### Proposed Solution

Create `actionPresentation.ts` in `packages/excalidraw/actions/` following the pattern in `actionFrame.ts`:

```typescript
// packages/excalidraw/actions/actionPresentation.ts
import { register } from "./register";
import { KEYS } from "@excalidraw/common";
import type { AppState } from "../types";

export const actionStartPresentation = register({
  name: "startPresentation",
  label: "labels.startPresentation",
  icon: presentationIcon,
  trackEvent: { category: "presentation" },
  viewMode: true,
  perform: (elements, appState, _, app) => {
    const frames = getFramesSortedForPresentation(elements);
    if (frames.length === 0) {
      app.setToast({ message: "No frames found", duration: 3000 });
      return { elements, appState, captureUpdate: CaptureUpdateAction.EVENTUALLY };
    }

    return {
      elements,
      appState: {
        ...appState,
        presentationMode: {
          active: true,
          currentSlide: 0,
          slides: frames.map(f => f.id),
        },
        viewModeEnabled: true,
        zenModeEnabled: true,
      },
      captureUpdate: CaptureUpdateAction.EVENTUALLY,
    };
  },
  predicate: (elements) => {
    // Only available if there are frames
    return elements.some(el => el.type === "frame" && !el.isDeleted);
  },
  keyTest: (event) =>
    event.altKey && event.shiftKey && event.key.toLowerCase() === "p",
});

export const actionNextSlide = register({
  name: "nextSlide",
  label: "labels.nextSlide",
  trackEvent: { category: "presentation" },
  viewMode: true,
  perform: (elements, appState, _, app) => {
    if (!appState.presentationMode?.active) {
      return { elements, appState, captureUpdate: CaptureUpdateAction.EVENTUALLY };
    }

    const { currentSlide, slides } = appState.presentationMode;
    if (currentSlide >= slides.length - 1) {
      return { elements, appState, captureUpdate: CaptureUpdateAction.EVENTUALLY };
    }

    const nextSlide = currentSlide + 1;
    const frameId = slides[nextSlide];
    const frame = elements.find(el => el.id === frameId);

    if (frame) {
      app.scrollToContent(frame, {
        fitToViewport: true,
        viewportZoomFactor: 1.0,
        animate: true,
        duration: 800,
      });
    }

    return {
      elements,
      appState: {
        ...appState,
        presentationMode: {
          ...appState.presentationMode,
          currentSlide: nextSlide,
        },
      },
      captureUpdate: CaptureUpdateAction.EVENTUALLY,
    };
  },
  predicate: (_, appState) => !!appState.presentationMode?.active,
  keyTest: (event) =>
    !event.ctrlKey &&
    !event.metaKey &&
    !event.altKey &&
    (event.key === "ArrowRight" || event.key === "ArrowDown" || event.key === " "),
});

export const actionPrevSlide = register({
  name: "prevSlide",
  label: "labels.prevSlide",
  trackEvent: { category: "presentation" },
  viewMode: true,
  perform: (elements, appState, _, app) => {
    if (!appState.presentationMode?.active) {
      return { elements, appState, captureUpdate: CaptureUpdateAction.EVENTUALLY };
    }

    const { currentSlide } = appState.presentationMode;
    if (currentSlide <= 0) {
      return { elements, appState, captureUpdate: CaptureUpdateAction.EVENTUALLY };
    }

    const prevSlide = currentSlide - 1;
    const frameId = appState.presentationMode.slides[prevSlide];
    const frame = elements.find(el => el.id === frameId);

    if (frame) {
      app.scrollToContent(frame, {
        fitToViewport: true,
        viewportZoomFactor: 1.0,
        animate: true,
        duration: 800,
      });
    }

    return {
      elements,
      appState: {
        ...appState,
        presentationMode: {
          ...appState.presentationMode,
          currentSlide: prevSlide,
        },
      },
      captureUpdate: CaptureUpdateAction.EVENTUALLY,
    };
  },
  predicate: (_, appState) => !!appState.presentationMode?.active,
  keyTest: (event) =>
    !event.ctrlKey &&
    !event.metaKey &&
    !event.altKey &&
    (event.key === "ArrowLeft" || event.key === "ArrowUp"),
});

export const actionExitPresentation = register({
  name: "exitPresentation",
  label: "labels.exitPresentation",
  trackEvent: { category: "presentation" },
  viewMode: true,
  perform: (elements, appState) => {
    return {
      elements,
      appState: {
        ...appState,
        presentationMode: null,
        viewModeEnabled: false,
        zenModeEnabled: false,
      },
      captureUpdate: CaptureUpdateAction.EVENTUALLY,
    };
  },
  predicate: (_, appState) => !!appState.presentationMode?.active,
  keyTest: (event) => event.key === "Escape",
});
```

### Files to Modify

| File | Change |
|------|--------|
| `packages/excalidraw/types.ts` | Add `presentationMode` to `AppState` |
| `packages/excalidraw/actions/actionPresentation.ts` | New file with presentation actions |
| `packages/excalidraw/actions/index.ts` | Export presentation actions |
| `excalidraw-app/components/Presentation/usePresentationMode.ts` | Simplify to use core actions |
| `excalidraw-app/components/Presentation/PresentationControls/` | Update to dispatch actions |

### Step-by-Step Implementation

#### Step 1: Add presentation state to AppState

```typescript
// packages/excalidraw/types.ts - Add to AppState interface

export interface PresentationModeState {
  active: boolean;
  currentSlide: number;
  slides: string[]; // Frame IDs in presentation order
  originalTheme?: Theme;
  originalFrameRendering?: FrameRenderingState;
}

export interface AppState {
  // ... existing properties
  presentationMode: PresentationModeState | null;
}
```

#### Step 2: Create actionPresentation.ts

Create the file as shown in the proposed solution above.

#### Step 3: Register actions

```typescript
// packages/excalidraw/actions/index.ts
export {
  actionStartPresentation,
  actionNextSlide,
  actionPrevSlide,
  actionExitPresentation,
} from "./actionPresentation";
```

#### Step 4: Update usePresentationMode.ts

```typescript
// Simplified hook that uses core actions
export const usePresentationMode = () => {
  const appState = useUIAppState();
  const app = useApp();

  const isPresentationMode = appState.presentationMode?.active ?? false;
  const currentSlide = appState.presentationMode?.currentSlide ?? 0;
  const slides = appState.presentationMode?.slides ?? [];

  // Actions are now handled by the action system
  // This hook just provides convenient access to state
  const startPresentation = useCallback(() => {
    app.actionManager.executeAction(actionStartPresentation);
  }, [app]);

  const endPresentation = useCallback(() => {
    app.actionManager.executeAction(actionExitPresentation);
  }, [app]);

  return {
    isPresentationMode,
    currentSlide,
    totalSlides: slides.length,
    startPresentation,
    endPresentation,
    // Navigation handled by action system via keyboard
  };
};
```

### Benefits

1. **Unified keyboard handling** - All shortcuts go through action system
2. **Command palette integration** - Users can discover and trigger presentation actions
3. **No conflicts** - Action system handles priority and context
4. **State in AppState** - Consistent with other Excalidraw state
5. **Extensible** - Easy to add new presentation actions

### Caveats

- Presentation state becomes part of scene state (may affect save/load)
- Need to handle state restoration carefully on exit
- Some AstraDraw-specific features (Talktrack integration) remain in app layer

> ✅ **Safe to implement:** This phase is NOT affected by the reactivity issues discovered in Phase 1.
> 
> **Why it's safe:**
> - `useUIAppState()` is used to read `presentationMode.currentSlide` which only changes on discrete user actions (button clicks, keyboard shortcuts), not on continuous scroll/zoom
> - The action system is reactive by design - when actions update `appState.presentationMode`, components using `useUIAppState()` will re-render
> - No need to track `scrollX`/`scrollY`/`zoom` changes in real-time
> 
> **One exception:** If you add animated slide transitions that need to track scroll position during animation, use `excalidrawAPI.onScrollChange()` for that specific case.

---

## 3. Native Comment Markers

> **Priority:** Third (highest impact, requires canvas knowledge)
> **Effort:** 2-3 days
> **Risk:** Medium-High

### Current Implementation

`ThreadMarkersLayer` (159 lines) renders comment markers as a DOM overlay:

```typescript
// excalidraw-app/components/Comments/ThreadMarkersLayer/ThreadMarkersLayer.tsx
export function ThreadMarkersLayer({ sceneId, excalidrawAPI }: ThreadMarkersLayerProps) {
  const [appState, setAppState] = useState<AppState | null>(null);

  // Subscribe to scroll/zoom changes
  useEffect(() => {
    if (!excalidrawAPI) return;
    setAppState(excalidrawAPI.getAppState());
    const unsubscribe = excalidrawAPI.onScrollChange(() => {
      setAppState(excalidrawAPI.getAppState());
    });
    return unsubscribe;
  }, [excalidrawAPI]);

  // Calculate viewport positions
  const markersWithPositions = useMemo(() => {
    if (!appState) return [];
    return threads.map((thread) => ({
      thread,
      position: sceneCoordsToViewportCoords(
        { sceneX: thread.x, sceneY: thread.y },
        appState,
      ),
    }));
  }, [threads, appState]);

  // Render DOM elements
  return (
    <div className={styles.layer}>
      {markersWithPositions.map(({ thread, position }) => (
        <ThreadMarker
          key={thread.id}
          thread={thread}
          x={position.x}
          y={position.y}
          // ...
        />
      ))}
    </div>
  );
}
```

### Problem

1. **Position lag** - DOM updates happen after canvas renders, causing visual lag during pan/zoom
2. **Z-ordering impossible** - DOM overlay is always on top, can't render markers behind elements
3. **Duplicated logic** - Manually tracking scroll/zoom duplicates what Excalidraw does internally
4. **Performance** - React reconciliation for many markers during rapid pan/zoom
5. **Inconsistent** - Different rendering approach than collaborator cursors

### Proposed Solution

Render comment markers in Excalidraw's canvas renderer, following the `renderRemoteCursors()` pattern in `clients.ts`:

```typescript
// packages/excalidraw/clients.ts - Add after renderRemoteCursors

export interface CommentMarker {
  id: string;
  x: number; // Scene coordinates
  y: number;
  resolved: boolean;
  selected: boolean;
  authorColor?: string;
}

export const renderCommentMarkers = ({
  context,
  appState,
  markers,
  normalizedWidth,
  normalizedHeight,
}: {
  context: CanvasRenderingContext2D;
  appState: InteractiveCanvasAppState;
  markers: CommentMarker[];
  normalizedWidth: number;
  normalizedHeight: number;
}) => {
  const MARKER_SIZE = 24;
  const MARKER_RADIUS = MARKER_SIZE / 2;

  for (const marker of markers) {
    if (marker.resolved) continue;

    // Convert scene coords to viewport coords
    const viewportX = marker.x * appState.zoom.value + appState.scrollX - appState.offsetLeft;
    const viewportY = marker.y * appState.zoom.value + appState.scrollY - appState.offsetTop;

    // Skip if outside viewport
    if (
      viewportX < -MARKER_SIZE ||
      viewportX > normalizedWidth + MARKER_SIZE ||
      viewportY < -MARKER_SIZE ||
      viewportY > normalizedHeight + MARKER_SIZE
    ) {
      continue;
    }

    context.save();

    // Draw marker background (speech bubble shape)
    const bgColor = marker.selected
      ? "#6965db" // Selected - purple
      : marker.authorColor || "#3b82f6"; // Default - blue

    context.fillStyle = bgColor;
    context.strokeStyle = "#ffffff";
    context.lineWidth = 2;

    // Draw rounded rectangle with tail
    context.beginPath();
    
    // Main bubble
    const bubbleX = viewportX;
    const bubbleY = viewportY;
    const bubbleWidth = MARKER_SIZE;
    const bubbleHeight = MARKER_SIZE;
    const cornerRadius = 6;

    // Draw rounded rect
    context.moveTo(bubbleX + cornerRadius, bubbleY);
    context.lineTo(bubbleX + bubbleWidth - cornerRadius, bubbleY);
    context.quadraticCurveTo(bubbleX + bubbleWidth, bubbleY, bubbleX + bubbleWidth, bubbleY + cornerRadius);
    context.lineTo(bubbleX + bubbleWidth, bubbleY + bubbleHeight - cornerRadius);
    context.quadraticCurveTo(bubbleX + bubbleWidth, bubbleY + bubbleHeight, bubbleX + bubbleWidth - cornerRadius, bubbleY + bubbleHeight);
    
    // Tail pointing to exact position
    context.lineTo(bubbleX + 8, bubbleY + bubbleHeight);
    context.lineTo(bubbleX, bubbleY + bubbleHeight + 6); // Tail tip
    context.lineTo(bubbleX + 4, bubbleY + bubbleHeight);
    
    context.lineTo(bubbleX + cornerRadius, bubbleY + bubbleHeight);
    context.quadraticCurveTo(bubbleX, bubbleY + bubbleHeight, bubbleX, bubbleY + bubbleHeight - cornerRadius);
    context.lineTo(bubbleX, bubbleY + cornerRadius);
    context.quadraticCurveTo(bubbleX, bubbleY, bubbleX + cornerRadius, bubbleY);
    
    context.closePath();
    context.fill();
    context.stroke();

    // Draw comment icon
    context.fillStyle = "#ffffff";
    context.font = "bold 12px sans-serif";
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillText("💬", bubbleX + MARKER_RADIUS, bubbleY + MARKER_RADIUS);

    context.restore();
  }
};
```

### Files to Modify

| File | Change |
|------|--------|
| `packages/excalidraw/scene/types.ts` | Add `commentMarkers` to `InteractiveCanvasRenderConfig` |
| `packages/excalidraw/clients.ts` | Add `renderCommentMarkers()` function |
| `packages/excalidraw/renderer/interactiveScene.ts` | Call `renderCommentMarkers()` in render pipeline |
| `packages/excalidraw/types.ts` | Add `commentMarkers` to `AppState` |
| `excalidraw-app/components/Comments/ThreadMarkersLayer/` | Simplify to data provider |

### Step-by-Step Implementation

#### Step 1: Add types

```typescript
// packages/excalidraw/scene/types.ts
export interface InteractiveCanvasRenderConfig {
  // ... existing properties
  commentMarkers: Map<string, CommentMarker>;
}

// packages/excalidraw/types.ts - Add to AppState
export interface AppState {
  // ... existing properties
  commentMarkers: CommentMarker[];
}
```

#### Step 2: Add render function to clients.ts

Add the `renderCommentMarkers()` function as shown in the proposed solution.

#### Step 3: Call from render pipeline

```typescript
// packages/excalidraw/renderer/interactiveScene.ts
// Add after line 1555 (after renderRemoteCursors)

if (renderConfig.commentMarkers?.size > 0) {
  renderCommentMarkers({
    context,
    appState,
    markers: Array.from(renderConfig.commentMarkers.values()),
    normalizedWidth,
    normalizedHeight,
  });
}
```

#### Step 4: Simplify ThreadMarkersLayer

```typescript
// excalidraw-app/components/Comments/ThreadMarkersLayer/ThreadMarkersLayer.tsx
// Now just provides data to Excalidraw via appState

export function ThreadMarkersLayer({ sceneId }: { sceneId: string }) {
  const app = useApp();
  const { data: threads = [] } = useQuery({
    queryKey: queryKeys.commentThreads.list(sceneId),
    queryFn: () => listThreads(sceneId),
    enabled: !!sceneId,
  });

  // Update appState with comment markers
  useEffect(() => {
    const markers: CommentMarker[] = threads
      .filter(t => !t.resolved)
      .map(t => ({
        id: t.id,
        x: t.x,
        y: t.y,
        resolved: t.resolved,
        selected: t.id === selectedThreadId,
      }));

    app.updateScene({
      appState: { commentMarkers: markers },
    });

    return () => {
      app.updateScene({
        appState: { commentMarkers: [] },
      });
    };
  }, [threads, selectedThreadId, app]);

  // No DOM rendering needed - canvas handles it
  return null;
}
```

#### Step 5: Handle click detection

```typescript
// packages/excalidraw/components/App.tsx
// Add to handleCanvasPointerDown or similar

private handleCommentMarkerClick(x: number, y: number): string | null {
  const { commentMarkers } = this.state;
  const MARKER_SIZE = 24;

  for (const marker of commentMarkers) {
    const viewportX = marker.x * this.state.zoom.value + this.state.scrollX;
    const viewportY = marker.y * this.state.zoom.value + this.state.scrollY;

    if (
      x >= viewportX &&
      x <= viewportX + MARKER_SIZE &&
      y >= viewportY &&
      y <= viewportY + MARKER_SIZE + 6 // Include tail
    ) {
      return marker.id;
    }
  }
  return null;
}
```

### Benefits

1. **No position lag** - Markers render in same frame as canvas
2. **Proper z-ordering** - Can render markers at correct layer in future
3. **Better performance** - No React reconciliation during pan/zoom
4. **Consistent approach** - Same pattern as collaborator cursors
5. **Foundation for element-attached comments** - Can associate markers with elements

### Caveats

- Click handling needs to be added to Excalidraw's event system
- Drag-to-move markers requires additional canvas interaction handling
- Tooltip/hover states may still need DOM elements
- Consider hybrid approach: canvas for markers, DOM for popups

> ⚠️ **Implementation notes based on Phase 1 learnings:**
> 
> **What's safe:**
> - The canvas rendering (`renderCommentMarkers()`) is called on every render frame by Excalidraw's render pipeline, so it will always have correct `scrollX`/`scrollY`/`zoom` values
> - The simplified `ThreadMarkersLayer` only **writes** data to appState via `updateScene()`, it doesn't need to **read** scroll/zoom state
> - Click detection code runs inside `App.tsx` where `this.state` is always current
> 
> **What to watch out for:**
> - The simplified `ThreadMarkersLayer` uses `useApp()` - this is fine for calling `app.updateScene()`, but do NOT use `app.state` to read scroll/zoom values
> - If you need to filter markers by visibility (e.g., skip markers outside viewport), do this calculation in the canvas render function, NOT in React component
> - The coordinate conversion in `renderCommentMarkers` must subtract `offsetLeft`/`offsetTop` (already shown in the code example)
> 
> **Coordinate system reminder:**
> ```typescript
> // In canvas render function - correct:
> const viewportX = marker.x * appState.zoom.value + appState.scrollX - appState.offsetLeft;
> const viewportY = marker.y * appState.zoom.value + appState.scrollY - appState.offsetTop;
> ```

---

## Recommended Implementation Order

### Phase 1: Foundation (1 day) - ⚠️ PARTIALLY COMPLETED

**Completed:**
- ✅ Exported `useApp`, `useAppProps`, `useUIAppState` from `packages/excalidraw/index.tsx`

**Not completed (blocked by reactivity limitations):**
- ❌ Component migrations - `useApp().state` is not reactive for scroll/zoom tracking
- ❌ Cannot remove `excalidrawAPI` prop from components that track pan/zoom

**Outcome:** Hooks are exported and available, but components tracking scroll/zoom must continue using `excalidrawAPI.onScrollChange()` subscriptions. See "Lessons Learned & Caveats" section.

### Phase 2: Presentation Actions (1-2 days) - ✅ COMPLETED
1. ✅ **Added presentation state** to AppState (`PresentationModeState` interface)
2. ✅ **Created actionPresentation.ts** with 7 actions: `actionStartPresentation`, `actionNextSlide`, `actionPrevSlide`, `actionExitPresentation`, `actionTogglePresentationLaser`, `actionTogglePresentationTheme`, `actionGoToSlide`
3. ✅ **Simplified usePresentationMode** to use action system for keyboard handling
4. ⏳ **Test keyboard shortcuts** - requires manual testing

*Keyboard shortcuts now handled by action system: Arrow keys, Space, Escape, L, T, Alt+Shift+P*

### Phase 3: Comment Markers (2-3 days) - ✅ READY TO IMPLEMENT (with notes)
1. **Add render function** to clients.ts
2. **Integrate into render pipeline**
3. **Simplify ThreadMarkersLayer** to data provider
4. **Add click detection** for marker selection
5. **Test pan/zoom performance**

*Review implementation notes in Phase 3 Caveats section before starting.*

### Phase 4: Cleanup (ongoing)
1. **Continue migrating** components from excalidrawAPI prop
2. **Remove unused** Jotai atoms from presentation
3. **Document** new patterns in FORK_ARCHITECTURE.md

---

## Shared Patterns

### Pattern 1: Adding to AppState

When adding new state to Excalidraw:

```typescript
// 1. Add type to packages/excalidraw/types.ts
export interface AppState {
  myFeature: MyFeatureState | null;
}

// 2. Add default in packages/excalidraw/appState.ts
export const getDefaultAppState = (): Omit<AppState, "..."> => ({
  myFeature: null,
});

// 3. Update via actions or updateScene
app.updateScene({
  appState: { myFeature: { ... } },
});
```

### Pattern 2: Creating Actions

Follow the pattern in `actionFrame.ts`:

```typescript
export const actionMyFeature = register({
  name: "myFeature",           // Unique identifier
  label: "labels.myFeature",   // i18n key
  icon: myIcon,                // Optional icon
  trackEvent: { category: "myCategory" },
  viewMode: false,             // Available in view mode?
  
  perform: (elements, appState, _, app) => {
    // Return new state
    return {
      elements,
      appState: { ...appState, /* changes */ },
      captureUpdate: CaptureUpdateAction.EVENTUALLY,
    };
  },
  
  predicate: (elements, appState) => {
    // When is action available?
    return true;
  },
  
  keyTest: (event) => {
    // Keyboard shortcut
    return event.key === "x" && !event.ctrlKey;
  },
});
```

### Pattern 3: Canvas Rendering

Follow the pattern in `clients.ts`:

```typescript
export const renderMyFeature = ({
  context,
  appState,
  data,
  normalizedWidth,
  normalizedHeight,
}: {
  context: CanvasRenderingContext2D;
  appState: InteractiveCanvasAppState;
  data: MyData[];
  normalizedWidth: number;
  normalizedHeight: number;
}) => {
  for (const item of data) {
    // Convert scene to viewport coords
    const viewportX = item.x * appState.zoom.value + appState.scrollX - appState.offsetLeft;
    const viewportY = item.y * appState.zoom.value + appState.scrollY - appState.offsetTop;

    // Skip if outside viewport
    if (isOutsideViewport(viewportX, viewportY, normalizedWidth, normalizedHeight)) {
      continue;
    }

    context.save();
    // Draw...
    context.restore();
  }
};
```

---

## Related Documentation

- [FORK_ARCHITECTURE.md](../architecture/FORK_ARCHITECTURE.md) - Fork ownership model
- [TECHNICAL_DEBT_AND_IMPROVEMENTS.md](TECHNICAL_DEBT_AND_IMPROVEMENTS.md) - Other improvements
- [STATE_MANAGEMENT.md](../architecture/STATE_MANAGEMENT.md) - When to use Jotai vs AppState

---

## Lessons Learned & Caveats

This section documents important discoveries made during implementation that should inform future refactoring work.

### 1. `useApp().state` is NOT Reactive

**Discovery:** When we attempted to migrate `ThreadMarkersLayer`, `NewThreadPopup`, and `CommentsSidebar` to use `useApp().state` instead of `excalidrawAPI.getAppState()`, the comment markers stopped moving during pan/zoom.

**Root Cause:** `app.state` (from `useApp()`) is a direct reference to the App component's state object. Accessing it does NOT trigger React re-renders when the state changes. It's essentially a snapshot that becomes stale.

**Correct Approach:** For components that need to react to state changes (especially `scrollX`, `scrollY`, `zoom`):
- Use `excalidrawAPI.onScrollChange()` to subscribe to scroll/zoom updates
- Use `excalidrawAPI.onChange()` to subscribe to general state changes
- Call `excalidrawAPI.getAppState()` inside the callback to get fresh state

```typescript
// ❌ WRONG - state is not reactive
const app = useApp();
const zoom = app.state.zoom; // Won't update on zoom changes

// ✅ CORRECT - subscribe to changes
useEffect(() => {
  const unsubscribe = excalidrawAPI.onScrollChange(() => {
    setAppState(excalidrawAPI.getAppState()); // Get fresh state
  });
  return unsubscribe;
}, [excalidrawAPI]);
```

**When `useUIAppState()` IS useful:**
- Components that only need to read state once (not track changes)
- Components that re-render for other reasons and just need current values
- Static UI that doesn't need to animate with pan/zoom

### 2. `onScrollChange` Does NOT Fire on `offsetLeft`/`offsetTop` Changes

**Discovery:** When the left workspace sidebar opens/closes, the canvas container shifts (changing `offsetLeft`), but `onScrollChange` is not triggered because only `scrollX`, `scrollY`, and `zoom` changes fire it.

**Impact:** Comment markers appeared to shift when sidebar state changed because their positions weren't recalculated.

**Solution:** Subscribe to both `onScrollChange` AND `onChange`, checking for offset changes:

```typescript
// Subscribe to scroll/zoom
useEffect(() => {
  const unsubscribe = excalidrawAPI.onScrollChange(() => {
    setAppState(excalidrawAPI.getAppState());
  });
  return unsubscribe;
}, [excalidrawAPI]);

// Also subscribe to offset changes (sidebar open/close)
useEffect(() => {
  let lastOffsetLeft = excalidrawAPI.getAppState().offsetLeft;
  let lastOffsetTop = excalidrawAPI.getAppState().offsetTop;

  const unsubscribe = excalidrawAPI.onChange(() => {
    const currentState = excalidrawAPI.getAppState();
    if (
      currentState.offsetLeft !== lastOffsetLeft ||
      currentState.offsetTop !== lastOffsetTop
    ) {
      lastOffsetLeft = currentState.offsetLeft;
      lastOffsetTop = currentState.offsetTop;
      setAppState(currentState);
    }
  });
  return unsubscribe;
}, [excalidrawAPI]);
```

### 3. Viewport vs Container Coordinates

**Discovery:** `sceneCoordsToViewportCoords()` returns coordinates relative to the **browser window** (viewport), but components rendered inside the Excalidraw container need coordinates relative to **that container**.

**Impact:** When sidebar is open, the Excalidraw container is shifted right by `offsetLeft` pixels. If markers use viewport coordinates directly, they appear shifted by double the offset.

**Solution:** Subtract `offsetLeft`/`offsetTop` when positioning elements inside the Excalidraw container:

```typescript
// sceneCoordsToViewportCoords returns viewport (window) coordinates
const viewportCoords = sceneCoordsToViewportCoords(
  { sceneX: thread.x, sceneY: thread.y },
  appState,
);

// Convert to container-relative coordinates
const containerCoords = {
  x: viewportCoords.x - appState.offsetLeft,
  y: viewportCoords.y - appState.offsetTop,
};
```

### 4. Browser Zoom vs Canvas Zoom on Trackpad

**Discovery:** Pinch-to-zoom gestures on trackpad only zoom the canvas when the cursor is over the canvas element. When cursor is over toolbar or other UI elements, the browser's native zoom kicks in, zooming the entire page.

**Root Cause:** Excalidraw's `handleWheel` only processes events where `event.target` is a canvas, textarea, or iframe. For other targets, it only calls `preventDefault()` if `ctrlKey` is pressed, but then returns early without zooming the canvas.

**Solution:** Add a global wheel event handler at the app level that:
1. Intercepts pinch-zoom gestures (`ctrlKey` or `metaKey` pressed)
2. Prevents browser zoom when cursor is over Excalidraw UI (but not canvas)
3. Forwards the zoom to the canvas via `excalidrawAPI.updateScene()`

```typescript
useEffect(() => {
  const preventBrowserZoom = (event: WheelEvent) => {
    if (event.ctrlKey || event.metaKey) {
      const target = event.target as HTMLElement;
      const isOnCanvas = target instanceof HTMLCanvasElement;
      const isInsideExcalidraw = target.closest(".excalidraw");

      if (isInsideExcalidraw && !isOnCanvas) {
        event.preventDefault();
        // Forward zoom to canvas via excalidrawAPI.updateScene()
      }
    }
  };

  document.addEventListener("wheel", preventBrowserZoom, {
    passive: false,
    capture: true,
  });
  return () => document.removeEventListener("wheel", preventBrowserZoom, { capture: true });
}, [excalidrawAPI]);
```

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-24 | Initial document with three refactoring plans |
| 2025-12-24 | Phase 1 attempted: Exported `useApp`, `useAppProps`, `useUIAppState` from `packages/excalidraw/index.tsx` |
| 2025-12-24 | Phase 1 reverted: Component migrations reverted due to `useApp().state` not being reactive for scroll/zoom tracking. Hook exports retained for future use. |
| 2025-12-24 | Bug fix: Added `onChange` subscription to `ThreadMarkersLayer` and `NewThreadPopup` to handle `offsetLeft`/`offsetTop` changes (sidebar open/close) |
| 2025-12-24 | Bug fix: Fixed marker position calculation to subtract `offsetLeft`/`offsetTop` for container-relative positioning |
| 2025-12-24 | Bug fix: Added global wheel handler to prevent browser zoom when pinch-zooming over UI elements |
| 2025-12-24 | Added "Lessons Learned & Caveats" section documenting reactivity issues, coordinate systems, and zoom handling |
| 2025-12-24 | **Phase 2 completed**: Created `actionPresentation.ts` with 7 presentation actions (start, next, prev, exit, toggle laser, toggle theme, go to slide). Added `PresentationModeState` to AppState. Refactored `usePresentationMode.ts` to use action system for keyboard handling. |

