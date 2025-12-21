# Navigation Debug Tool

This document describes the file-based navigation debugging system for AstraDraw. Use this tool to diagnose scene switching, URL routing, and navigation issues.

## Quick Start

### Enable Debug Mode

1. **Set environment variable** in `deploy/.env`:
   ```bash
   DEBUG_NAVIGATION=true
   ```

2. **Restart containers**:
   ```bash
   just restart
   # Or: cd deploy && docker compose restart
   ```

3. **Use the app** - create scenes, switch between them, navigate

4. **Read the logs**:
   ```bash
   cat deploy/logs/navigation.log
   # Or last 50 lines:
   tail -50 deploy/logs/navigation.log
   ```

### Disable Debug Mode

1. **Remove or set to false** in `deploy/.env`:
   ```bash
   DEBUG_NAVIGATION=false
   ```

2. **Restart containers**:
   ```bash
   just restart
   ```

3. **Clear old logs** (optional):
   ```bash
   rm deploy/logs/navigation.log
   ```

## Log Format

Each line is a JSON object (NDJSON format):

```json
{"ts":"2025-12-21T10:30:45.123Z","event":"SCENE_LOAD_START","sceneId":"abc123","workspaceSlug":"admin","data":{"isInitialLoad":false}}
{"ts":"2025-12-21T10:30:45.456Z","event":"SCENE_LOAD_API_SUCCESS","sceneId":"abc123","workspaceSlug":"admin","data":{"sceneTitle":"My Scene"}}
{"ts":"2025-12-21T10:30:45.789Z","event":"SCENE_LOAD_COMPLETE","sceneId":"abc123","workspaceSlug":"admin","data":{"success":true}}
```

### Fields

| Field | Description |
|-------|-------------|
| `ts` | ISO 8601 timestamp |
| `event` | Event type (see below) |
| `sceneId` | Scene ID if applicable |
| `workspaceSlug` | Workspace slug if applicable |
| `data` | Additional event-specific data |

## Event Types

### Navigation Events

| Event | When | Key Data |
|-------|------|----------|
| `NAV_INIT` | App initializes | `url`, `pathname` |
| `NAV_TO_DASHBOARD` | Navigate to dashboard | `fromSceneId` |
| `NAV_TO_SCENE` | Navigate to scene | `title`, `previousSceneId`, `source` |
| `NAV_TO_COLLECTION` | Navigate to collection | `collectionId`, `isPrivate` |
| `NAV_POPSTATE` | Browser back/forward | `routeType`, `url` |
| `NAV_URL_PUSH` | URL pushed to history | `url` |
| `NAV_URL_REPLACE` | URL replaced in history | `url` |

### Scene Loading Events

| Event | When | Key Data |
|-------|------|----------|
| `SCENE_LOAD_START` | Loading begins | `isInitialLoad`, `currentLoadingSceneId` |
| `SCENE_LOAD_API_START` | API call begins | `endpoint` |
| `SCENE_LOAD_API_SUCCESS` | API returns data | `sceneTitle`, `hasData`, `canCollaborate` |
| `SCENE_LOAD_API_ERROR` | API call fails | `error` |
| `SCENE_LOAD_STALE` | Stale request ignored | `currentLoadingSceneId` |
| `SCENE_LOAD_UPDATE` | Canvas updated | `elementsCount`, `filesCount` |
| `SCENE_LOAD_COMPLETE` | Loading finished | `success` |

### Scene Management Events

| Event | When | Key Data |
|-------|------|----------|
| `SCENE_CREATE_START` | Creating new scene | `title`, `collectionId` |
| `SCENE_CREATE_SUCCESS` | Scene created | `title`, `collectionId` |
| `SCENE_DELETE_START` | Deleting scene | `isCurrentScene` |
| `SCENE_DELETE_SUCCESS` | Scene deleted | `remainingScenesCount`, `wasCurrentScene` |

### State Change Events

| Event | When | Key Data |
|-------|------|----------|
| `STATE_APP_MODE` | appMode changes | `from`, `to` |
| `STATE_CURRENT_SCENE` | currentSceneId changes | `from`, `to` |
| `STATE_LOADING` | isLoadingScene changes | `value` |
| `STATE_DATA_LOADED` | sceneDataLoaded changes | `value` |

