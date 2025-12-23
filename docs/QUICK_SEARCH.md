# Quick Search Feature

Quick Search is a keyboard-driven navigation feature that allows users to quickly find and open scenes and collections within their current workspace.

> **Note:** Quick Search is only available for **authenticated users**. The hotkey and modal are disabled for anonymous/unauthenticated users.

## Overview

Quick Search provides:
- **Global hotkey** (Cmd+P / Ctrl+P) accessible from both canvas and dashboard modes
- **Unified search** across collections and scenes
- **Keyboard navigation** with arrow keys
- **Quick actions** - open in current view or new tab
- **Access-aware results** - only shows items the user can access
- **Authentication required** - only available when signed in

## User Interface

### Opening Quick Search

| Platform | Hotkey |
|----------|--------|
| macOS | `Cmd + P` |
| Windows/Linux | `Ctrl + P` |

The hotkey works in both **canvas mode** and **dashboard mode** thanks to the CSS Hide/Show pattern (see [CRITICAL_CSS_HIDE_SHOW_FIX.md](CRITICAL_CSS_HIDE_SHOW_FIX.md)).

### Modal Layout

```
┌─────────────────────────────────────────────────────────────┐
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 🔍  Search scenes and collections...                │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ↑↓ Select    ↵ Open    ⌘+↵ Open in new tab    esc Close  │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│  Collections                                                │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  🔒  Private                                                │
│      by You • 4 days ago                                   │
│                                                             │
│  📁  Main                                              ←──  │  (selected)
│      by Mr. Khachaturov • 4 days ago                       │
│                                                             │
│  🍯  ass                                                    │
│      by Mr. Khachaturov • 2 days ago                       │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│  Scenes                                                     │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  [thumb]  Use-cases showcase                                │
│           by Mr. Khachaturov • 21 hours ago                │
│           in Private                                   🔒   │
│                                                             │
│  [thumb]  Presentation showcase                             │
│           by Mr. Khachaturov • 2 days ago                  │
│           in Main                                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Keyboard Navigation

| Key | Action |
|-----|--------|
| `↑` / `↓` | Move selection up/down through results |
| `Enter` | Open selected item |
| `Cmd+Enter` (Mac) / `Ctrl+Enter` (Win) | Open in new browser tab |
| `Esc` | Close Quick Search |
| Click outside modal | Close Quick Search |

### Result Types

#### Collections

- Shows collection icon (emoji or default folder icon)
- Private collections show lock icon 🔒
- Displays author name and last modified time
- **Action:** Opens collection view at `/workspace/{slug}/collection/{id}`

#### Scenes

- Shows scene thumbnail (or placeholder if none)
- Displays scene title, author, and last modified time
- Shows which collection the scene belongs to
- Private collection scenes show lock badge
- **Action:** Opens scene in canvas mode at `/workspace/{slug}/scene/{id}`

## Search Behavior

### Filtering

- Search is performed **client-side** after initial data fetch
- Matches against:
  - Collection names
  - Scene titles
- Case-insensitive matching
- Partial matches supported (e.g., "pres" matches "Presentation showcase")

### Scope

- Searches only within the **current workspace**
- Respects user access permissions:
  - Only shows collections the user can access
  - Only shows scenes from accessible collections
  - Private collections only visible to their owner

### Access Control

Per [ROLES_TEAMS_COLLECTIONS.md](ROLES_TEAMS_COLLECTIONS.md):

| Role | Can See |
|------|---------|
| ADMIN | All collections and scenes in workspace |
| MEMBER | Own private collection + team-accessible collections |
| VIEWER | Team-accessible collections (read-only) |

## Technical Implementation

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         App.tsx                              │
│                                                              │
│  useEffect(() => {                                          │
│    // Global Cmd+P listener - works in both modes           │
│    window.addEventListener("keydown", handleCmdP);          │
│  });                                                         │
│                                                              │
│  ┌────────────────────┐    ┌────────────────────┐          │
│  │  Dashboard (CSS)   │    │   Canvas (CSS)     │          │
│  │  display: block/   │    │   display: block/  │          │
│  │          none      │    │           none     │          │
│  └────────────────────┘    └────────────────────┘          │
│                                                              │
│  <QuickSearchModal />  ← Always rendered at App level       │
└─────────────────────────────────────────────────────────────┘
```

