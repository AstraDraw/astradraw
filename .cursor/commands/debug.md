# Debug Issue

You are helping debug an issue in AstraDraw.

## Step 1: Gather Context (Minimal)

Ask the user:
1. **What's the problem?** (error message, unexpected behavior)
2. **Where does it occur?** (frontend/backend/both, which component/endpoint)
3. **Steps to reproduce?**

## Step 2: Check Environment

```bash
just dev-status   # Is everything running?
```

If not running:
```bash
just dev          # Start dev environment
```

## Step 3: Request Relevant Rules Only

**Don't load all rules!** Request only what's needed:

| Issue Type | Rule to Request |
|------------|-----------------|
| Frontend UI/component | `@frontend-patterns` |
| State/navigation | `@frontend-state` |
| Frontend errors | `@common-issues-frontend` |
| Backend API | `@backend-patterns` |
| Backend errors | `@common-issues-backend` |
| Docker/dev environment | `@common-issues-dev` |
| Collaboration/realtime | `@collaboration-system` |

## Step 4: Common Quick Checks

### Frontend Issues

**Infinite loop / stack overflow:**
- Check if `handlePopState` calls navigation atoms (it shouldn't)
- Check `useEffect` dependencies for state that's also being set

**Scene data loss:**
- Verify CSS hide/show pattern is used (not conditional rendering)
- Check `/docs/troubleshooting/CRITICAL_CSS_HIDE_SHOW_FIX.md`

**Keyboard shortcuts triggering in inputs:**
- Add `onKeyDown={(e) => e.stopPropagation()}` to input

**Dark mode not working:**
- Use BOTH selectors: `.excalidraw.theme--dark, .excalidraw-app.theme--dark`

### Backend Issues

**Build fails with jwt-auth.guard:**
- Import from `jwt.guard.ts`, NOT `jwt-auth.guard.ts`

**401 Unauthorized:**
- Ensure `credentials: "include"` in fetch calls

**OIDC fails in Docker:**
- Check `OIDC_INTERNAL_URL` is set for internal Docker networking

### Dev Environment Issues

**Changes not appearing:**
- Is `just dev` running? Check `just dev-status`
- Hard refresh: `Cmd+Shift+R`
- If using Docker: `just rebuild app`

**Bad Gateway:**
- Run `just dev-status` to see what's not running
- Run `just dev` to restart

## Step 5: Targeted Investigation

Based on the issue type, look at specific files:

| Issue | Files to Check |
|-------|----------------|
| Navigation | `App.tsx`, `router.ts`, `settingsState.ts` |
| Scene loading | `workspaceSceneLoader.ts`, `httpStorage.ts` |
| API calls | `workspaceApi.ts`, backend controller |
| Auth | `AuthProvider.tsx`, `auth.controller.ts` |
| Collaboration | `collab/`, `room-service/src/` |

## Step 6: Fix and Verify

1. Make the fix
2. Test in browser at `https://draw.local`
3. Run `just check-all` before committing

## Keep Context Light

- Don't read entire large files (App.tsx is 2400+ lines)
- Use targeted searches: `grep` for specific functions/variables
- Request only the rules you need
- If issue is solved, don't continue investigating
