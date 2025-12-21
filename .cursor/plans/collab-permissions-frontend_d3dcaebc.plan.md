---
name: collab-permissions-frontend
overview: Implement workspace-aware collaboration routing, sharing, copy/move UI, legacy separation, and translations per Part B phases 3-6.
todos:
  - id: routing-loader
    content: Add workspace scene routing and loader helpers
    status: completed
  - id: share-dialog-workspace
    content: Workspace-aware share dialog & collab start
    status: completed
    dependencies:
      - routing-loader
  - id: copy-move-ui
    content: Copy/Move dialog UI and API wiring
    status: completed
    dependencies:
      - routing-loader
  - id: legacy-separation
    content: Separate legacy vs workspace modes
    status: completed
    dependencies:
      - routing-loader
  - id: translations-styles
    content: Add locale keys and dialog styles
    status: completed
    dependencies:
      - copy-move-ui
      - share-dialog-workspace
---

# Frontend Collaboration Permissions Plan

## Goals

Implement Part B (Phases 3-6) of the collaboration permissions frontend: workspace scene routing & auto-join, workspace-aware share UI, copy/move collection dialog, legacy/anonymous separation, and translations.

## Steps

1. **Scene URL Routing & Loader**

- Add workspace scene URL detection in `frontend/excalidraw-app/App.tsx` for `/workspace/{slug}/scene/{id}#key={roomKey}` before legacy `#room=` handling.
- Create `frontend/excalidraw-app/data/workspaceSceneLoader.ts` with helpers to load scene/access, fetch/start collaboration credentials, and redirect on 401.
- Wire scene loading into App initialization and hash/path handling so workspace scenes set current scene state, update URL, and auto-join if permitted.

2. **Share Dialog Workspace Mode**

- Update `frontend/excalidraw-app/share/ShareDialog.tsx` to accept workspace scene context (sceneId, workspaceSlug, access) and render workspace-aware share section that starts collaboration via new API helpers and builds `/workspace/{slug}/scene/{id}#key=` links.
- Ensure legacy anonymous flow remains unchanged for non-workspace/legacy mode.

3. **Copy/Move Collection UI**

- Add `frontend/excalidraw-app/components/Workspace/CopyMoveDialog.tsx` (+ SCSS) to list shared workspaces and perform copy/move via workspace API.
- Extend `frontend/excalidraw-app/auth/workspaceApi.ts` with list/copy/move endpoints.
- Surface “Copy to workspace…” and “Move to workspace…” actions in workspace collection menus (likely `WorkspaceSidebar`/collection components) and refresh lists after success.

4. **Legacy vs Workspace Mode Separation**

- In `App.tsx`, detect anonymous/legacy (`?mode=anonymous` or `#room=`) vs workspace mode; render legacy flow without workspace UI, keep legacy `#room=` collaboration working.
- When opening scenes from workspace UI (e.g., `WorkspaceSidebar`), push URL to workspace path and auto-join collaboration when allowed.

5. **Translations & UX Text**

- Add required keys to `frontend/packages/excalidraw/locales/en.json` and `ru-RU.json` per plan (workspace copy/move labels, share dialog text, anonymous board entry, workspace type labels).
- Ensure any new UI strings use `t()` and input handlers stop propagation where needed.

6. **Styles & Misc**

- Add SCSS for `CopyMoveDialog` with `--ui-font` root var (per workspace style rule) and dark-mode variables.