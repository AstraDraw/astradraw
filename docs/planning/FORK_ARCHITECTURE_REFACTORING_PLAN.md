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

After:
```typescript
// ThreadMarkersLayer.tsx
import { useUIAppState } from "@excalidraw/excalidraw";

export function ThreadMarkersLayer({ sceneId }: ThreadMarkersLayerProps) {
  // useUIAppState automatically updates on state changes
  const appState = useUIAppState();
  // No need for useEffect subscription - hook handles reactivity
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

---

## Recommended Implementation Order

### Phase 1: Foundation (1 day)
1. **Export hooks** from `packages/excalidraw/index.tsx`
2. **Migrate 2-3 simple components** to validate approach
3. **Document pattern** for future migrations

### Phase 2: Presentation Actions (1-2 days)
1. **Add presentation state** to AppState
2. **Create actionPresentation.ts** with all actions
3. **Simplify usePresentationMode** to use actions
4. **Test keyboard shortcuts** work correctly

### Phase 3: Comment Markers (2-3 days)
1. **Add render function** to clients.ts
2. **Integrate into render pipeline**
3. **Simplify ThreadMarkersLayer** to data provider
4. **Add click detection** for marker selection
5. **Test pan/zoom performance**

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

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-24 | Initial document with three refactoring plans |

