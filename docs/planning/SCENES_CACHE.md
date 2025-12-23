# Scenes Cache System

This document describes the centralized caching system for workspace scenes in AstraDraw.

## Overview

AstraDraw implements a **stale-while-revalidate** caching strategy for scenes data. This ensures:

- **Instant navigation** - Switching between collections shows data immediately
- **Always fresh** - Background refresh keeps data up-to-date
- **No spinners** - Users only see loading spinner on first visit
- **Cross-component sync** - All components share the same cache

## Architecture

### Cache Storage

The cache is stored in a Jotai atom (`scenesCacheAtom`) which provides:
- Shared state across all React components
- Automatic re-renders when cache updates
- No prop drilling needed

```
┌─────────────────────────────────────────────────────────────┐
│                    scenesCacheAtom (Jotai)                  │
│  Map<string, { scenes: WorkspaceScene[], timestamp: number }>│
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐   ┌─────────────────┐   ┌─────────────────┐
│ WorkspaceSidebar │   │  DashboardView  │   │ CollectionView  │
│  (left panel)    │   │  (recent scenes)│   │ (collection)    │
└───────────────┘   └─────────────────┘   └─────────────────┘
```

### Cache Key Format

```
"workspaceId:collectionId"  - Scenes for a specific collection
"workspaceId:all"           - All scenes in workspace (dashboard)
```

### Components Using Cache

| Component | Cache Key | Purpose |
|-----------|-----------|---------|
| `WorkspaceSidebar` | `workspaceId:collectionId` | Scene list in left sidebar |
| `DashboardView` | `workspaceId:all` | Recently modified scenes |
| `CollectionView` | `workspaceId:collectionId` | Collection page scenes |

## Usage

### Reading Scenes with Cache

Use the `useScenesCache` hook:

```typescript
import { useScenesCache } from "../../hooks/useScenesCache";

const MyComponent = ({ workspace, collection }) => {
  const { scenes, isLoading, updateScenes, refetch } = useScenesCache({
    workspaceId: workspace?.id,
    collectionId: collection?.id,  // null for all scenes
    enabled: !!workspace?.id,
  });

  // scenes - Array of WorkspaceScene
  // isLoading - true only on first load (not on cache hit)
  // updateScenes - Function to update scenes and cache together
  // refetch - Function to force refresh
};
```

### Updating Scenes

When modifying scenes (create, delete, rename, duplicate), use `updateScenes` to keep cache in sync:

```typescript
const handleDeleteScene = async (sceneId: string) => {
  await deleteSceneApi(sceneId);
  
  // Update local state AND cache together
  updateScenes((prev) => prev.filter((s) => s.id !== sceneId));
  
  // Notify other components to refresh
  triggerScenesRefresh();
};
```

### Invalidating Cache

When scenes move between collections (copy/move), invalidate the cache:

```typescript
import { useInvalidateScenesCache } from "../../hooks/useScenesCache";

const invalidateCache = useInvalidateScenesCache();

// Invalidate specific collection
invalidateCache(workspaceId, collectionId);

// Invalidate all collections in workspace
invalidateCache(workspaceId);
```

## Caching Strategy: Stale-While-Revalidate

```
User opens collection → Check cache
  │
  ├── Cache HIT
  │     │
  │     ├── Show cached data immediately (no spinner)
  │     │
  │     └── Fetch fresh data in background
  │           │
  │           └── Update cache & UI silently
  │
  └── Cache MISS
        │
        ├── Show loading spinner
        │
        └── Fetch data → Cache → Display
```

### Benefits

1. **Perceived performance** - Data appears instantly on cache hit
2. **Data freshness** - Background refresh ensures data doesn't get stale
3. **Reduced API calls** - Same data isn't fetched multiple times
4. **Graceful degradation** - On error, cached data is still shown

## Cache Lifecycle

### When Cache is Populated

- First visit to a collection
- Background refresh after showing cached data
- After scene operations (create, rename, duplicate)

### When Cache is Updated

- `updateScenes()` - Updates specific cache entry
- Background refresh - Replaces cache entry with fresh data

### When Cache is Invalidated

- Scene moved/copied between collections
- Workspace switch (clears all cache)
- Manual `invalidateCache()` call

### When Cache is Cleared

- User logs out
- `clearScenesCacheAtom` is dispatched

## Atoms Reference

### `scenesCacheAtom`

Main cache storage atom.

```typescript
type ScenesCacheEntry = {
  scenes: WorkspaceScene[];
  timestamp: number;
};

const scenesCacheAtom = atom<Map<string, ScenesCacheEntry>>(new Map());
```

### `setScenesCacheAtom`

Action atom to set cache entry.

```typescript
const setCacheEntry = useSetAtom(setScenesCacheAtom);
setCacheEntry({ key: "workspace123:collection456", scenes: [...] });
```

### `invalidateScenesCacheAtom`

Action atom to invalidate cache entries.

```typescript
const invalidate = useSetAtom(invalidateScenesCacheAtom);

// Invalidate specific collection
invalidate({ workspaceId: "ws123", collectionId: "col456" });

// Invalidate all collections in workspace
invalidate({ workspaceId: "ws123" });
```

### `clearScenesCacheAtom`

Action atom to clear entire cache.

```typescript
const clearCache = useSetAtom(clearScenesCacheAtom);
clearCache();
```

## Cross-Component Communication

When one component modifies scenes, others need to know:

```
┌─────────────────┐    updateScenes()    ┌─────────────────┐
│  CollectionView │ ──────────────────▶  │  scenesCacheAtom │
│  (delete scene) │                      │  (shared cache)  │
└─────────────────┘                      └─────────────────┘
        │                                         │
        │ triggerScenesRefresh()                  │ Jotai subscription
        ▼                                         ▼
┌─────────────────┐                      ┌─────────────────┐
│ scenesRefreshAtom│ ◀────────────────── │  DashboardView  │
│  (counter: 0→1)  │                     │ (auto re-render) │
└─────────────────┘                      └─────────────────┘
        │
        │ useEffect dependency
        ▼
┌─────────────────┐
│ WorkspaceSidebar │
│ (refetch scenes) │
└─────────────────┘
```

## Performance Considerations

### Cache Size

The cache stores scenes per collection. For a workspace with:
- 10 collections × 50 scenes average = ~500 scene objects in memory
- Each scene object is ~500 bytes
- Total: ~250KB (negligible)

### Background Refresh

Background fetches happen on every cache hit, but:
- Don't block UI (data shown immediately)
- Don't show spinner
- Update silently when complete

### Memory Management

- Cache is cleared on logout
- Cache is per-session (not persisted to localStorage)
- Old entries are not automatically evicted (could add TTL if needed)

## Future Improvements

- [ ] Add TTL (time-to-live) to cache entries
- [ ] Persist cache to localStorage for faster initial load
- [ ] Add cache for collections (not just scenes)
- [ ] Implement optimistic updates for better UX
- [ ] Add cache size limits with LRU eviction

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-23 | Initial implementation with stale-while-revalidate strategy |
| 2025-12-23 | Added `useScenesCache` hook for shared cache access |
| 2025-12-23 | Migrated DashboardView and CollectionView to use shared cache |

