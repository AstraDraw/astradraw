# Custom Pens Implementation

This document describes the implementation of custom pen presets in AstraDraw, based on the [Obsidian Excalidraw Plugin](https://github.com/zsviczian/obsidian-excalidraw-plugin) and its [zsviczian/excalidraw fork](https://github.com/zsviczian/excalidraw).

## Overview

Custom pens allow users to draw with different stroke characteristics (e.g., highlighter, fountain pen, marker) by modifying the parameters passed to the `perfect-freehand` library which renders freedraw strokes.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│   PenToolbar    │────▶│    AppState      │────▶│ FreeDrawElement     │
│   (UI Component)│     │ currentStroke-   │     │ customData: {       │
│                 │     │ Options          │     │   strokeOptions     │
└─────────────────┘     └──────────────────┘     │ }                   │
                                                 └──────────┬──────────┘
                                                            │
                                                            ▼
                                               ┌─────────────────────────┐
                                               │ getFreedrawOutlinePoints│
                                               │ (renderElement.ts)      │
                                               │                         │
                                               │ Reads customData.       │
                                               │ strokeOptions.options   │
                                               │ for perfect-freehand    │
                                               └─────────────────────────┘
```

## Key Files

| File | Purpose |
|------|---------|
| `packages/excalidraw/types.ts` | Type definitions for pens |
| `packages/excalidraw/appState.ts` | Default state and storage config |
| `packages/element/src/easingFunctions.ts` | Easing functions for stroke tapering |
| `packages/element/src/renderElement.ts` | Rendering with custom pen options |
| `packages/excalidraw/components/App.tsx` | Stores strokeOptions in element customData |
| `excalidraw-app/pens/pens.ts` | Pen preset definitions |
| `excalidraw-app/pens/PenToolbar/PenToolbar.tsx` | UI component |
| `excalidraw-app/pens/PenSettingsModal/PenSettingsModal.tsx` | Pen customization modal |

## Type Definitions

**`packages/excalidraw/types.ts`**:

```typescript
// Perfect Freehand stroke options
export interface PenStrokeOptions {
  thinning: number;        // -1 to 1, affects stroke thinning based on pressure
  smoothing: number;       // 0 to 1, smooths the stroke path
  streamline: number;      // 0 to 1, reduces jitter in strokes
  easing: string;          // easing function name (e.g., "easeOutSine", "linear")
  simulatePressure?: "yes" | "no" | "yes for mouse, no for pen";
  start: {
    cap: boolean;          // round cap at start
    taper: number | boolean; // taper length or true for auto
    easing: string;
  };
  end: {
    cap: boolean;
    taper: number | boolean;
    easing: string;
  };
}

// Full pen options (stored in element.customData.strokeOptions)
export interface PenOptions {
  highlighter: boolean;     // true = semi-transparent fill mode (future)
  constantPressure: boolean; // true = ignore pressure variation, use uniform width
  hasOutline: boolean;      // true = draw outline around stroke
  outlineWidth: number;     // outline thickness multiplier
  options: PenStrokeOptions; // perfect-freehand parameters
}

// Pen preset type identifiers
export type PenType =
  | "default"
  | "highlighter"
  | "finetip"
  | "fountain"
  | "marker"
  | "thick-thin"
  | "thin-thick-thin";

// Complete pen style definition
export interface PenStyle {
  type: PenType;
  freedrawOnly: boolean;    // if true, saves/restores other tool settings
  strokeColor: string;      // pen stroke color (empty = use canvas current)
  backgroundColor: string;  // pen fill color (for outline pens)
  fillStyle: string;        // fill style (empty = use canvas current)
  strokeWidth: number;      // 0 = use canvas current stroke width
  roughness: number | null; // null = use canvas current
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
  currentStrokeOptions: PenOptions | null;  // Active pen configuration
  currentPenType: PenType | null;           // Active pen type
  resetCustomPen: ResetCustomPenState | null; // Saved state to restore
  customPens: PenStyle[];                   // User's pen presets
}
```

## Data Flow

### 1. User Selects Pen

When a user clicks a pen button in `PenToolbar`:

```typescript
const setPen = useCallback((pen: PenStyle) => {
  const st = excalidrawAPI.getAppState();

  // Save current settings if switching to freedrawOnly pen
  const resetCustomPen = pen.freedrawOnly && !st.resetCustomPen
    ? {
        currentItemStrokeWidth: st.currentItemStrokeWidth,
        currentItemBackgroundColor: st.currentItemBackgroundColor,
        currentItemStrokeColor: st.currentItemStrokeColor,
        currentItemFillStyle: st.currentItemFillStyle,
        currentItemRoughness: st.currentItemRoughness,
      }
    : null;

  const appStateUpdate = {
    currentStrokeOptions: pen.penOptions,
    currentPenType: pen.type,
  };

  // Apply pen properties following Obsidian Excalidraw plugin patterns:
  // - strokeWidth: 0 means "keep current canvas width" (don't override)
  // - backgroundColor/strokeColor: only apply if truthy
  // - fillStyle: empty string means "keep current" (don't override)
  // - roughness: null means "keep current" (don't override)
  if (pen.strokeWidth && pen.strokeWidth > 0) {
    appStateUpdate.currentItemStrokeWidth = pen.strokeWidth;
  }
  if (pen.backgroundColor) {
    appStateUpdate.currentItemBackgroundColor = pen.backgroundColor;
  }
  if (pen.strokeColor) {
    appStateUpdate.currentItemStrokeColor = pen.strokeColor;
  }
  // ... etc

  excalidrawAPI.updateScene({ appState: appStateUpdate });
  excalidrawAPI.setActiveTool({ type: "freedraw" });
}, [excalidrawAPI]);
```

### 2. User Draws (Element Creation)

In `App.tsx` `handlePointerDown`, when creating a freedraw element:

```typescript
// Custom pen stroke options (AstraDraw)
const strokeOptions = this.state.currentStrokeOptions;

// constantPressure means ignore hardware pressure - use uniform width
const simulatePressure = strokeOptions?.constantPressure
  ? false
  : event.pressure === 0.5;

const element = newFreeDrawElement({
  type: elementType,
  x: gridX,
  y: gridY,
  strokeColor: this.state.currentItemStrokeColor,
  backgroundColor: this.state.currentItemBackgroundColor,
  strokeWidth: this.state.currentItemStrokeWidth,
  // ... other properties
  simulatePressure,
  // Store custom pen options in customData (AstraDraw)
  ...(strokeOptions ? { customData: { strokeOptions } } : {}),
  pressures: simulatePressure
    ? []
    : [strokeOptions?.constantPressure ? 1 : event.pressure],
});
```

### 3. Rendering

In `renderElement.ts`, `getFreedrawOutlinePoints()` reads the custom options:

```typescript
import easingsFunctions from "./easingFunctions";

export function getFreedrawOutlinePoints(element: ExcalidrawFreeDrawElement) {
  const inputPoints = element.simulatePressure
    ? element.points
    : element.points.length
    ? element.points.map(([x, y], i) => [x, y, element.pressures[i]])
    : [[0, 0, 0.5]];

  // Read custom stroke options from customData (AstraDraw pen system)
  const customOptions = element.customData?.strokeOptions?.options;

  // Use custom stroke options if available, otherwise use defaults
  const options: StrokeOptions = customOptions
    ? {
        ...customOptions,
        simulatePressure: customOptions.simulatePressure ?? element.simulatePressure,
        size: element.strokeWidth * 4.25, // Override size with stroke width
        last: true,
        easing: easingsFunctions[customOptions.easing] ?? ((t) => t),
        // Handle start/end easing functions
        ...(customOptions.start?.easing && {
          start: {
            ...customOptions.start,
            easing: easingsFunctions[customOptions.start.easing] ?? ((t) => t),
          },
        }),
        ...(customOptions.end?.easing && {
          end: {
            ...customOptions.end,
            easing: easingsFunctions[customOptions.end.easing] ?? ((t) => t),
          },
        }),
      }
    : {
        // Default Excalidraw values
        simulatePressure: element.simulatePressure,
        size: element.strokeWidth * 4.25,
        thinning: 0.6,
        smoothing: 0.5,
        streamline: 0.5,
        easing: easingsFunctions.easeOutSine,
        last: true,
      };

  return getStroke(inputPoints, options);
}
```

### 4. Outline Rendering

For pens with `hasOutline: true`, in `drawElementOnCanvas`:

```typescript
case "freedraw": {
  context.save();
  const path = getFreeDrawPath2D(element) as Path2D;
  const fillShape = ShapeCache.get(element);

  if (fillShape) {
    rc.draw(fillShape);
  }

  // AstraDraw: Check for outline stroke options in customData
  const strokeOptions = element.customData?.strokeOptions;
  if (strokeOptions?.hasOutline) {
    // Draw outline first: strokeColor is outline, backgroundColor is fill
    context.lineWidth = element.strokeWidth * (strokeOptions.outlineWidth ?? 1);
    context.strokeStyle = element.strokeColor;
    context.lineCap = "round";
    context.lineJoin = "round";
    context.stroke(path);
    context.fillStyle = element.backgroundColor;
  } else {
    context.fillStyle = element.strokeColor;
  }
  context.fill(path);

  context.restore();
  break;
}
```

## Easing Functions

**`packages/element/src/easingFunctions.ts`**:

```typescript
type EasingFunction = (t: number) => number;

interface EasingDictionary {
  [key: string]: EasingFunction;
}

const easingsFunctions: EasingDictionary = {
  linear: (x) => x,
  easeInQuad(x) { return x * x; },
  easeOutQuad(x) { return 1 - (1 - x) * (1 - x); },
  easeInOutQuad(x) {
    return x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2;
  },
  easeInCubic(x) { return x * x * x; },
  easeOutCubic(x) { return 1 - Math.pow(1 - x, 3); },
  easeInOutCubic(x) {
    return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
  },
  easeInSine(x) { return 1 - Math.cos((x * Math.PI) / 2); },
  easeOutSine(x) { return Math.sin((x * Math.PI) / 2); },
  easeInOutSine(x) { return -(Math.cos(Math.PI * x) - 1) / 2; },
  // ... more easing functions (expo, circ, back, elastic, bounce)
};

export default easingsFunctions;
```

## Pen Presets

**`excalidraw-app/pens/pens.ts`**:

```typescript
export const PENS: Record<PenType, PenStyle> = {
  default: {
    type: "default",
    freedrawOnly: false,
    strokeColor: "#000000",
    backgroundColor: "transparent",
    fillStyle: "hachure",
    strokeWidth: 0,  // 0 = use canvas current
    roughness: 0,
    penOptions: {
      highlighter: false,
      constantPressure: false,
      hasOutline: false,
      outlineWidth: 1,
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
    freedrawOnly: true,
    strokeColor: "#FFC47C",
    backgroundColor: "#FFC47C",
    fillStyle: "solid",
    strokeWidth: 2,
    roughness: null,
    penOptions: {
      highlighter: true,
      constantPressure: true,
      hasOutline: true,
      outlineWidth: 4,
      options: {
        thinning: 1,
        smoothing: 0.5,
        streamline: 0.5,
        easing: "linear",
        start: { taper: 0, cap: true, easing: "linear" },
        end: { taper: 0, cap: true, easing: "linear" },
      },
    },
  },
  finetip: {
    type: "finetip",
    freedrawOnly: false,
    strokeColor: "#3E6F8D",
    backgroundColor: "transparent",
    fillStyle: "hachure",
    strokeWidth: 0.5,
    roughness: 0,
    penOptions: {
      highlighter: false,
      hasOutline: false,
      outlineWidth: 1,
      constantPressure: true,
      options: {
        smoothing: 0.4,
        thinning: -0.5,  // Negative = thicker with pressure
        streamline: 0.4,
        easing: "linear",
        start: { taper: 5, cap: false, easing: "linear" },
        end: { taper: 5, cap: false, easing: "linear" },
      },
    },
  },
  fountain: {
    type: "fountain",
    freedrawOnly: false,
    strokeColor: "#000000",
    backgroundColor: "transparent",
    fillStyle: "hachure",
    strokeWidth: 2,
    roughness: 0,
    penOptions: {
      highlighter: false,
      constantPressure: false,
      hasOutline: false,
      outlineWidth: 1,
      options: {
        smoothing: 0.2,
        thinning: 0.6,
        streamline: 0.2,
        easing: "easeInOutSine",
        start: { taper: 150, cap: true, easing: "linear" },  // Long entry taper
        end: { taper: 1, cap: true, easing: "linear" },
      },
    },
  },
  marker: {
    type: "marker",
    freedrawOnly: true,
    strokeColor: "#B83E3E",
    backgroundColor: "#FF7C7C",
    fillStyle: "dashed",
    strokeWidth: 2,
    roughness: 3,
    penOptions: {
      highlighter: false,
      constantPressure: true,
      hasOutline: true,
      outlineWidth: 4,
      options: {
        thinning: 1,
        smoothing: 0.5,
        streamline: 0.5,
        easing: "linear",
        start: { taper: 0, cap: true, easing: "linear" },
        end: { taper: 0, cap: true, easing: "linear" },
      },
    },
  },
  "thick-thin": {
    type: "thick-thin",
    freedrawOnly: true,
    strokeColor: "#CECDCC",
    backgroundColor: "transparent",
    fillStyle: "hachure",
    strokeWidth: 0,
    roughness: null,
    penOptions: {
      highlighter: true,
      constantPressure: true,
      hasOutline: false,
      outlineWidth: 1,
      options: {
        thinning: 1,
        smoothing: 0.5,
        streamline: 0.5,
        easing: "linear",
        start: { taper: 0, cap: true, easing: "linear" },
        end: { cap: true, taper: true, easing: "linear" },  // Auto taper at end
      },
    },
  },
  "thin-thick-thin": {
    type: "thin-thick-thin",
    freedrawOnly: true,
    strokeColor: "#CECDCC",
    backgroundColor: "transparent",
    fillStyle: "hachure",
    strokeWidth: 0,
    roughness: null,
    penOptions: {
      highlighter: true,
      constantPressure: true,
      hasOutline: false,
      outlineWidth: 1,
      options: {
        thinning: 1,
        smoothing: 0.5,
        streamline: 0.5,
        easing: "linear",
        start: { cap: true, taper: true, easing: "linear" },  // Auto taper both ends
        end: { cap: true, taper: true, easing: "linear" },
      },
    },
  },
};
```

## Adding New Pen Types

1. Add type to `PenType` union in `packages/excalidraw/types.ts`
2. Add preset definition to `PENS` object in `excalidraw-app/pens/pens.ts`
3. Add icon case to `PenIcon` component in `PenToolbar.tsx`

## Pen Settings Modal

Users can customize pen settings via the `PenSettingsModal` component, which allows editing:

- Pen type selection
- Stroke & fill applies to: All shapes / Freedraw only
- Stroke color (current or preset)
- Background color (current, preset, or transparent)
- Sloppiness (roughness)
- Stroke width
- Highlighter mode
- Pressure sensitivity / constant pressure
- Outline stroke
- Perfect Freehand settings:
  - Thinning (-1 to 1)
  - Smoothing (0 to 1)
  - Streamline (0 to 1)
  - Easing function
  - Simulate pressure mode
  - Start/End tapering options

## Implemented Features

- ✅ **Custom pen presets**: 7 built-in pen types
- ✅ **Perfect Freehand integration**: Full control over stroke parameters
- ✅ **Outline strokes**: Double-stroke rendering for outlined pens
- ✅ **Constant pressure**: Uniform stroke width ignoring stylus pressure
- ✅ **freedrawOnly mode**: Saves/restores other tool settings
- ✅ **Pen settings modal**: User-editable pen presets
- ✅ **Easing functions**: Full set of easing functions for tapering
- ✅ **Highlighter rendering order**: Pens with `highlighter: true` are drawn behind other elements, both during drawing and after completion

## Future Improvements

- **Pressure curves**: Custom pressure-to-width mapping
- **Keyboard shortcuts**: Quick pen switching (1-7 keys)
- **Pen import/export**: Share pen presets

## Bug Fixes

### Pen Toolbar Hidden Behind Sidebar (v0.18.0-beta0.2)

**Problem**: When the sidebar was opened, the pen toolbar was hidden behind it.

**Solution**: Used `useUIAppState()` hook for reactive state updates and proper z-index.

```typescript
import { useUIAppState } from "@excalidraw/excalidraw/context/ui-appState";

export const PenToolbar: React.FC<PenToolbarProps> = ({ excalidrawAPI }) => {
  const uiAppState = useUIAppState();
  const isSidebarOpen = !!uiAppState.openSidebar;
  // ...
};
```

### strokeWidth: 0 Not Working

**Problem**: Pens with `strokeWidth: 0` were setting element stroke width to 0, making strokes invisible.

**Solution**: Changed conditional check to treat `strokeWidth: 0` as "keep current canvas width":

```typescript
// Before (wrong)
if (pen.strokeWidth !== undefined) {
  appStateUpdate.currentItemStrokeWidth = pen.strokeWidth;
}

// After (correct - matches Obsidian plugin)
if (pen.strokeWidth && pen.strokeWidth > 0) {
  appStateUpdate.currentItemStrokeWidth = pen.strokeWidth;
}
```

## References

- [perfect-freehand options](https://github.com/steveruizok/perfect-freehand#options)
- [Obsidian Excalidraw Plugin](https://github.com/zsviczian/obsidian-excalidraw-plugin)
- [zsviczian/excalidraw fork](https://github.com/zsviczian/excalidraw)
- [Easing functions](https://easings.net/)
