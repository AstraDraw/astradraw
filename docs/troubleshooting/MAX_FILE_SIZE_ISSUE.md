# Documentation: Fixing Large Image Sync (4MB -> 200MB)

## Problem

Users encountered a "Very large file. Maximum allowed size - 4MB" error when syncing large images in collaborative sessions. This was due to hardcoded limits in the frontend, storage backend, and WebSocket room server.

## Resolution

The limit has been increased to **200MB** across all layers of the application.

### 1. Frontend (App & Package)

- **Modified**: `frontend/packages/common/src/constants.ts`
  - Changed `MAX_ALLOWED_FILE_BYTES` from `4 * 1024 * 1024` to `200 * 1024 * 1024`.
  - This is the primary constant used by the `@excalidraw/excalidraw` package for file size validation.
- **Modified**: `frontend/excalidraw-app/app_constants.ts`
  - Changed `FILE_UPLOAD_MAX_BYTES` to `200 * 1024 * 1024` for consistency.

### 2. Storage Backend

- **Modified**: `backend/src/raw-parser.middleware.ts`
  - Increased the `body-parser` limit to `200mb`.
  - Code: `limit: process.env.BODY_LIMIT ?? '200mb'`.
  - This can be overridden by the `BODY_LIMIT` environment variable if needed.

### 3. WebSocket Room Server

- **Modified**: `room-service/src/index.ts`
  - Increased `maxHttpBufferSize` for the Socket.IO server to `200 * 1024 * 1024`.
  - This ensures that large image data chunks can be transmitted via WebSockets during real-time sync.

---

## How to Build & Deploy

### Local Development

To apply these changes locally, you must rebuild the containers without cache to ensure the updated `common` package is correctly linked and bundled:

```bash
cd deploy
docker compose build --no-cache app api room
docker compose up -d
```

_Note: A hard refresh (Cmd+Shift+R) in the browser may be required to clear cached JavaScript._

### GitHub Workflows

**Do I need to change workflows?** **No**, you do not need to change the `.github/workflows/*.yml` files.

The current workflows are configured to build from the source code in your repository:

- The **App** workflow uses the `Dockerfile` in `excalidraw/`, which now contains the updated constants.
- The **Storage** and **Room** workflows build from their respective directories.

As long as you **commit and push** the changes I made to these repositories, the next time the GitHub Actions run (e.g., on a new tag or manual dispatch), they will produce images with the 200MB limit enabled.

### Summary of Source Changes for Git Commit:

Ensure you commit changes in:

1. `frontend/packages/common/src/constants.ts`
2. `frontend/excalidraw-app/app_constants.ts`
3. `backend/src/raw-parser.middleware.ts`
4. `room-service/src/index.ts`
