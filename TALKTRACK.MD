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

Add the following to your `.env` file:

```bash
# Kinescope API Key for video upload and playback
KINESCOPE_API_KEY=your_kinescope_api_key_here

# Kinescope Project ID (parent folder for uploaded recordings)
KINESCOPE_PROJECT_ID=your_project_id_here
```

### 3. Rebuild and Start

```bash
docker-compose up -d --build
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

| File | Description |
|------|-------------|
| `TalktrackRecorder.ts` | Core recording logic with canvas capture, camera PIP compositing, and MediaRecorder |
| `TalktrackPanel.tsx` | Sidebar panel showing recordings list (scene-specific) |
| `TalktrackSetupDialog.tsx` | Camera/mic selection dialog before recording |
| `TalktrackToolbar.tsx` | Floating controls during recording |
| `TalktrackManager.tsx` | Orchestrates recording lifecycle and upload |
| `kinescopeApi.ts` | Kinescope upload helpers |
| `workspaceApi.ts` | Backend API client for recording CRUD operations |

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

## Troubleshooting

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

## Dependencies

- **Browser APIs**: `MediaRecorder`, `getUserMedia`, `captureStream`, `AudioContext`
- **External**: Kinescope API for video hosting
- **NPM**: `@kinescope/player-iframe-api-loader` (optional, for enhanced playback control)