### State Management

```typescript
// settingsState.ts
export const quickSearchOpenAtom = atom<boolean>(false);
export const searchQueryAtom = atom<string>("");
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `QuickSearchModal` | `components/Workspace/QuickSearchModal.tsx` | Modal UI with search and results |
| `App.tsx` | `excalidraw-app/App.tsx` | Hotkey registration, modal rendering |

### API Integration

Quick Search uses existing workspace APIs:

```typescript
// Fetch collections (already filtered by access)
const collections = await listCollections(workspaceId);

// Fetch all scenes in workspace (already filtered by access)
const scenes = await listWorkspaceScenes(workspaceId);
```

### Navigation Actions

```typescript
// Open collection
navigateToCollection({ collectionId, isPrivate });
// → URL: /workspace/{slug}/collection/{id}

// Open scene
navigateToScene({ sceneId, title, workspaceSlug });
// → URL: /workspace/{slug}/scene/{id}

// Open in new tab
window.open(buildCollectionUrl(slug, collectionId), '_blank');
window.open(buildSceneUrl(slug, sceneId), '_blank');
```

## Dashboard Search Integration

In addition to the Quick Search modal, the sidebar search input in **dashboard mode** shows results in the main content area:

1. User types in sidebar search input
2. `searchQueryAtom` is updated
3. `WorkspaceMainContent` checks the atom
4. If query is not empty, renders `SearchResultsView` instead of normal content
5. Results show matching scenes with same card grid as collection view

This provides two search experiences:
- **Quick Search (Cmd+P):** Fast navigation overlay, works everywhere
- **Dashboard Search:** Persistent results in main content area

## Localization

Translation keys in `packages/excalidraw/locales/`:

```json
{
  "workspace.quickSearch": "Quick search...",
  "workspace.quickSearchPlaceholder": "Search scenes and collections...",
  "workspace.collections": "Collections",
  "workspace.scenes": "Scenes",
  "workspace.select": "Select",
  "workspace.open": "Open",
  "workspace.openInNewTab": "Open in new tab",
  "workspace.close": "Close",
  "workspace.noSearchResults": "No results found",
  "workspace.noSearchResultsHint": "Try a different search term"
}
```

## Testing Checklist

### Authentication Tests

- [ ] Quick Search hotkey does NOT work when not signed in
- [ ] Quick Search modal does NOT render when not signed in
- [ ] Cmd+P shows browser print dialog when not signed in (default behavior)
- [ ] After signing in, Cmd+P opens Quick Search modal

### Hotkey Tests

- [ ] Cmd+P opens modal from canvas mode (when authenticated)
- [ ] Cmd+P opens modal from dashboard mode (when authenticated)
- [ ] Cmd+P does not open browser print dialog (when authenticated)
- [ ] Ctrl+P works on Windows/Linux (when authenticated)
- [ ] Hotkey works after switching between modes multiple times

### Navigation Tests

- [ ] ↑/↓ arrows move selection through results
- [ ] Selection wraps from bottom to top
- [ ] Selection wraps from top to bottom
- [ ] Enter opens selected collection (goes to collection page)
- [ ] Enter opens selected scene (goes to canvas)
- [ ] Cmd+Enter opens in new tab
- [ ] Esc closes modal
- [ ] Click outside closes modal

### Search Tests

- [ ] Empty query shows all accessible items
- [ ] Typing filters results in real-time
- [ ] Search is case-insensitive
- [ ] Partial matches work
- [ ] Collections and scenes are separated by divider
- [ ] Private items only visible to owner

### Access Control Tests

- [ ] ADMIN sees all collections
- [ ] MEMBER only sees accessible collections
- [ ] VIEWER only sees accessible collections
- [ ] Private collections only visible to owner
- [ ] Scenes respect collection access

## Related Documentation

- [ROLES_TEAMS_COLLECTIONS.md](ROLES_TEAMS_COLLECTIONS.md) - Access control rules
- [URL_ROUTING.md](URL_ROUTING.md) - URL patterns for navigation
- [CRITICAL_CSS_HIDE_SHOW_FIX.md](CRITICAL_CSS_HIDE_SHOW_FIX.md) - Why hotkey works in both modes
- [WORKSPACE.md](WORKSPACE.md) - Workspace and scene management

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-23 | Initial specification |

