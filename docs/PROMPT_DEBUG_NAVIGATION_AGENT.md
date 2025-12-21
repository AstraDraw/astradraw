# Prompt for Debug Navigation Agent

Copy everything below the line and paste it into a new Cursor Agent chat.

---

## Task: Implement File-Based Navigation Debugging for AstraDraw

I need you to implement a debugging system for scene navigation in AstraDraw. The debugging logs must be written to a file that you can read directly, without asking me to check the console.

### What You Need to Do

1. **Create a logging utility** in the frontend that sends navigation events to the backend
2. **Create a backend endpoint** that writes logs to a file
3. **Update Docker Compose** to mount the logs directory
4. **Instrument the navigation code** with log calls

### Files to Read First

Read these files to understand the architecture:

```
@docs/DEBUG_SCENE_NAVIGATION.md - Full specification of what to log and how navigation works
@docs/SCENE_NAVIGATION.md - How scene navigation is supposed to work
@frontend/excalidraw-app/App.tsx - Main navigation logic
@frontend/excalidraw-app/router.ts - URL utilities
@frontend/excalidraw-app/components/Settings/settingsState.ts - Navigation atoms
@frontend/excalidraw-app/components/Workspace/WorkspaceSidebar.tsx - Scene interactions
```

### Requirements

#### 1. Log File Location

```
Host path:      deploy/logs/navigation.log
Container path: /app/logs/navigation.log (frontend) or /logs/navigation.log (backend)
```

The logs directory should be mounted in docker-compose.yml so you can read the file at:
`/Volumes/storage/01_Projects/astradraw/deploy/logs/navigation.log`

#### 2. Log Format

Each line must be a JSON object with:
- `ts` - ISO timestamp
- `event` - Event name (see DEBUG_SCENE_NAVIGATION.md for list)
- `sceneId` - Scene ID if applicable
- `workspaceSlug` - Workspace slug if applicable
- `data` - Additional data object

Example:
```json
{"ts":"2025-12-21T10:30:45.123Z","event":"SCENE_LOAD_START","sceneId":"abc123","workspaceSlug":"admin","data":{"isInitialLoad":false}}
```

#### 3. Frontend Logger

Create a utility that:
- Collects navigation events
- Sends them to a backend endpoint (POST /api/v2/debug/navigation)
- Works only when `VITE_DEBUG_NAVIGATION=true`

#### 4. Backend Endpoint

Create an endpoint that:
- Receives log entries
- Appends them to the log file
- Works only when `DEBUG_NAVIGATION=true`

#### 5. Docker Compose Changes

Add to `deploy/docker-compose.yml`:
- Volume mount for logs directory
- Environment variables for enabling debug mode

#### 6. Events to Log

See `@docs/DEBUG_SCENE_NAVIGATION.md` for the complete list. Key events:

**Navigation:**
- `NAV_INIT` - App starts
- `NAV_TO_DASHBOARD` - Going to dashboard
- `NAV_TO_SCENE` - Going to scene
- `NAV_POPSTATE` - Browser back/forward

**Scene Loading:**
- `SCENE_LOAD_START` - Loading begins
- `SCENE_LOAD_API_SUCCESS` - API returned data
- `SCENE_LOAD_UPDATE` - Canvas updated
- `SCENE_LOAD_COMPLETE` - Loading finished
- `SCENE_LOAD_STALE` - Stale request ignored

**Scene Management:**
- `SCENE_CREATE_SUCCESS` - Scene created
- `SCENE_DELETE_SUCCESS` - Scene deleted

**State Changes:**
- `STATE_APP_MODE` - appMode changed
- `STATE_CURRENT_SCENE` - currentSceneId changed

### Implementation Steps

1. Create `frontend/excalidraw-app/debug/navigationLogger.ts`
2. Create `backend/src/debug/debug.controller.ts` and `debug.module.ts`
3. Update `backend/src/app.module.ts` to include DebugModule
4. Update `deploy/docker-compose.yml` with volume mount
5. Update `deploy/docker-compose.override.yml.disabled` with volume mount
6. Instrument the navigation code in:
   - `App.tsx` (loadSceneFromUrl, handlePopState, handleNewScene)
   - `settingsState.ts` (navigation atoms)
   - `WorkspaceSidebar.tsx` (scene clicks, deletes)
   - `router.ts` (navigateTo, replaceUrl)

### After Implementation

1. Run `just check-all` to verify no errors
2. Run `just rebuild app` and `just rebuild api` to rebuild with debug code
3. Clear the log file: `echo "" > deploy/logs/navigation.log`
4. Test by creating and switching scenes
5. Read the log file to verify events are being recorded

### How to Read Logs

After implementation, you can read the navigation log directly:

```bash
cat /Volumes/storage/01_Projects/astradraw/deploy/logs/navigation.log
```

Or read the last 50 lines:
```bash
tail -50 /Volumes/storage/01_Projects/astradraw/deploy/logs/navigation.log
```

### Notes

- The debug mode should be OFF by default (don't set env vars in main docker-compose.yml)
- Add instructions to enable debug mode in the env.example file
- The log file should be gitignored
- Consider adding a max file size or rotation if needed

### Success Criteria

When complete, I should be able to:
1. Enable debug mode by setting environment variables
2. Restart the containers
3. Use the app (create scenes, switch between them, go to dashboard)
4. You read the log file directly and tell me what happened

Start by reading the documentation files, then implement the solution.

