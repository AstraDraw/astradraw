# Custom Pens Implementation

This document describes the implementation of custom pen presets in Astradraw, inspired by the [Obsidian Excalidraw Plugin](https://github.com/zsviczian/obsidian-excalidraw-plugin).

## Overview

Custom pens allow users to draw with different stroke characteristics (e.g., highlighter, fountain pen, marker) by modifying the parameters passed to the `perfect-freehand` library which renders freedraw strokes.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│   PenToolbar    │────▶│    AppState      │────▶│ FreeDrawElement     │
│   (UI Component)│     │ currentStroke-   │     │ customStrokeOptions │
│                 │     │ Options          │     │                     │
└─────────────────┘     └──────────────────┘     └──────────┬──────────┘
                                                            │
                                                            ▼
                                               ┌─────────────────────────┐
                                               │ getFreedrawOutlinePoints│
                                               │ (renderElement.ts)      │
                                               │                         │
                                               │ Uses customStrokeOptions│
                                               │ to configure            │
                                               │ perfect-freehand        │
                                               └─────────────────────────┘
```

## Files Modified/Created

### 1. Type Definitions

**`packages/excalidraw/types.ts`** - Added pen-related types to AppState:

```typescript
// Custom Pen Types
export interface PenStrokeOptions {
  thinning: number; // -1 to 1, affects stroke thinning based on pressure
  smoothing: number; // 0 to 1, smooths the stroke path
  streamline: number; // 0 to 1, reduces jitter in strokes
  easing: string; // easing function name (e.g., "easeOutSine", "linear")
  simulatePressure?: boolean;
  start: {
    cap: boolean; // round cap at start
    taper: number | boolean; // taper length or true for auto
    easing: string;
  };
  end: {
    cap: boolean;
    taper: number | boolean;
    easing: string;
  };
}

export interface PenOptions {
  highlighter: boolean; // true = semi-transparent fill mode
  constantPressure: boolean; // true = ignore pressure variation
  hasOutline: boolean; // future: add outline around stroke
  outlineWidth: number; // future: outline thickness
  options: PenStrokeOptions;
}

export type PenType =
  | "default"
  | "highlighter"
  | "finetip"
  | "fountain"
  | "marker"
  | "thick-thin"
  | "thin-thick-thin";

export interface PenStyle {
  type: PenType;
  freedrawOnly: boolean; // if true, saves/restores other tool settings
  strokeColor: string;
  backgroundColor: string;
  fillStyle: string;
  strokeWidth: number;
  roughness: number | null;
  penOptions: PenOptions;
}

// State to restore after using a freedrawOnly pen
export interface ResetCustomPenState {
  currentItemStrokeWidth: number;
  currentItemBackgroundColor: string;
  currentItemStrokeColor: string;
  currentItemFillStyle: string;
  currentItemRoughness: number;
}

// Added to AppState interface:
export interface AppState {
  // ... existing fields
  currentStrokeOptions: PenOptions | null; // Active pen configuration
  resetCustomPen: ResetCustomPenState | null; // Saved state to restore
  customPens: PenStyle[]; // Available pen presets
}
```

**`packages/element/src/types.ts`** - Extended FreeDrawElement:

```typescript
export interface FreeDrawStrokeOptions {
  thinning: number;
  smoothing: number;
  streamline: number;
  easing: string;
  start?: {
    cap: boolean;
    taper: number | boolean;
    easing: string;
  };
  end?: {
    cap: boolean;
    taper: number | boolean;
    easing: string;
  };
}

export type ExcalidrawFreeDrawElement = _ExcalidrawElementBase &
  Readonly<{
    type: "freedraw";
    points: readonly LocalPoint[];
    pressures: readonly number[];
    simulatePressure: boolean;
    customStrokeOptions?: FreeDrawStrokeOptions; // NEW: attached to each stroke
  }>;
```

### 2. Default State

**`packages/excalidraw/appState.ts`**:

```typescript
export const getDefaultAppState = () => {
  return {
    // ... existing defaults
    currentStrokeOptions: null, // No custom pen active by default
    resetCustomPen: null,
    customPens: [], // Populated by App.tsx on init
  };
};

// Storage configuration
APP_STATE_STORAGE_CONF = {
  currentStrokeOptions: { browser: true, export: false, server: false },
  resetCustomPen: { browser: false, export: false, server: false },
  customPens: { browser: true, export: false, server: false },
};
```

### 3. Rendering Logic

**`packages/element/src/renderElement.ts`** - Modified `getFreedrawOutlinePoints()`:

```typescript
// Easing functions map for perfect-freehand
const EASING_FUNCTIONS: Record<string, (t: number) => number> = {
  linear: (t) => t,
  easeOutSine: (t) => Math.sin((t * Math.PI) / 2),
  easeInSine: (t) => 1 - Math.cos((t * Math.PI) / 2),
  easeInOutSine: (t) => (1 - Math.cos(t * Math.PI)) / 2,
  easeInQuad: (t) => t * t,
  easeOutQuad: (t) => t * (2 - t),
  easeInOutQuad: (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2),
  easeInCubic: (t) => t * t * t,
  easeOutCubic: (t) => 1 - Math.pow(1 - t, 3),
  easeInOutCubic: (t) =>
    t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2,
  // ... more easing functions
};

export function getFreedrawOutlinePoints(element: ExcalidrawFreeDrawElement) {
  const inputPoints = element.simulatePressure
    ? element.points
    : element.points.length
    ? element.points.map(([x, y], i) => [x, y, element.pressures[i]])
    : [[0, 0, 0.5]];

  // KEY: Read custom options from the element itself
  const customOpts = element.customStrokeOptions;

  const options: StrokeOptions = {
    simulatePressure: element.simulatePressure,
    size: element.strokeWidth * 4.25,
    // Use custom values if present, otherwise use Excalidraw defaults
    thinning: customOpts?.thinning ?? 0.6,
    smoothing: customOpts?.smoothing ?? 0.5,
    streamline: customOpts?.streamline ?? 0.5,
    easing: customOpts?.easing
      ? getEasingFunction(customOpts.easing)
      : (t) => Math.sin((t * Math.PI) / 2),
    last: true,
    // Apply start/end taper settings if present
    ...(customOpts?.start && {
      start: {
        cap: customOpts.start.cap,
        taper: customOpts.start.taper,
        easing: getEasingFunction(customOpts.start.easing),
      },
    }),
    ...(customOpts?.end && {
      end: {
        cap: customOpts.end.cap,
        taper: customOpts.end.taper,
        easing: getEasingFunction(customOpts.end.easing),
      },
    }),
  };

  return getStroke(inputPoints, options);
}
```

### 4. Pen Presets

**`excalidraw-app/pens/pens.ts`** - Pen preset definitions:

```typescript
export const PENS: Record<PenType, PenStyle> = {
  default: {
    type: "default",
    freedrawOnly: false,
    penOptions: {
      options: {
        thinning: 0.6,
        smoothing: 0.5,
        streamline: 0.5,
        easing: "easeOutSine",
        start: { cap: true, taper: 0, easing: "linear" },
        end: { cap: true, taper: 0, easing: "linear" },
      },
    },
  },
  highlighter: {
    type: "highlighter",
    freedrawOnly: true, // Will save/restore other settings
    strokeColor: "#FFC47C",
    fillStyle: "solid",
    penOptions: {
      highlighter: true,
      constantPressure: true,
      options: {
        thinning: 1,
        smoothing: 0.5,
        streamline: 0.5,
        easing: "linear",
        // No taper = flat ends like a real highlighter
      },
    },
  },
  fountain: {
    type: "fountain",
    freedrawOnly: false,
    penOptions: {
      options: {
        thinning: 0.6,
        smoothing: 0.2,
        streamline: 0.2,
        easing: "easeInOutSine",
        start: { taper: 150, cap: true, easing: "linear" }, // Long entry taper
        end: { taper: 1, cap: true, easing: "linear" },
      },
    },
  },
  // ... more presets (finetip, marker, thick-thin, thin-thick-thin)
};
```

### 5. UI Component

**`excalidraw-app/pens/PenToolbar.tsx`**:

```typescript
export const PenToolbar: React.FC<PenToolbarProps> = ({ excalidrawAPI }) => {
  const appState = excalidrawAPI.getAppState();
  const currentStrokeOptions = appState.currentStrokeOptions;
  const isSidebarOpen = !!appState.openSidebar;

  const setPen = useCallback(
    (pen: PenStyle) => {
      const st = excalidrawAPI.getAppState();

      // Save current settings if switching to freedrawOnly pen
      const resetCustomPen =
        pen.freedrawOnly && !st.resetCustomPen
          ? {
              currentItemStrokeWidth: st.currentItemStrokeWidth,
              currentItemBackgroundColor: st.currentItemBackgroundColor,
              currentItemStrokeColor: st.currentItemStrokeColor,
              currentItemFillStyle: st.currentItemFillStyle,
              currentItemRoughness: st.currentItemRoughness,
            }
          : null;

      // Update appState with new pen settings
      excalidrawAPI.updateScene({
        appState: {
          currentStrokeOptions: pen.penOptions,
          currentItemStrokeWidth: pen.strokeWidth,
          currentItemStrokeColor: pen.strokeColor,
          // ... other pen properties
          resetCustomPen,
        },
      });

      // Switch to freedraw tool
      excalidrawAPI.setActiveTool({ type: "freedraw" });
    },
    [excalidrawAPI],
  );

  const resetToDefault = useCallback(() => {
    const st = excalidrawAPI.getAppState();
    // Restore saved settings
    excalidrawAPI.updateScene({
      appState: {
        currentStrokeOptions: null,
        ...(st.resetCustomPen && { ...st.resetCustomPen }),
        resetCustomPen: null,
      },
    });
  }, [excalidrawAPI]);

  // Toolbar shifts left when sidebar is open
  return (
    <div
      className="pen-toolbar"
      style={{ right: isSidebarOpen ? "var(--right-sidebar-width, 302px)" : 0 }}
    >
      {/* Pen buttons */}
    </div>
  );
};
```

### 6. App Integration

**`excalidraw-app/App.tsx`**:

```typescript
import { PenToolbar, getDefaultPenPresets } from "./pens";

// In initializeScene:
const defaultPenPresets = getDefaultPenPresets();
appState.customPens = defaultPenPresets;

// In render:
<Excalidraw>
  <AppSidebar />
  {excalidrawAPI && <PenToolbar excalidrawAPI={excalidrawAPI} />}
</Excalidraw>;
```

## Data Flow

1. **User clicks pen button** → `setPen()` in PenToolbar
2. **Updates AppState** → `currentStrokeOptions` set to pen's options
3. **User draws** → New freedraw element created
4. **Element stores options** → `customStrokeOptions` copied from `currentStrokeOptions`
5. **Rendering** → `getFreedrawOutlinePoints()` reads `element.customStrokeOptions`
6. **perfect-freehand** → Uses custom thinning/smoothing/taper values

## Adding New Pen Types

1. Add type to `PenType` union in `types.ts`
2. Add preset definition to `PENS` object in `pens.ts`
3. Add icon case to `PenIcon` component in `PenToolbar.tsx`

## Future Improvements (from Obsidian Plugin)

- **Highlighter mode**: Semi-transparent fill with `globalCompositeOperation`
- **Outline strokes**: Double-stroke rendering for outlined pens
- **Pressure curves**: Custom pressure-to-width mapping
- **Pen customization UI**: User-editable pen presets
- **Keyboard shortcuts**: Quick pen switching

## Key Differences from Obsidian Plugin

The Obsidian Excalidraw plugin uses a heavily modified fork (`@zsviczian/excalidraw`) with deeper integration. This implementation:

1. Stores stroke options on each element (not just in appState)
2. Uses standard Excalidraw APIs where possible
3. Renders in the main Excalidraw component tree
4. Designed for web-first (not Electron/Obsidian)

## Bug Fixes

### Pen Toolbar Hidden Behind Sidebar (v0.18.0-beta0.2)

**Problem**: When the sidebar was opened, the pen toolbar was hidden behind it instead of shifting to the left.

**Root Causes**:

1. **Missing CSS variable**: `--right-sidebar-width` was referenced but never defined
2. **Insufficient z-index**: Pen toolbar had `z-index: 100` while sidebar had `z-index: 120`
3. **Non-reactive state**: `PenToolbar` used `excalidrawAPI.getAppState()` which doesn't trigger re-renders when sidebar state changes

**Solution**:

1. **Added `--right-sidebar-width` CSS variable** in `packages/excalidraw/css/styles.scss`:

```scss
:root {
  // ... other variables
  --right-sidebar-width: 360px;
}
```

2. **Fixed z-index** in `excalidraw-app/pens/PenToolbar.scss`:

```scss
.pen-toolbar {
  z-index: calc(var(--zIndex-ui-library, 120) + 1); // Above sidebar

  &--sidebar-open {
    right: var(--right-sidebar-width, 360px);
    border-radius: 8px;
  }
}
```

3. **Used reactive hook** in `excalidraw-app/pens/PenToolbar.tsx`:

```typescript
import { useUIAppState } from "@excalidraw/excalidraw/context/ui-appState";

export const PenToolbar: React.FC<PenToolbarProps> = ({ excalidrawAPI }) => {
  // Use reactive UI state for sidebar detection
  const uiAppState = useUIAppState();
  const isSidebarOpen = !!uiAppState.openSidebar;

  return (
    <div
      className={clsx("pen-toolbar", {
        "pen-toolbar--sidebar-open": isSidebarOpen,
      })}
    >
      {/* ... */}
    </div>
  );
};
```

**Key Insight**: The `useUIAppState()` hook provides reactive state updates from Excalidraw's context, ensuring the component re-renders when `openSidebar` changes. The previous approach using `excalidrawAPI.getAppState()` only captured state at render time.

## References

- [perfect-freehand options](https://github.com/steveruizok/perfect-freehand#options)
- [Obsidian Excalidraw pens.ts](https://github.com/zsviczian/obsidian-excalidraw-plugin/blob/master/src/utils/pens.ts)
- [Easing functions](https://easings.net/)
