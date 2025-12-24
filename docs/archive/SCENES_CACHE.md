# Scenes Cache System

This document describes the caching system for workspace scenes in AstraDraw using React Query.

## Overview

AstraDraw uses **TanStack React Query** for scenes caching. This provides:

- **Automatic caching** - Built-in stale-while-revalidate pattern
- **Request deduplication** - Multiple components share one request
- **Background refetching** - Data stays fresh automatically
- **Instant navigation** - Cached data shown immediately

## Architecture

### React Query Setup

The cache is managed by React Query's QueryClient:

```
┌─────────────────────────────────────────────────────────────┐
│                    QueryClient (React Query)                 │
│  Automatic caching, deduplication, background refetch       │
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

### Query Key Format

```typescript
// lib/queryClient.ts
export const queryKeys = {
  scenes: {
    all: ["scenes"] as const,
    list: (workspaceId: string, collectionId?: string | null) =>
      ["scenes", workspaceId, collectionId ?? "all"] as const,
  },
};
```

### Components Using Cache

| Component | Query Key | Purpose |
|-----------|-----------|---------|
| `WorkspaceSidebar` | `queryKeys.scenes.list(workspaceId, collectionId)` | Scene list in left sidebar |
| `DashboardView` | `queryKeys.scenes.list(workspaceId, null)` | Recently modified scenes |
| `CollectionView` | `queryKeys.scenes.list(workspaceId, collectionId)` | Collection page scenes |
| `SearchResultsView` | `queryKeys.scenes.list(workspaceId, null)` | Search results |

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
  // updateScenes - Function to update cache optimistically
  // refetch - Function to force refresh
};
```

### Updating Scenes (Optimistic Updates)

When modifying scenes, use `updateScenes` for immediate UI feedback:

```typescript
const { updateScenes } = useScenesCache({ workspaceId, collectionId });

const handleDeleteScene = async (sceneId: string) => {
  // Optimistic update - UI updates immediately
  updateScenes((prev) => prev.filter((s) => s.id !== sceneId));
  
  // API call
  await deleteSceneApi(sceneId);
};
```

### Invalidating Cache

After mutations, invalidate queries to refetch fresh data:

```typescript
import { useQueryClient } from "@tanstack/react-query";
import { queryKeys } from "../../lib/queryClient";

const queryClient = useQueryClient();

// Invalidate all scenes
queryClient.invalidateQueries({ queryKey: queryKeys.scenes.all });

// Invalidate specific workspace
queryClient.invalidateQueries({ 
  queryKey: ["scenes", workspaceId] 
});

// Invalidate specific collection
queryClient.invalidateQueries({ 
  queryKey: queryKeys.scenes.list(workspaceId, collectionId) 
});
```

### Using the Invalidation Hook

For convenience, use the `useInvalidateScenesCache` hook:

```typescript
import { useInvalidateScenesCache } from "../../hooks/useScenesCache";

const invalidateCache = useInvalidateScenesCache();

// Invalidate specific collection
invalidateCache(workspaceId, collectionId);

// Invalidate all collections in workspace
invalidateCache(workspaceId);
```

## Caching Strategy

React Query implements stale-while-revalidate automatically:

```
User opens collection → Check cache
  │
  ├── Cache HIT (data < staleTime)
  │     │
  │     └── Show cached data (no refetch)
  │
  ├── Cache HIT (data > staleTime)
  │     │
  │     ├── Show cached data immediately
  │     │
  │     └── Refetch in background → Update silently
  │
  └── Cache MISS
        │
        ├── Show loading state
        │
        └── Fetch data → Cache → Display
```

### Default Settings

```typescript
// lib/queryClient.ts
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,  // 5 minutes
      gcTime: 30 * 60 * 1000,    // 30 minutes (garbage collection)
      retry: 2,
      refetchOnWindowFocus: true,
    },
  },
});
```

### Benefits

1. **Perceived performance** - Data appears instantly on cache hit
2. **Data freshness** - Background refresh after staleTime
3. **Request deduplication** - Multiple components share one request
4. **Automatic retry** - Failed requests retry automatically
5. **Window focus refetch** - Data refreshes when user returns to tab

## Cache Lifecycle

### When Cache is Populated

- First visit to a collection
- After staleTime expires (background refetch)
- After `invalidateQueries()` call

### When Cache is Updated

- `updateScenes()` - Optimistic updates via `setQueryData`
- Background refetch - Replaces cache with fresh data
- After successful mutation

### When Cache is Invalidated

- Scene CRUD operations (create, delete, rename, duplicate)
- Scene moved/copied between collections
- Manual `invalidateQueries()` call

### When Cache is Cleared

- `gcTime` expires (30 minutes after last use)
- User logs out (clear all queries)

## Cross-Component Communication

React Query handles this automatically through shared cache:

```
┌─────────────────┐    invalidateQueries()   ┌─────────────────┐
│  CollectionView │ ──────────────────────▶  │   QueryClient   │
│  (delete scene) │                          │  (shared cache) │
└─────────────────┘                          └─────────────────┘
                                                      │
                                                      │ Automatic refetch
                                                      ▼
                                             ┌─────────────────┐
                                             │  All subscribed │
                                             │   components    │
                                             │  (auto-update)  │
                                             └─────────────────┘
```

No manual refresh triggers needed - React Query handles it!

## Performance Considerations

### Cache Size

React Query manages cache size automatically:
- Unused queries are garbage collected after `gcTime` (30 min)
- Active queries stay in memory while components are mounted

### Request Deduplication

Multiple components using the same query key share one request:
- `DashboardView` and `SearchResultsView` both use `scenes.list(workspaceId, null)`
- Only one API call is made, both components get the data

### Background Refetch

Background fetches happen when:
- Data is stale (> 5 min old) and component mounts
- Window regains focus
- Network reconnects

## Migration from Jotai Cache

The old Jotai-based cache (`scenesCacheAtom`) has been removed. Here's the mapping:

| Old (Jotai) | New (React Query) |
|-------------|-------------------|
| `scenesCacheAtom` | QueryClient internal cache |
| `setScenesCacheAtom` | `queryClient.setQueryData()` |
| `invalidateScenesCacheAtom` | `queryClient.invalidateQueries()` |
| `clearScenesCacheAtom` | `queryClient.clear()` |
| `scenesRefreshAtom` | Not needed - automatic |
| `triggerScenesRefreshAtom` | `queryClient.invalidateQueries()` |

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-23 | Migrated to React Query from Jotai cache |
| 2025-12-23 | Removed manual cache atoms |
| 2025-12-23 | Added automatic request deduplication |
| 2025-12-23 | Initial implementation with stale-while-revalidate strategy |
