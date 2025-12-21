# Talktrack - Board Recording Feature

Record canvas walkthroughs with camera PIP and microphone, upload to Kinescope, and embed playback on the board.

## Overview

Talktrack is a Miro-style recording feature that allows you to create video walkthroughs of your Excalidraw boards. Recordings include:

- Canvas content capture via `canvas.captureStream()`
- Camera Picture-in-Picture (PIP) overlay in the bottom-right corner
- Microphone audio
- Automatic upload to Kinescope video hosting
- Embeddable player on the board
- **Scene-specific storage** - Recordings are linked to workspace scenes and stored in PostgreSQL

## Setup

### 1. Get Kinescope API Credentials

1. Create an account at [Kinescope](https://kinescope.io/)
2. Go to Settings → API in your dashboard
3. Create or copy your API key
4. Note your project ID from the URL: `https://app.kinescope.io/projects/{PROJECT_ID}`

### 2. Configure Environment Variables

Add the following to your `deploy/.env` file:

```bash
# Kinescope API Key for video upload and playback
KINESCOPE_API_KEY=your_kinescope_api_key_here

# Kinescope Project ID (parent folder for uploaded recordings)
KINESCOPE_PROJECT_ID=your_project_id_here
```

### 3. Rebuild and Start

```bash
cd deploy
docker compose up -d --build
```

## Usage

### Recording a Talktrack

1. Click the **Video** icon in the sidebar to open the Talktrack panel
2. Click **"Record a Talktrack"** button
3. In the setup dialog:
   - Preview your camera (optional)
   - Toggle camera on/off
   - Toggle microphone on/off
   - Select video and audio sources
4. Click **"Start recording"**
5. After a 3-2-1 countdown, recording begins
6. A floating toolbar appears in the top-right corner with:
   - **Delete** - Cancel and discard recording
   - **Restart** - Start over
   - **Pause/Resume** - Pause recording
   - **Timer** - Shows elapsed time
   - **STOP** - End recording and upload

### Managing Recordings

After recording stops, your video is automatically uploaded to Kinescope and saved to your scene. The recording appears in the Talktrack panel where you can:

- **Add to board** - Embed the video player on the canvas
- **Copy link** - Copy the embed URL to clipboard
- **Rename** - Change the recording title (owner only)
- **Delete** - Remove from the list and Kinescope (owner only)

> **Note:** Recordings are linked to the current scene. You must save your scene to the workspace before recording. Shared viewers can see recordings but cannot modify them.

### Playback

Click "Add to board" to embed the Kinescope player as an embeddable element on your canvas. The video can be moved, resized, and played directly on the board.

## Technical Details

### Components

All located in `frontend/excalidraw-app/components/Talktrack/`:

| File | Description |
|------|-------------|
| `TalktrackRecorder.ts` | Core recording logic with canvas capture, camera PIP compositing, and MediaRecorder |
| `TalktrackPanel.tsx` | Sidebar panel showing recordings list (scene-specific) |
| `TalktrackSetupDialog.tsx` | Camera/mic selection dialog before recording |
| `TalktrackToolbar.tsx` | Floating controls during recording |
| `TalktrackManager.tsx` | Orchestrates recording lifecycle and upload |
| `kinescopeApi.ts` | Kinescope upload helpers |

Backend API client: `frontend/excalidraw-app/auth/workspaceApi.ts`

### Backend API Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/workspace/scenes/:sceneId/talktracks` | GET | JWT | List recordings for a scene |
| `/workspace/scenes/:sceneId/talktracks` | POST | JWT | Create recording (owner only) |
| `/workspace/scenes/:sceneId/talktracks/:id` | PUT | JWT | Update title/status (owner only) |
| `/workspace/scenes/:sceneId/talktracks/:id` | DELETE | JWT | Delete recording (owner only) |

### Database Schema

```sql
CREATE TABLE "talktrack_recordings" (
    "id" TEXT PRIMARY KEY,
    "title" TEXT NOT NULL,
    "kinescopeVideoId" TEXT UNIQUE NOT NULL,
    "duration" INTEGER NOT NULL,
    "processingStatus" TEXT DEFAULT 'processing',
    "sceneId" TEXT NOT NULL REFERENCES scenes(id) ON DELETE CASCADE,
    "userId" TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP NOT NULL
);
```

### Recording Pipeline

```
┌─────────────────┐     ┌─────────────────┐
│  Static Canvas  │────▶│                 │
│ captureStream() │     │   Compositor    │
└─────────────────┘     │     Canvas      │
                        │  (PIP overlay)  │
┌─────────────────┐     │                 │
│  Camera Feed    │────▶│                 │
│  getUserMedia() │     └────────┬────────┘
└─────────────────┘              │
                                 ▼
                        ┌─────────────────┐
┌─────────────────┐     │                 │
│  Microphone     │────▶│  MediaRecorder  │───▶ webm blob
│  getUserMedia() │     │   (vp9/opus)    │
└─────────────────┘     └─────────────────┘
```

### Browser Requirements

- Chrome 60+, Firefox 60+, Safari 14.1+, Edge 79+
- Required APIs: `captureStream()`, `getUserMedia()`, `MediaRecorder`
- Permissions: Camera, Microphone (requested on first use)

### Video Format

- Container: WebM
- Video codec: VP9 (fallback to VP8)
- Audio codec: Opus
- Frame rate: 30 fps
- Bitrate: 2.5 Mbps

## Important Implementation Details

### Singleton Pattern & Component Lifecycle

The `TalktrackRecorder` uses a **singleton pattern** to maintain a single recorder instance across the app. This is important to understand when working with the dashboard/canvas mode switching:

```typescript
// TalktrackRecorder.ts
let recorderInstance: TalktrackRecorder | null = null;

export function getTalktrackRecorder(): TalktrackRecorder {
  if (!recorderInstance) {
    recorderInstance = new TalktrackRecorder();
  }
  return recorderInstance;
}

export function disposeTalktrackRecorder(): void {
  if (recorderInstance) {
    recorderInstance.dispose();
    recorderInstance = null;  // CRITICAL: Reset the singleton reference
  }
}
```

**Why this matters:** When switching between dashboard mode and canvas mode (e.g., switching collections), the `TalktrackManager` component unmounts. If `dispose()` is called without resetting the singleton reference, the next mount will return a broken instance with null DOM elements.

**Rule:** Always use `disposeTalktrackRecorder()` instead of calling `dispose()` directly on the instance.

### Workspace Sidebar & Canvas Size

The recording captures the Excalidraw canvas at its current size. If the **left workspace sidebar** is open when recording starts, the canvas is narrower, which causes **black bars** on the sides of the recorded video.

**Solution implemented:** When recording starts, the `TalktrackManager`:
1. Closes the workspace sidebar via `onCloseWorkspaceSidebar` callback
2. Waits 300ms for the sidebar animation to complete
3. Then captures the canvas dimensions for the compositor

```typescript
// TalktrackManager.tsx - startRecording()
onCloseWorkspaceSidebar?.();
await new Promise((resolve) => setTimeout(resolve, 300));
await recorderRef.current.prepare({ ... });
```

**Props chain:** `App.tsx` → `AppSidebar` → `TalktrackManager`

### Canvas Compositing

The compositor canvas handles several concerns:

1. **Background fill** - Canvas is filled with white before drawing to prevent transparent areas showing as black in the video
2. **Resolution scaling** - Uses CSS display size (via `getBoundingClientRect()`) capped at 1080p to avoid huge file sizes
3. **High-DPI handling** - Source canvas may have `devicePixelRatio` scaling; compositor handles this via proper `drawImage()` parameters

```typescript
// Fill with white background first
ctx.fillStyle = "#ffffff";
ctx.fillRect(0, 0, width, height);

// Draw with proper source/destination dimensions
ctx.drawImage(staticCanvas, 0, 0, srcWidth, srcHeight, 0, 0, width, height);
```

## Troubleshooting

### "Compositor canvas not initialized" error

**Cause:** The `TalktrackRecorder` singleton was disposed but not reset. This happens when:
1. User opens a scene → `TalktrackManager` mounts → recorder created
2. User goes to dashboard → `TalktrackManager` unmounts → `dispose()` called
3. User opens another scene → `getTalktrackRecorder()` returns broken instance

**Solution:** Ensure `disposeTalktrackRecorder()` is used in the cleanup effect, not `recorderRef.current?.dispose()`.

### Black bars on sides of recording

**Cause:** The workspace sidebar (left) was open when recording started, making the canvas narrower.

**Solution:** The sidebar should auto-close when recording starts. If it doesn't:
1. Check that `onCloseWorkspaceSidebar` prop is passed through `App.tsx` → `AppSidebar` → `TalktrackManager`
2. Try a hard refresh (Cmd+Shift+R / Ctrl+Shift+R) to clear cached JavaScript

### "Kinescope not configured" message

Make sure both `KINESCOPE_API_KEY` and `KINESCOPE_PROJECT_ID` are set in your `.env` file and you've rebuilt the Docker container.

### Camera/microphone not working

- Check browser permissions for camera and microphone
- Ensure you're accessing the app via HTTPS (required for getUserMedia in production)
- Try a different browser

### Upload fails

- Verify your Kinescope API key is valid
- Check that the project ID exists in your Kinescope account
- Check browser console for detailed error messages

### Recording quality issues

- The recording quality depends on your canvas size and content complexity
- Camera PIP is rendered at 15% of canvas width by default
- For best results, avoid rapid panning/zooming during recording
- Maximum resolution is capped at 1920x1080 to keep file sizes reasonable

## Dependencies

- **Browser APIs**: `MediaRecorder`, `getUserMedia`, `captureStream`, `AudioContext`
- **External**: Kinescope API for video hosting
- **NPM**: `@kinescope/player-iframe-api-loader` (optional, for enhanced playback control)

---

## Future Improvements

### Per-Workspace/Collection Kinescope Project IDs

Currently, all Talktrack recordings are uploaded to a single Kinescope project defined by the global `KINESCOPE_PROJECT_ID` environment variable. This works for single-tenant deployments but doesn't scale for multi-tenant scenarios.

**Planned implementation:**

1. **Database schema changes:**
   ```prisma
   model Workspace {
     // ... existing fields
     kinescopeProjectId  String?  // Optional override for this workspace
   }
   
   model Collection {
     // ... existing fields
     kinescopeProjectId  String?  // Optional override for this collection
   }
   ```

2. **Project ID resolution order:**
   - Collection's `kinescopeProjectId` (if set)
   - Workspace's `kinescopeProjectId` (if set)
   - Global `KINESCOPE_PROJECT_ID` from environment (fallback)

3. **Backend changes:**
   - `TalktrackService` should resolve the project ID based on the scene's collection/workspace
   - API endpoint for uploading should accept or look up the correct project ID

4. **Frontend changes:**
   - `kinescopeApi.ts` should receive the project ID from the backend rather than reading from `window.__ENV__`
   - Or: fetch the project ID from a new API endpoint before upload

5. **Admin UI:**
   - Add Kinescope Project ID field to Workspace Settings page
   - Optionally add to Collection settings (for fine-grained control)

**Use cases:**
- Different teams/departments have separate Kinescope projects for billing
- Separate projects for different clients in agency setups
- Compliance requirements for data isolation

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-21 | Fixed singleton pattern to properly reset on component unmount (prevents "Compositor canvas not initialized" error) |
| 2025-12-21 | Added auto-close of workspace sidebar before recording to prevent black bars |
| 2025-12-21 | Improved canvas compositing: white background fill, proper resolution scaling |
