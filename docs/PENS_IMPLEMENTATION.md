# Add Custom Pens to Astradraw

## Overview

Add custom pen presets to Astradraw by extending the Excalidraw core with new appState fields and UI components. This feature is inspired by the Obsidian Excalidraw plugin's pen functionality.

## Technical Analysis

The `excalidraw/` fork is based on upstream Excalidraw. The Obsidian plugin uses `@zsviczian/excalidraw`, which contains **core modifications** not present in upstream.

### What @zsviczian/excalidraw adds for pens

1. **New AppState fields** (not in upstream):
   - `currentStrokeOptions: PenOptions | null` - active pen stroke settings
   - `resetCustomPen: {...} | null` - saved state to restore after pen use
   - `customPens: PenStyle[]` - array of configured pen presets

2. **Modified freedraw rendering** - `getFreedrawOutlinePoints()` in upstream uses hardcoded values:

```typescript
// Current upstream (excalidraw/packages/element/src/renderElement.ts:1111-1119)
const options: StrokeOptions = {
  simulatePressure: element.simulatePressure,
  size: element.strokeWidth * 4.25,
  thinning: 0.6,        // HARDCODED
  smoothing: 0.5,       // HARDCODED
  streamline: 0.5,      // HARDCODED
  easing: (t) => Math.sin((t * Math.PI) / 2),
  last: true,
};
```

3. **Pen presets** defined in plugin at `obsidian-excalidraw-plugin/src/utils/pens.ts`:
   - `default`, `highlighter`, `finetip`, `fountain`, `marker`, `thick-thin`, `thin-thick-thin`
   - Each has: `thinning`, `smoothing`, `streamline`, `easing`, `start/end taper`, `cap`, `highlighter` flag, `constantPressure`, `hasOutline`, `outlineWidth`

---

## Implementation Plan

### Step 1: Extend AppState

**Files:**
- `excalidraw/packages/excalidraw/types.ts`
- `excalidraw/packages/excalidraw/appState.ts`

**Add to `AppState` interface:**

```typescript
currentStrokeOptions: StrokeOptionsOverride | null;
resetCustomPen: {
  currentItemStrokeWidth: number;
  currentItemBackgroundColor: string;
  currentItemStrokeColor: string;
  currentItemFillStyle: string;
  currentItemRoughness: number;
} | null;
customPens: PenStyle[];
```

### Step 2: Modify Freedraw Rendering

**File:** `excalidraw/packages/element/src/renderElement.ts`

Update `getFreedrawOutlinePoints()` to read from `appState.currentStrokeOptions` when available, falling back to hardcoded defaults.

### Step 3: Add Pen Types and Presets

**Create:** `excalidraw/excalidraw-app/pens/`

- `penTypes.ts` - TypeScript interfaces
- `pens.ts` - preset definitions (copy from plugin)
- `PenToolbar.tsx` - UI component for pen selection

### Step 4: Add Vertical Pen Toolbar UI

**Approach:** Create a vertical icon panel on the right side (like Obsidian plugin)

```
┌──────────────────────────────────┬──┐
│                                  │🖊│ ← Pen presets
│           Canvas                 │🖍│
│                                  │✒│
│                                  │🖌│
│                                  │──│
│                                  │📚│ ← Sidebar trigger
└──────────────────────────────────┴──┘
```

**Implementation:**

1. Create `excalidraw-app/components/PenToolbar.tsx` - vertical panel component
2. Enable `FixedSideContainer side="right"` CSS (currently commented out in `FixedSideContainer.scss`)
3. Add to `LayerUI.tsx` or as child of `<Excalidraw>` in `App.tsx`
4. Wire pen selection to `updateScene({ appState: { currentStrokeOptions } })`

---

## Files to Modify

| File | Change |
|------|--------|
| `excalidraw/packages/excalidraw/types.ts` | Add 3 new AppState fields |
| `excalidraw/packages/excalidraw/appState.ts` | Add defaults for new fields |
| `excalidraw/packages/element/src/renderElement.ts` | Make `getFreedrawOutlinePoints` use appState |
| `excalidraw/packages/excalidraw/components/FixedSideContainer.scss` | Uncomment `side_right` CSS |
| `excalidraw/excalidraw-app/App.tsx` | Add pen toolbar, wire state |
| `excalidraw/excalidraw-app/pens/*` (new) | Pen presets and UI |

---

## Pen Presets Reference

From `obsidian-excalidraw-plugin/src/utils/pens.ts`:

| Pen Type | Description |
|----------|-------------|
| `default` | Standard Excalidraw freedraw |
| `highlighter` | Transparent, constant pressure, yellow |
| `finetip` | Thin, constant pressure, tapered ends |
| `fountain` | Variable pressure, long start taper |
| `marker` | With outline, rough style |
| `thick-thin` | Mindmap style, thick to thin |
| `thin-thick-thin` | Mindmap style, tapered both ends |

---

## Presentation/Frames

`frameRendering` already exists in upstream AppState (line 104 in `appState.ts`, line 304 in `types.ts`). Frame support is already available - no core changes needed for basic presentation mode.

---

## TODO

- [ ] Extend AppState with pen fields
- [ ] Modify getFreedrawOutlinePoints to use currentStrokeOptions
- [ ] Create pen presets data and types
- [ ] Add pen selector toolbar component
- [ ] Test pens with collaboration and exports
