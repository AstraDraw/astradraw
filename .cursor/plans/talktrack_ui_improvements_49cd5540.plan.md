---
name: Talktrack UI Improvements
overview: "Improve Talktrack recording UX: move controls to left, default camera position to top-right, and fix laser pointer capture by compositing both canvas layers."
todos:
  - id: move-controls-left
    content: Move recording controls from center to left side
    status: completed
  - id: camera-position-topright
    content: Set default camera bubble position to top-right
    status: completed
  - id: find-both-canvases
    content: Update findExcalidrawCanvas to return both static and interactive canvases
    status: completed
  - id: composite-canvases
    content: Update drawFrame to composite both canvas layers
    status: completed
  - id: test-laser-capture
    content: Test that laser pointer is captured in recordings
    status: completed
---

# Talktrack UI &

Laser Capture Improvements

## Overview

Fix 3 UX issues based on user feedback:

1. Move recording controls to left side
2. Position camera bubble at top-right by default
3. Capture laser pointer by compositing interactive canvas layer

## Changes Required

### 1. Move Recording Controls to Left

**File**: [`excalidraw/excalidraw-app/components/Talktrack/TalktrackToolbar.scss`](excalidraw/excalidraw-app/components/Talktrack/TalktrackToolbar.scss)Change toolbar positioning from bottom-center to bottom-left:

```scss
.talktrack-toolbar {
  // FROM:
  left: 50%;
  transform: translateX(-50%);
  
  // TO:
  left: 20px;
  bottom: 20px;
}
```



### 2. Default Camera Position: Top-Right

**File**: [`excalidraw/excalidraw-app/components/Talktrack/TalktrackToolbar.tsx`](excalidraw/excalidraw-app/components/Talktrack/TalktrackToolbar.tsx)Change initial `bubblePosition` state:

```typescript
// Calculate top-right position on mount
const [bubblePosition, setBubblePosition] = useState(() => {
  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;
  return { 
    x: viewportWidth - 140, // 120px bubble + 20px margin
    y: 20 
  };
});
```



### 3. Fix Laser Pointer Capture

**Problem**: Only capturing `.static` canvas, but laser is on `.interactive` canvas**File**: [`excalidraw/excalidraw-app/components/Talktrack/TalktrackRecorder.ts`](excalidraw/excalidraw-app/components/Talktrack/TalktrackRecorder.ts)**Changes needed**:

#### A. Find both canvases (line ~162)

```typescript
private findExcalidrawCanvases(): { 
  static: HTMLCanvasElement | null; 
  interactive: HTMLCanvasElement | null;
} {
  const staticCanvas = document.querySelector(".excalidraw__canvas.static") as HTMLCanvasElement;
  const interactiveCanvas = document.querySelector(".excalidraw__canvas.interactive") as HTMLCanvasElement;
  
  return { static: staticCanvas, interactive: interactiveCanvas };
}
```



#### B. Update class properties (line ~97)

```typescript
private staticCanvas: HTMLCanvasElement | null = null;
private interactiveCanvas: HTMLCanvasElement | null = null;
```



#### C. Update drawFrame method (line ~229)

```typescript
private drawFrame = () => {
  if (!this.compositorCtx || !this.staticCanvas) return;
  
  const ctx = this.compositorCtx;
  const width = this.compositorCanvas!.width;
  const height = this.compositorCanvas!.height;
  
  ctx.clearRect(0, 0, width, height);
  
  // 1. Draw static canvas (main drawing)
  ctx.drawImage(this.staticCanvas, 0, 0, width, height);
  
  // 2. Draw interactive canvas (laser, selections) IF available
  if (this.interactiveCanvas) {
    ctx.drawImage(this.interactiveCanvas, 0, 0, width, height);
  }
  
  // 3. Draw camera PIP on top
  if (this.cameraVideo && this.options.videoDeviceId) {
    // ... existing PIP code
  }
};
```



#### D. Update startRecording (line ~337)

```typescript
const canvases = this.findExcalidrawCanvases();
this.staticCanvas = canvases.static;
this.interactiveCanvas = canvases.interactive;

if (!this.staticCanvas) {
  throw new Error("Could not find Excalidraw canvas");
}

// Set compositor size to match static canvas
if (this.compositorCanvas) {
  this.compositorCanvas.width = this.staticCanvas.width;
  this.compositorCanvas.height = this.staticCanvas.height;
}
```



## Files to Modify

| File | Changes ||------|---------|| `TalktrackToolbar.scss` | Change positioning: left side instead of center || `TalktrackToolbar.tsx` | Default camera position to top-right || `TalktrackRecorder.ts` | Find both canvases, composite in drawFrame |

## Testing

1. Start recording
2. Verify controls are on left side ✓
3. Verify camera bubble starts at top-right ✓
4. Use laser pointer during recording ✓
5. Stop and upload ✓
6. Play back video - laser should be visible ✓

## Technical Notes

- Compositing order matters: static → interactive → camera PIP