## Diagnosing Common Issues

### Scene Data Reset on Switch

**Symptom:** Canvas shows empty when switching scenes

**Look for:**
- `SCENE_LOAD_START` without `SCENE_LOAD_COMPLETE`
- Missing `SCENE_LOAD_UPDATE` event
- `SCENE_LOAD_STALE` appearing unexpectedly

### URL Doesn't Match Content

**Symptom:** URL shows scene A but canvas shows scene B

**Look for:**
- `NAV_URL_PUSH` with different sceneId than `SCENE_LOAD_COMPLETE`
- Multiple `SCENE_LOAD_START` for different scenes close together

### Back Button Goes to Deleted Scene

**Symptom:** Back button tries to load deleted scene

**Look for:**
- `NAV_URL_PUSH` instead of `NAV_URL_REPLACE` after `SCENE_DELETE_SUCCESS`

### Infinite Loop

**Symptom:** Hundreds of API calls, app freezes

**Look for:**
- Repeating pattern of same events
- `SCENE_LOAD_START` events without `SCENE_LOAD_STALE`

### Scene Loads Twice

**Symptom:** Scene loads, then reloads immediately

**Look for:**
- Two `SCENE_LOAD_START` events for same sceneId in quick succession
- Check `NAV_POPSTATE` triggering unexpected reload

## Useful Commands

### Parse logs with jq

```bash
# Get all scene load events
cat deploy/logs/navigation.log | jq 'select(.event | startswith("SCENE_LOAD"))'

# Get events for a specific scene
cat deploy/logs/navigation.log | jq 'select(.sceneId == "abc123")'

# Get only errors
cat deploy/logs/navigation.log | jq 'select(.event | endswith("_ERROR"))'

# Count events by type
cat deploy/logs/navigation.log | jq -s 'group_by(.event) | map({event: .[0].event, count: length})'
```

### Clear logs before testing

```bash
echo "" > deploy/logs/navigation.log
```

### Watch logs in real-time

```bash
tail -f deploy/logs/navigation.log | jq .
```

## Architecture

### Frontend (`frontend/excalidraw-app/debug/navigationLogger.ts`)

- Collects navigation events
- Batches and sends to backend via POST `/api/v2/debug/navigation`
- Uses `sendBeacon` for reliable delivery on page unload
- Only active when `VITE_DEBUG_NAVIGATION=true`

### Backend (`backend/src/debug/debug.controller.ts`)

- Receives log entries from frontend
- Appends to log file as NDJSON
- Only writes when `DEBUG_NAVIGATION=true`

### Docker Configuration

| File | What to add |
|------|-------------|
| `deploy/.env` | `DEBUG_NAVIGATION=true` |
| `deploy/docker-compose.yml` | Volume mount already configured |
| `deploy/logs/` | Log files written here |

## Performance Considerations

- Debug logging adds network overhead (batched every 100ms)
- Log file can grow large with heavy usage
- **Disable in production** - set `DEBUG_NAVIGATION=false`

## Files Involved

| File | Purpose |
|------|---------|
| `frontend/excalidraw-app/debug/navigationLogger.ts` | Frontend logger utility |
| `backend/src/debug/debug.controller.ts` | Backend log endpoint |
| `backend/src/debug/debug.module.ts` | NestJS module |
| `deploy/docker-compose.yml` | Volume mount for logs |
| `deploy/logs/navigation.log` | Log output file |

## Test Scenarios

When debugging, try these scenarios and check logs:

1. **Fresh login** → Should redirect to dashboard
2. **Create scene from dashboard** → Should open canvas with new scene
3. **Switch scenes from sidebar** → Should load correct scene data
4. **Rapid scene switching** → Should end up on last clicked scene
5. **Go to dashboard** → Should show dashboard, clear scene state
6. **Back button (scene → dashboard)** → Should return to scene
7. **Delete current scene** → Should switch to another scene or dashboard
8. **Back after delete** → Should NOT go to deleted scene
9. **Refresh on scene** → Should reload same scene
10. **Direct URL access** → Should load correct scene

## Related Documentation

- [Scene Navigation Architecture](./SCENE_NAVIGATION.md)
- [URL Routing](./URL_ROUTING.md)

