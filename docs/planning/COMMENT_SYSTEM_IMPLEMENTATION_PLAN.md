# Comment System Implementation Plan

This document provides a detailed implementation plan for the Comment System feature in AstraDraw. The system allows users to place threaded comments on specific canvas locations, similar to Excalidraw Plus.

> **Research:** See [COMMENT_SYSTEM_RESEARCH.md](COMMENT_SYSTEM_RESEARCH.md) for UI/UX research, HTML structures, and design decisions.
> **Related:** See [NOTIFICATION_SYSTEM_RESEARCH.md](NOTIFICATION_SYSTEM_RESEARCH.md) for notification integration.

---

## Overview

### Feature Goals

1. **Canvas Comments** - Place comment markers at specific canvas coordinates
2. **Threaded Discussions** - Reply to comments, creating conversation threads
3. **@Mentions** - Tag workspace members in comments
4. **Thread Resolution** - Mark threads as resolved (hides from canvas)
5. **Deep Links** - Share URLs that open specific comments
6. **Real-time Sync** - Comments sync across collaborators via WebSocket
7. **Notifications** - Alert users when mentioned or when new comments appear

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Frontend                                   │
│                                                                     │
│  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │ auth/api/        │    │ hooks/           │    │ components/   │  │
│  │ comments.ts      │───►│ useCommentThreads│───►│ Comments/     │  │
│  │ (API client)     │    │ (React Query)    │    │ (UI)          │  │
│  └──────────────────┘    └──────────────────┘    └───────────────┘  │
│                                                         │           │
│                          ┌──────────────────┐           │           │
│                          │ commentsState.ts │◄──────────┘           │
│                          │ (Jotai atoms)    │                       │
│                          └──────────────────┘                       │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           Backend                                    │
│                                                                     │
│  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │ comments/        │    │ comments.        │    │ Prisma        │  │
│  │ controller.ts    │───►│ service.ts       │───►│ CommentThread │  │
│  │ (REST API)       │    │ (Business logic) │    │ Comment       │  │
│  └──────────────────┘    └──────────────────┘    └───────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Room Service                                  │
│  WebSocket events for real-time sync (comment:created, etc.)        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Backend Foundation

**Goal:** Create database schema and REST API for comment threads and comments.

**Complexity:** M (Medium) | **Estimate:** 2-3 days

### 1.1 Prisma Schema

**File:** `backend/prisma/schema.prisma`

Add two models following the two-model pattern (thread = anchor point, comment = message):

```prisma
// ============================================================================
// Comment Thread - The anchor point on the canvas
// ============================================================================
model CommentThread {
  id              String    @id @default(cuid())
  
  // Scene relationship
  sceneId         String
  scene           Scene     @relation(fields: [sceneId], references: [id], onDelete: Cascade)
  
  // Canvas position (scene coordinates, not viewport)
  x               Float
  y               Float
  
  // Thread status
  resolved        Boolean   @default(false)
  resolvedAt      DateTime?
  resolvedById    String?
  resolvedBy      User?     @relation("ResolvedThreads", fields: [resolvedById], references: [id])
  
  // Thread creator
  createdById     String
  createdBy       User      @relation("CreatedThreads", fields: [createdById], references: [id])
  
  // Comments in this thread
  comments        Comment[]
  
  // Notifications referencing this thread
  notifications   Notification[]
  
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt
  
  @@index([sceneId])
  @@index([createdById])
}

// ============================================================================
// Comment - Individual message in a thread
// ============================================================================
model Comment {
  id              String        @id @default(cuid())
  
  // Thread relationship
  threadId        String
  thread          CommentThread @relation(fields: [threadId], references: [id], onDelete: Cascade)
  
  // Content
  content         String        @db.Text
  
  // Mentions (array of user IDs)
  mentions        String[]      @default([])
  
  // Author
  createdById     String
  createdBy       User          @relation("CreatedComments", fields: [createdById], references: [id])
  
  // Edit tracking
  editedAt        DateTime?
  
  // Notifications referencing this comment
  notifications   Notification[]
  
  createdAt       DateTime      @default(now())
  updatedAt       DateTime      @updatedAt
  
  @@index([threadId])
  @@index([createdById])
}
```

**Update existing models:**

```prisma
// Add to User model
model User {
  // ... existing fields ...
  
  createdThreads    CommentThread[] @relation("CreatedThreads")
  resolvedThreads   CommentThread[] @relation("ResolvedThreads")
  createdComments   Comment[]       @relation("CreatedComments")
}

// Add to Scene model
model Scene {
  // ... existing fields ...
  
  commentThreads    CommentThread[]
}
```

### 1.2 Backend Module Structure

**Directory:** `backend/src/comments/`

```
comments/
├── comments.module.ts          # NestJS module definition
├── comments.controller.ts      # REST endpoints
├── comments.service.ts         # Business logic
└── dto/
    ├── create-thread.dto.ts    # { x, y, content, mentions? }
    ├── create-comment.dto.ts   # { content, mentions? }
    ├── update-thread.dto.ts    # { x?, y? }
    └── update-comment.dto.ts   # { content }
```

### 1.3 API Endpoints

| Method | Endpoint | Purpose | Auth |
|--------|----------|---------|------|
| GET | `/api/v2/scenes/:sceneId/threads` | List threads for scene | VIEW+ |
| POST | `/api/v2/scenes/:sceneId/threads` | Create thread with first comment | EDIT+ |
| GET | `/api/v2/threads/:threadId` | Get thread with all comments | VIEW+ |
| PATCH | `/api/v2/threads/:threadId` | Update thread position | EDIT+ |
| DELETE | `/api/v2/threads/:threadId` | Delete thread and comments | ADMIN or owner |
| POST | `/api/v2/threads/:threadId/resolve` | Mark resolved | EDIT+ |
| POST | `/api/v2/threads/:threadId/reopen` | Reopen thread | EDIT+ |
| POST | `/api/v2/threads/:threadId/comments` | Add reply | EDIT+ |
| PATCH | `/api/v2/comments/:commentId` | Edit comment | Owner only |
| DELETE | `/api/v2/comments/:commentId` | Delete comment | ADMIN or owner |

### 1.4 Request/Response Examples

**Create Thread:**
```typescript
// POST /api/v2/scenes/:sceneId/threads
// Request
{
  "x": 245.5,
  "y": 180.2,
  "content": "This needs to be fixed",
  "mentions": ["user-id-1", "user-id-2"]
}

// Response
{
  "id": "thread-abc123",
  "sceneId": "scene-xyz",
  "x": 245.5,
  "y": 180.2,
  "resolved": false,
  "createdBy": {
    "id": "user-123",
    "name": "Mr. Khachaturov",
    "avatar": "https://..."
  },
  "comments": [{
    "id": "comment-001",
    "content": "This needs to be fixed",
    "mentions": ["user-id-1", "user-id-2"],
    "createdBy": { ... },
    "createdAt": "2025-12-23T15:30:00Z"
  }],
  "commentCount": 1,
  "createdAt": "2025-12-23T15:30:00Z",
  "updatedAt": "2025-12-23T15:30:00Z"
}
```

**List Threads:**
```typescript
// GET /api/v2/scenes/:sceneId/threads?resolved=false&sort=date
// Response
{
  "threads": [...],
  "total": 15
}
```

### 1.5 Permission Guards

Reuse existing guards from `backend/src/auth/`:

```typescript
// comments.controller.ts
@Controller('api/v2')
@UseGuards(JwtAuthGuard)
export class CommentsController {
  
  @Get('scenes/:sceneId/threads')
  async listThreads(
    @Param('sceneId') sceneId: string,
    @CurrentUser() user: User,
    @Query('resolved') resolved?: string,
    @Query('sort') sort?: 'date' | 'unread',
    @Query('fields') fields?: string,
  ) {
    // Check scene access via SceneAccessService
    await this.sceneAccessService.checkAccess(sceneId, user.id, 'VIEW');
    return this.commentsService.listThreads(sceneId, { resolved, sort, fields });
  }
}
```

### 1.6 Field Filtering

Support `?fields=` parameter using existing utility at `backend/src/utils/field-filter.ts`:

```typescript
const ALLOWED_THREAD_FIELDS = [
  'id', 'sceneId', 'x', 'y', 'resolved', 'resolvedAt',
  'resolvedBy', 'createdBy', 'comments', 'commentCount',
  'createdAt', 'updatedAt'
] as const;

// In controller
const fields = parseFields(fieldsParam, ALLOWED_THREAD_FIELDS);
return filterResponseArray(threads, fields);
```

### Acceptance Criteria

- [x] Migration creates CommentThread and Comment tables
- [x] All CRUD endpoints work with proper authentication
- [x] Permission checks enforce VIEW/EDIT/ADMIN access
- [x] Field filtering reduces payload size
- [x] Cascade delete works (scene delete removes threads)
- [ ] Controller tests cover happy path and error cases (deferred)

### Implementation Status ✅

**Completed:** 2025-12-23

**Files Created:**
- `backend/prisma/migrations/20251223165239_add_comments/migration.sql`
- `backend/src/comments/comments.module.ts`
- `backend/src/comments/comments.controller.ts`
- `backend/src/comments/comments.service.ts`
- `backend/src/comments/dto/create-thread.dto.ts`
- `backend/src/comments/dto/create-comment.dto.ts`
- `backend/src/comments/dto/update-thread.dto.ts`
- `backend/src/comments/dto/update-comment.dto.ts`

**Files Modified:**
- `backend/prisma/schema.prisma` - Added CommentThread, Comment models
- `backend/src/app.module.ts` - Imported CommentsModule

### API Testing Results ✅

All endpoints tested successfully via curl against `https://draw.local`:

| Test | Endpoint | Method | Result |
|------|----------|--------|--------|
| List threads (empty) | `/api/v2/scenes/:sceneId/threads` | GET | ✅ Returns `[]` |
| Create thread | `/api/v2/scenes/:sceneId/threads` | POST | ✅ Returns thread with first comment |
| List threads (with data) | `/api/v2/scenes/:sceneId/threads` | GET | ✅ Returns array of threads |
| Add reply | `/api/v2/threads/:threadId/comments` | POST | ✅ Returns new comment |
| Resolve thread | `/api/v2/threads/:threadId/resolve` | POST | ✅ Sets `resolved: true` |
| Reopen thread | `/api/v2/threads/:threadId/reopen` | POST | ✅ Sets `resolved: false` |
| Update position | `/api/v2/threads/:threadId` | PATCH | ✅ Updates x, y coordinates |
| Edit comment | `/api/v2/comments/:commentId` | PATCH | ✅ Updates content, sets `editedAt` |
| Delete comment | `/api/v2/comments/:commentId` | DELETE | ✅ Returns `{ success: true }` |
| Get thread | `/api/v2/threads/:threadId` | GET | ✅ Returns thread with comments |
| Field filtering | `/api/v2/scenes/:sceneId/threads?fields=id,x,y` | GET | ✅ Returns filtered fields only |
| Delete thread | `/api/v2/threads/:threadId` | DELETE | ✅ Returns `{ success: true }` |
| Permission check | `/api/v2/scenes/:sceneId/threads` (no access) | GET | ✅ Returns 403 Forbidden |

**Testing Pattern:**

```bash
# Login to get session cookie
curl -X POST "https://draw.local/api/v2/auth/login/local" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@localhost","password":"admin"}' \
  -k -c /tmp/cookies.txt

# Test endpoints with cookie
curl -X GET "https://draw.local/api/v2/scenes/{sceneId}/threads" \
  -k -b /tmp/cookies.txt

# Create thread
curl -X POST "https://draw.local/api/v2/scenes/{sceneId}/threads" \
  -H "Content-Type: application/json" \
  -d '{"x": 100, "y": 200, "content": "Test comment"}' \
  -k -b /tmp/cookies.txt
```

**Note:** The login endpoint uses `username` field (not `email`) for the email address.

---

## Phase 2: Frontend State & API

**Goal:** Create API client, React Query hooks, and Jotai atoms for comment state.

**Complexity:** M (Medium) | **Estimate:** 1-2 days

**Dependencies:** Phase 1 (Backend)

### 2.1 API Client Module

**File:** `frontend/excalidraw-app/auth/api/comments.ts`

Following existing pattern from `auth/api/scenes.ts`:

```typescript
/**
 * Comments API - CRUD operations for comment threads and comments
 */

import { apiRequest, jsonBody } from "./client";
import type { CommentThread, Comment, CreateThreadDto, CreateCommentDto } from "./types";

// ============================================================================
// Thread Operations
// ============================================================================

export interface ListThreadsOptions {
  resolved?: boolean;
  sort?: 'date' | 'unread';
  fields?: string[];
}

export async function listThreads(
  sceneId: string,
  options?: ListThreadsOptions
): Promise<CommentThread[]> {
  const params = new URLSearchParams();
  if (options?.resolved !== undefined) {
    params.append('resolved', String(options.resolved));
  }
  if (options?.sort) {
    params.append('sort', options.sort);
  }
  if (options?.fields?.length) {
    params.append('fields', options.fields.join(','));
  }
  
  return apiRequest(`/scenes/${sceneId}/threads?${params}`, {
    errorMessage: "Failed to list comment threads",
  });
}

export async function getThread(threadId: string): Promise<CommentThread> {
  return apiRequest(`/threads/${threadId}`, {
    errorMessage: "Failed to get comment thread",
  });
}

export async function createThread(
  sceneId: string,
  dto: CreateThreadDto
): Promise<CommentThread> {
  return apiRequest(`/scenes/${sceneId}/threads`, {
    method: "POST",
    ...jsonBody(dto),
    errorMessage: "Failed to create comment thread",
  });
}

export async function updateThread(
  threadId: string,
  dto: { x?: number; y?: number }
): Promise<CommentThread> {
  return apiRequest(`/threads/${threadId}`, {
    method: "PATCH",
    ...jsonBody(dto),
    errorMessage: "Failed to update thread position",
  });
}

export async function deleteThread(threadId: string): Promise<void> {
  return apiRequest(`/threads/${threadId}`, {
    method: "DELETE",
    errorMessage: "Failed to delete comment thread",
  });
}

export async function resolveThread(threadId: string): Promise<CommentThread> {
  return apiRequest(`/threads/${threadId}/resolve`, {
    method: "POST",
    errorMessage: "Failed to resolve thread",
  });
}

export async function reopenThread(threadId: string): Promise<CommentThread> {
  return apiRequest(`/threads/${threadId}/reopen`, {
    method: "POST",
    errorMessage: "Failed to reopen thread",
  });
}

// ============================================================================
// Comment Operations
// ============================================================================

export async function addComment(
  threadId: string,
  dto: CreateCommentDto
): Promise<Comment> {
  return apiRequest(`/threads/${threadId}/comments`, {
    method: "POST",
    ...jsonBody(dto),
    errorMessage: "Failed to add comment",
  });
}

export async function updateComment(
  commentId: string,
  dto: { content: string }
): Promise<Comment> {
  return apiRequest(`/comments/${commentId}`, {
    method: "PATCH",
    ...jsonBody(dto),
    errorMessage: "Failed to update comment",
  });
}

export async function deleteComment(commentId: string): Promise<void> {
  return apiRequest(`/comments/${commentId}`, {
    method: "DELETE",
    errorMessage: "Failed to delete comment",
  });
}
```

### 2.2 TypeScript Interfaces

**File:** `frontend/excalidraw-app/auth/api/types.ts`

Add to existing types file:

```typescript
// ============================================================================
// Comment System Types
// ============================================================================

export interface UserSummary {
  id: string;
  name: string;
  avatar?: string;
}

export interface CommentThread {
  id: string;
  sceneId: string;
  x: number;
  y: number;
  resolved: boolean;
  resolvedAt?: string;
  resolvedBy?: UserSummary;
  createdBy: UserSummary;
  comments: Comment[];
  commentCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface Comment {
  id: string;
  threadId: string;
  content: string;
  mentions: string[];
  createdBy: UserSummary;
  editedAt?: string;
  createdAt: string;
}

export interface CreateThreadDto {
  x: number;
  y: number;
  content: string;
  mentions?: string[];
}

export interface CreateCommentDto {
  content: string;
  mentions?: string[];
}

export interface ThreadFilters {
  resolved?: boolean;
  sort: 'date' | 'unread';
  search: string;
}
```

### 2.3 Query Keys

**File:** `frontend/excalidraw-app/lib/queryClient.ts`

Add to existing query key factory:

```typescript
export const queryKeys = {
  // ... existing keys ...
  
  // Comment Threads
  commentThreads: {
    all: ["commentThreads"] as const,
    list: (sceneId: string) => ["commentThreads", sceneId] as const,
    detail: (threadId: string) => ["commentThreads", "detail", threadId] as const,
  },
  
  // Mutations
  mutations: {
    // ... existing ...
    createThread: ["createThread"] as const,
    resolveThread: ["resolveThread"] as const,
    addComment: ["addComment"] as const,
  },
} as const;
```

### 2.4 React Query Hooks

**File:** `frontend/excalidraw-app/hooks/useCommentThreads.ts`

```typescript
import { useCallback } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { queryKeys } from "../lib/queryClient";
import {
  listThreads,
  createThread,
  deleteThread,
  resolveThread,
  reopenThread,
  addComment,
} from "../auth/api/comments";
import type { CommentThread, CreateThreadDto, CreateCommentDto } from "../auth/api/types";

interface UseThreadsOptions {
  sceneId: string | undefined;
  enabled?: boolean;
}

interface UseThreadsResult {
  threads: CommentThread[];
  isLoading: boolean;
  error: Error | null;
  refetch: () => Promise<void>;
}

/**
 * Hook for fetching comment threads with React Query caching.
 */
export function useCommentThreads({
  sceneId,
  enabled = true,
}: UseThreadsOptions): UseThreadsResult {
  const {
    data: threads = [],
    isLoading,
    error,
    refetch: queryRefetch,
  } = useQuery({
    queryKey: sceneId ? queryKeys.commentThreads.list(sceneId) : ["disabled"],
    queryFn: () => listThreads(sceneId!),
    enabled: enabled && !!sceneId,
    staleTime: 2 * 60 * 1000, // 2 minutes (comments change more frequently)
  });

  const refetch = useCallback(async () => {
    await queryRefetch();
  }, [queryRefetch]);

  return {
    threads,
    isLoading,
    error: error as Error | null,
    refetch,
  };
}

/**
 * Hook for comment thread mutations with optimistic updates.
 */
export function useCommentMutations(sceneId: string | undefined) {
  const queryClient = useQueryClient();
  const queryKey = sceneId ? queryKeys.commentThreads.list(sceneId) : ["disabled"];

  // Create thread mutation
  const createMutation = useMutation({
    mutationFn: (dto: CreateThreadDto) => createThread(sceneId!, dto),
    onSuccess: (newThread) => {
      queryClient.setQueryData<CommentThread[]>(queryKey, (prev) =>
        prev ? [...prev, newThread] : [newThread]
      );
    },
  });

  // Delete thread mutation with optimistic update
  const deleteMutation = useMutation({
    mutationFn: deleteThread,
    onMutate: async (threadId) => {
      await queryClient.cancelQueries({ queryKey });
      const previous = queryClient.getQueryData<CommentThread[]>(queryKey);
      queryClient.setQueryData<CommentThread[]>(queryKey, (prev) =>
        prev?.filter((t) => t.id !== threadId) ?? []
      );
      return { previous };
    },
    onError: (err, threadId, context) => {
      queryClient.setQueryData(queryKey, context?.previous);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.commentThreads.all });
    },
  });

  // Resolve/reopen thread mutation
  const resolveMutation = useMutation({
    mutationFn: ({ threadId, resolved }: { threadId: string; resolved: boolean }) =>
      resolved ? reopenThread(threadId) : resolveThread(threadId),
    onSuccess: (updatedThread) => {
      queryClient.setQueryData<CommentThread[]>(queryKey, (prev) =>
        prev?.map((t) => (t.id === updatedThread.id ? updatedThread : t)) ?? []
      );
    },
  });

  // Add comment mutation
  const addCommentMutation = useMutation({
    mutationFn: ({ threadId, dto }: { threadId: string; dto: CreateCommentDto }) =>
      addComment(threadId, dto),
    onSuccess: (newComment, { threadId }) => {
      queryClient.setQueryData<CommentThread[]>(queryKey, (prev) =>
        prev?.map((t) =>
          t.id === threadId
            ? { ...t, comments: [...t.comments, newComment], commentCount: t.commentCount + 1 }
            : t
        ) ?? []
      );
    },
  });

  return {
    createThread: createMutation.mutateAsync,
    deleteThread: deleteMutation.mutateAsync,
    toggleResolved: resolveMutation.mutateAsync,
    addComment: addCommentMutation.mutateAsync,
    isCreating: createMutation.isPending,
    isDeleting: deleteMutation.isPending,
  };
}
```

### 2.5 Jotai Atoms

**File:** `frontend/excalidraw-app/components/Comments/commentsState.ts`

```typescript
import { atom } from "jotai";
import { openSidebarAtom } from "../Settings/settingsState";
import type { ThreadFilters } from "../../auth/api/types";

// ============================================================================
// UI State Atoms
// ============================================================================

/** Currently selected thread ID (for popup display) */
export const selectedThreadIdAtom = atom<string | null>(null);

/** Whether comment creation mode is active (cursor shows comment icon) */
export const isCommentModeAtom = atom<boolean>(false);

/** Filter and sort settings for sidebar */
export const commentFiltersAtom = atom<ThreadFilters>({
  resolved: undefined, // undefined = show all
  sort: 'date',
  search: '',
});

// ============================================================================
// Derived Atoms
// ============================================================================

/** Whether the comments sidebar tab is currently open */
export const isCommentsSidebarOpenAtom = atom((get) => {
  const openSidebar = get(openSidebarAtom);
  return openSidebar?.name === 'default' && openSidebar?.tab === 'comments';
});

// ============================================================================
// Action Atoms
// ============================================================================

/** Clear comment selection (e.g., when closing popup) */
export const clearCommentSelectionAtom = atom(null, (get, set) => {
  set(selectedThreadIdAtom, null);
  set(isCommentModeAtom, false);
});

/** Toggle comment mode on/off */
export const toggleCommentModeAtom = atom(null, (get, set) => {
  const current = get(isCommentModeAtom);
  set(isCommentModeAtom, !current);
  if (current) {
    // Exiting comment mode - clear selection
    set(selectedThreadIdAtom, null);
  }
});
```

### Acceptance Criteria

- [x] API client functions match all backend endpoints
- [x] TypeScript interfaces match backend DTOs
- [x] React Query hooks fetch and cache threads correctly
- [x] Optimistic updates work for create/delete/resolve
- [x] Jotai atoms manage UI state (selected thread, comment mode)
- [x] Query keys added to queryClient.ts
- [x] Re-export from auth/api/index.ts

### Implementation Status ✅

**Completed:** 2025-12-23

**Files Created:**
- `frontend/excalidraw-app/auth/api/comments.ts` - API client with all endpoint functions
- `frontend/excalidraw-app/hooks/useCommentThreads.ts` - React Query hooks for fetching and mutations
- `frontend/excalidraw-app/components/Comments/commentsState.ts` - Jotai atoms for UI state
- `frontend/excalidraw-app/components/Comments/index.ts` - Module exports

**Files Modified:**
- `frontend/excalidraw-app/auth/api/types.ts` - Added comment system TypeScript interfaces
- `frontend/excalidraw-app/auth/api/index.ts` - Added comments API re-exports
- `frontend/excalidraw-app/lib/queryClient.ts` - Added commentThreads query keys

**Key Implementation Details:**
- API client uses existing `apiRequest` helper with automatic credential handling
- React Query hooks use 2-minute stale time (shorter than scenes' 5 minutes)
- Optimistic updates for delete/resolve operations with rollback on error
- Jotai atoms for: selectedThreadId, isCommentMode, commentFilters, pendingCommentPosition

---

## Phase 3: Canvas Integration

**Goal:** Render comment markers on canvas as HTML overlay, handle positioning during pan/zoom.

**Complexity:** L (Large) | **Estimate:** 2-3 days

**Dependencies:** Phase 2 (Frontend State)

### 3.1 Component Structure

**Directory:** `frontend/excalidraw-app/components/Comments/`

```
Comments/
├── index.ts                      # Public exports
├── types.ts                      # Component-specific types
├── commentsState.ts              # Jotai atoms (from Phase 2)
│
├── # Canvas Layer
├── ThreadMarkersLayer.tsx        # Container for all markers
├── ThreadMarkersLayer.module.scss
├── ThreadMarker.tsx              # Single marker (pin with avatar)
├── ThreadMarker.module.scss
├── ThreadMarkerTooltip.tsx       # Hover tooltip with preview
├── CommentCreationOverlay.tsx    # Click-to-create cursor mode
│
├── # Popup (Phase 4)
├── ThreadPopup.tsx
├── ...
│
└── # Sidebar (Phase 5)
└── CommentsSidebar.tsx
```

### 3.2 ThreadMarkersLayer Component

**File:** `frontend/excalidraw-app/components/Comments/ThreadMarkersLayer.tsx`

```typescript
import React, { useMemo } from "react";
import { useAtomValue } from "jotai";
import { sceneCoordsToViewportCoords } from "@excalidraw/excalidraw";
import { ThreadMarker } from "./ThreadMarker";
import { selectedThreadIdAtom } from "./commentsState";
import type { CommentThread } from "../../auth/api/types";
import type { AppState } from "@excalidraw/excalidraw/types";
import styles from "./ThreadMarkersLayer.module.scss";

interface Props {
  threads: CommentThread[];
  appState: AppState;
  onThreadClick: (threadId: string) => void;
}

export const ThreadMarkersLayer: React.FC<Props> = ({
  threads,
  appState,
  onThreadClick,
}) => {
  const selectedThreadId = useAtomValue(selectedThreadIdAtom);
  
  // Filter out resolved threads (they don't show on canvas)
  const visibleThreads = useMemo(
    () => threads.filter((t) => !t.resolved),
    [threads]
  );

  return (
    <div className={styles.layer}>
      {visibleThreads.map((thread) => {
        const { x, y } = sceneCoordsToViewportCoords(
          { sceneX: thread.x, sceneY: thread.y },
          appState
        );
        
        return (
          <ThreadMarker
            key={thread.id}
            thread={thread}
            isSelected={thread.id === selectedThreadId}
            position={{ x, y }}
            onClick={() => onThreadClick(thread.id)}
          />
        );
      })}
    </div>
  );
};
```

**Styles:** `ThreadMarkersLayer.module.scss`

```scss
@use "../../styles/mixins" as *;

.layer {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  pointer-events: none; // Allow clicks to pass through to canvas
  z-index: 3; // Above canvas, below UI
  
  // Markers themselves need pointer events
  > * {
    pointer-events: auto;
  }
}
```

### 3.3 ThreadMarker Component

**File:** `frontend/excalidraw-app/components/Comments/ThreadMarker.tsx`

```typescript
import React, { useState } from "react";
import { ThreadMarkerTooltip } from "./ThreadMarkerTooltip";
import type { CommentThread } from "../../auth/api/types";
import styles from "./ThreadMarker.module.scss";

interface Props {
  thread: CommentThread;
  isSelected: boolean;
  position: { x: number; y: number };
  onClick: () => void;
}

export const ThreadMarker: React.FC<Props> = ({
  thread,
  isSelected,
  position,
  onClick,
}) => {
  const [isHovered, setIsHovered] = useState(false);

  return (
    <div
      className={`${styles.marker} ${isSelected ? styles.selected : ""}`}
      style={{
        left: position.x,
        top: position.y,
        transform: "translate(-50%, -100%)", // Anchor at bottom center
      }}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      onClick={onClick}
    >
      <div className={styles.pin}>
        <img
          src={thread.createdBy.avatar || "/default-avatar.png"}
          alt={thread.createdBy.name}
          className={styles.avatar}
        />
      </div>
      
      {isHovered && !isSelected && (
        <ThreadMarkerTooltip thread={thread} />
      )}
    </div>
  );
};
```

**Styles:** `ThreadMarker.module.scss`

```scss
@use "../../styles/mixins" as *;

.marker {
  position: absolute;
  cursor: pointer;
  z-index: 3;
  touch-none;
  user-select: none;
  
  &:hover {
    z-index: 20;
  }
  
  &.selected {
    z-index: 21;
  }
}

.pin {
  display: flex;
  padding: 2px;
  background: var(--color-surface-low);
  border-radius: 66px 67px 67px 0; // Pin shape: rounded top, flat bottom-left
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
  transition: transform 0.2s, box-shadow 0.2s;
  
  &:hover {
    transform: scale(1.03);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
  }
}

.avatar {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  border: 1px solid var(--color-surface-lowest);
  pointer-events: none;
}

@include dark-mode {
  .pin {
    background: var(--color-surface-high);
  }
}
```

### 3.4 Comment Mode Activation

Add keyboard shortcut handler to `useKeyboardShortcuts.ts`:

```typescript
// In useKeyboardShortcuts.ts
import { toggleCommentModeAtom } from "../components/Comments/commentsState";

// Add to keyboard handler
case "c":
case "C":
  if (!event.ctrlKey && !event.metaKey && !event.altKey) {
    event.preventDefault();
    setToggleCommentMode();
  }
  break;
```

### 3.5 CommentCreationOverlay

**File:** `frontend/excalidraw-app/components/Comments/CommentCreationOverlay.tsx`

```typescript
import React from "react";
import { useAtomValue, useSetAtom } from "jotai";
import { viewportCoordsToSceneCoords } from "@excalidraw/excalidraw";
import { isCommentModeAtom, toggleCommentModeAtom } from "./commentsState";
import type { AppState } from "@excalidraw/excalidraw/types";
import styles from "./CommentCreationOverlay.module.scss";

interface Props {
  appState: AppState;
  onCreateComment: (x: number, y: number) => void;
}

export const CommentCreationOverlay: React.FC<Props> = ({
  appState,
  onCreateComment,
}) => {
  const isCommentMode = useAtomValue(isCommentModeAtom);
  const toggleCommentMode = useSetAtom(toggleCommentModeAtom);

  if (!isCommentMode) return null;

  const handleClick = (e: React.MouseEvent) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const viewportX = e.clientX - rect.left;
    const viewportY = e.clientY - rect.top;
    
    // Convert to scene coordinates
    const { x, y } = viewportCoordsToSceneCoords(
      { clientX: viewportX, clientY: viewportY },
      appState
    );
    
    onCreateComment(x, y);
    toggleCommentMode(); // Exit comment mode after creating
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Escape") {
      toggleCommentMode();
    }
  };

  return (
    <div
      className={styles.overlay}
      onClick={handleClick}
      onKeyDown={handleKeyDown}
      tabIndex={0}
    />
  );
};
```

### 3.6 Integration with App.tsx

Add to `App.tsx` via Excalidraw's `children` prop:

```typescript
// In App.tsx render
<Excalidraw
  // ... existing props
>
  {currentSceneId && (
    <>
      <ThreadMarkersLayer
        threads={threads}
        appState={excalidrawAPI?.getAppState()}
        onThreadClick={handleThreadClick}
      />
      <CommentCreationOverlay
        appState={excalidrawAPI?.getAppState()}
        onCreateComment={handleCreateComment}
      />
      <ThreadPopup /> {/* Phase 4 */}
    </>
  )}
</Excalidraw>
```

### Acceptance Criteria

- [x] Markers render at correct canvas positions
- [x] Markers update position on pan/zoom (subscribe to appState changes)
- [x] Resolved markers are hidden from canvas
- [x] Hover shows tooltip with preview (author, text, count)
- [x] Click opens thread popup (sets selectedThreadIdAtom)
- [x] C hotkey activates comment mode
- [x] Comment mode shows cursor feedback
- [x] Click-to-create converts viewport to scene coords correctly
- [x] ESC exits comment mode

### Implementation Status ✅

**Completed:** 2025-12-23

**Files Created:**
- `frontend/excalidraw-app/components/Comments/ThreadMarkersLayer/ThreadMarkersLayer.tsx` - Canvas overlay container
- `frontend/excalidraw-app/components/Comments/ThreadMarkersLayer/ThreadMarkersLayer.module.scss` - Overlay styles
- `frontend/excalidraw-app/components/Comments/ThreadMarker/ThreadMarker.tsx` - Single pin marker with avatar
- `frontend/excalidraw-app/components/Comments/ThreadMarker/ThreadMarker.module.scss` - Pin shape, hover effects
- `frontend/excalidraw-app/components/Comments/ThreadMarkerTooltip/ThreadMarkerTooltip.tsx` - Hover preview
- `frontend/excalidraw-app/components/Comments/ThreadMarkerTooltip/ThreadMarkerTooltip.module.scss` - Tooltip styles
- `frontend/excalidraw-app/components/Comments/CommentCreationOverlay/CommentCreationOverlay.tsx` - Click-to-create mode
- `frontend/excalidraw-app/components/Comments/CommentCreationOverlay/CommentCreationOverlay.module.scss` - Custom cursor, hint

**Files Modified:**
- `frontend/excalidraw-app/hooks/useKeyboardShortcuts.ts` - Added C hotkey for comment mode toggle
- `frontend/excalidraw-app/App.tsx` - Integrated ThreadMarkersLayer and CommentCreationOverlay
- `frontend/excalidraw-app/components/Comments/index.ts` - Added exports for new components

**Key Implementation Details:**
- Uses `sceneCoordsToViewportCoords` from `@excalidraw/common` for marker positioning
- Uses `viewportCoordsToSceneCoords` for click-to-create coordinate conversion
- React Query fetches threads with `resolved: false` filter for canvas markers
- Pin shape uses asymmetric border-radius (`66px 67px 67px 0`) rotated -45deg
- Z-index layering: markers at z-3, hover bumps to z-20
- Full dark mode support using `@include dark-mode` mixin
- ESC key cancels comment mode via capture phase event listener
- C hotkey only triggers when authenticated, on a scene, and not typing in inputs

---

## Phase 4: Comment Popup

**Goal:** Thread popup component for viewing/replying to comments.

**Complexity:** L (Large) | **Estimate:** 2-3 days

**Dependencies:** Phase 3 (Canvas Integration)

### 4.1 Component Structure

```
Comments/
├── ThreadPopup.tsx               # Main popup container
├── ThreadPopup.module.scss
├── ThreadPopupHeader.tsx         # Navigation + actions
├── CommentItem.tsx               # Single comment display
├── CommentInput.tsx              # Reply input with emoji/mention
└── MentionInput.tsx              # @mention autocomplete
```

### 4.2 ThreadPopup Component

**File:** `frontend/excalidraw-app/components/Comments/ThreadPopup.tsx`

```typescript
import React, { useRef, useEffect } from "react";
import { useAtomValue, useSetAtom } from "jotai";
import { selectedThreadIdAtom, clearCommentSelectionAtom } from "./commentsState";
import { useCommentThreads, useCommentMutations } from "../../hooks/useCommentThreads";
import { ThreadPopupHeader } from "./ThreadPopupHeader";
import { CommentItem } from "./CommentItem";
import { CommentInput } from "./CommentInput";
import styles from "./ThreadPopup.module.scss";

interface Props {
  sceneId: string;
  threads: CommentThread[];
}

export const ThreadPopup: React.FC<Props> = ({ sceneId, threads }) => {
  const selectedThreadId = useAtomValue(selectedThreadIdAtom);
  const clearSelection = useSetAtom(clearCommentSelectionAtom);
  const commentsRef = useRef<HTMLDivElement>(null);
  
  const thread = threads.find((t) => t.id === selectedThreadId);
  const { toggleResolved, addComment } = useCommentMutations(sceneId);

  // Find current thread index for navigation
  const visibleThreads = threads.filter((t) => !t.resolved);
  const currentIndex = visibleThreads.findIndex((t) => t.id === selectedThreadId);

  if (!selectedThreadId || !thread) return null;

  const handleNavigate = (direction: 'prev' | 'next') => {
    const newIndex = direction === 'prev' 
      ? (currentIndex - 1 + visibleThreads.length) % visibleThreads.length
      : (currentIndex + 1) % visibleThreads.length;
    setSelectedThreadId(visibleThreads[newIndex].id);
  };

  const handleReply = async (content: string, mentions: string[]) => {
    await addComment({ threadId: thread.id, dto: { content, mentions } });
    // Scroll to bottom after adding comment
    commentsRef.current?.scrollTo({ top: commentsRef.current.scrollHeight });
  };

  return (
    <div className={styles.popup}>
      <ThreadPopupHeader
        thread={thread}
        canNavigate={visibleThreads.length > 1}
        onNavigate={handleNavigate}
        onResolve={() => toggleResolved({ threadId: thread.id, resolved: thread.resolved })}
        onCopyLink={() => copyThreadLink(thread.id)}
        onDelete={() => handleDeleteThread(thread.id)}
        onClose={clearSelection}
      />
      
      <div className={styles.comments} ref={commentsRef}>
        {thread.comments.map((comment) => (
          <CommentItem key={comment.id} comment={comment} />
        ))}
      </div>
      
      <CommentInput onSubmit={handleReply} />
      
      {thread.resolved && (
        <div className={styles.resolvedBanner}>
          <span className={styles.checkIcon}>✓</span>
          This thread was resolved
        </div>
      )}
    </div>
  );
};
```

### 4.3 Key Features

**Navigation buttons (< >):**
```typescript
<button onClick={() => onNavigate('prev')} disabled={!canNavigate}>
  <ChevronLeftIcon />
</button>
<button onClick={() => onNavigate('next')} disabled={!canNavigate}>
  <ChevronRightIcon />
</button>
```

**Resolve/Reopen toggle:**
```typescript
<button 
  className={`${styles.resolveBtn} ${thread.resolved ? styles.active : ""}`}
  onClick={onResolve}
>
  <CheckIcon />
</button>
```

**Copy link:**
```typescript
const copyThreadLink = async (threadId: string) => {
  const url = buildSceneUrlWithThread(workspaceSlug, sceneId, threadId);
  await navigator.clipboard.writeText(url);
  showSuccess(t("comments.linkCopied"));
};
```

### 4.4 Deep Links

**Update router.ts:**

```typescript
// Add to RouteType
| { type: "scene"; workspaceSlug: string; sceneId: string; threadId?: string; commentId?: string }

// Update parseUrl to extract query params
const params = new URLSearchParams(urlObj.search);
const threadId = params.get("thread") || undefined;
const commentId = params.get("comment") || undefined;

// Add URL builder
export function buildSceneUrlWithThread(
  workspaceSlug: string,
  sceneId: string,
  threadId: string,
  commentId?: string,
): string {
  let url = `/workspace/${encodeURIComponent(workspaceSlug)}/scene/${encodeURIComponent(sceneId)}?thread=${encodeURIComponent(threadId)}`;
  if (commentId) {
    url += `&comment=${encodeURIComponent(commentId)}`;
  }
  return url;
}
```

**Handle deep link in App.tsx:**

```typescript
// In useUrlRouting hook
useEffect(() => {
  const route = parseUrl();
  if (route.type === "scene" && route.threadId) {
    // Open comments sidebar
    setOpenSidebar({ name: "default", tab: "comments" });
    // Select the thread
    setSelectedThreadId(route.threadId);
    // Pan canvas to thread position (after threads load)
    // Scroll to specific comment if commentId provided
  }
}, []);
```

### 4.5 @Mention Input

**File:** `frontend/excalidraw-app/components/Comments/MentionInput.tsx`

```typescript
import React, { useState, useRef } from "react";
import { useWorkspaceMembers } from "../../hooks/useWorkspaceMembers";

interface Props {
  value: string;
  onChange: (value: string, mentions: string[]) => void;
  placeholder?: string;
}

export const MentionInput: React.FC<Props> = ({ value, onChange, placeholder }) => {
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [mentionQuery, setMentionQuery] = useState("");
  const { members } = useWorkspaceMembers();
  
  const handleInput = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const text = e.target.value;
    // Detect @ trigger
    const lastAtIndex = text.lastIndexOf("@");
    if (lastAtIndex !== -1 && lastAtIndex === text.length - 1) {
      setShowSuggestions(true);
    }
    // Extract mentions from text
    const mentionPattern = /@\[([^\]]+)\]\(([^)]+)\)/g;
    const mentions: string[] = [];
    let match;
    while ((match = mentionPattern.exec(text)) !== null) {
      mentions.push(match[2]); // User ID
    }
    onChange(text, mentions);
  };

  const handleSelectMember = (member: Member) => {
    // Insert mention in format: @[Name](userId)
    const mention = `@[${member.name}](${member.id})`;
    onChange(value + mention, [...extractMentions(value), member.id]);
    setShowSuggestions(false);
  };

  return (
    <div className={styles.mentionInput}>
      <textarea
        value={value}
        onChange={handleInput}
        placeholder={placeholder}
        onKeyDown={(e) => e.stopPropagation()} // Prevent canvas shortcuts
      />
      {showSuggestions && (
        <div className={styles.suggestions}>
          {members
            .filter((m) => m.name.toLowerCase().includes(mentionQuery.toLowerCase()))
            .map((member) => (
              <button key={member.id} onClick={() => handleSelectMember(member)}>
                <img src={member.avatar} alt="" />
                {member.name}
              </button>
            ))}
        </div>
      )}
    </div>
  );
};
```

### Acceptance Criteria

- [ ] Popup displays thread with all comments
- [ ] Reply input works with @mentions
- [ ] @mention shows autocomplete dropdown with workspace members
- [ ] Resolve/reopen updates thread state immediately
- [ ] Copy link generates correct deep link URL
- [ ] Navigation buttons cycle through visible threads
- [ ] Deep link opens scene, selects thread, scrolls to comment
- [ ] Close button clears selection
- [ ] Scrollable comments area (max-height: 230px)
- [ ] Reply input always visible at bottom

---

## Phase 5: Sidebar Panel

**Goal:** Comments tab in AppSidebar with search, filter, and thread list.

**Complexity:** M (Medium) | **Estimate:** 1-2 days

**Dependencies:** Phase 2 (Frontend State)

### 5.1 Component Structure

```
Comments/
├── CommentsSidebar.tsx           # Main sidebar panel
├── CommentsSidebar.module.scss
├── CommentsSidebarHeader.tsx     # Search + filter controls
├── ThreadListItem.tsx            # Single thread in list
└── ThreadList.tsx                # Scrollable list
```

### 5.2 CommentsSidebar Component

**File:** `frontend/excalidraw-app/components/Comments/CommentsSidebar.tsx`

```typescript
import React, { useMemo } from "react";
import { useAtom, useSetAtom } from "jotai";
import { commentFiltersAtom, selectedThreadIdAtom } from "./commentsState";
import { useCommentThreads } from "../../hooks/useCommentThreads";
import { CommentsSidebarHeader } from "./CommentsSidebarHeader";
import { ThreadListItem } from "./ThreadListItem";
import styles from "./CommentsSidebar.module.scss";

interface Props {
  sceneId: string | undefined;
}

export const CommentsSidebar: React.FC<Props> = ({ sceneId }) => {
  const { threads, isLoading } = useCommentThreads({ sceneId, enabled: !!sceneId });
  const [filters, setFilters] = useAtom(commentFiltersAtom);
  const setSelectedThread = useSetAtom(selectedThreadIdAtom);

  // Filter and sort threads
  const filteredThreads = useMemo(() => {
    let result = [...threads];
    
    // Filter by resolved status
    if (filters.resolved !== undefined) {
      result = result.filter((t) => t.resolved === filters.resolved);
    }
    
    // Filter by search query
    if (filters.search) {
      const query = filters.search.toLowerCase();
      result = result.filter((t) =>
        t.comments.some((c) => c.content.toLowerCase().includes(query))
      );
    }
    
    // Sort
    if (filters.sort === 'date') {
      result.sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
    }
    // TODO: Sort by unread requires tracking read status
    
    return result;
  }, [threads, filters]);

  const handleThreadClick = (threadId: string) => {
    setSelectedThread(threadId);
    // TODO: Pan canvas to thread position
  };

  if (!sceneId) {
    return (
      <div className={styles.empty}>
        <p>Open a scene to view comments</p>
      </div>
    );
  }

  return (
    <div className={styles.sidebar}>
      <CommentsSidebarHeader
        filters={filters}
        onFiltersChange={setFilters}
      />
      
      <div className={styles.list}>
        {isLoading ? (
          <ThreadListSkeleton count={3} />
        ) : filteredThreads.length === 0 ? (
          <div className={styles.empty}>
            <p>No comments yet</p>
          </div>
        ) : (
          filteredThreads.map((thread) => (
            <ThreadListItem
              key={thread.id}
              thread={thread}
              searchQuery={filters.search}
              onClick={() => handleThreadClick(thread.id)}
            />
          ))
        )}
      </div>
    </div>
  );
};
```

### 5.3 Replace AppSidebar Placeholder

**Update:** `frontend/excalidraw-app/components/AppSidebar/AppSidebar.tsx`

```typescript
// Replace placeholder content
<Sidebar.Tab tab="comments">
  {currentSceneId ? (
    <CommentsSidebar sceneId={currentSceneId} />
  ) : (
    <div className={styles.promoContainer}>
      <div className={styles.promoImage} />
      <div className={styles.promoText}>{t("comments.promoTitle")}</div>
      <div className={styles.promoComingSoon}>{t("comments.openScene")}</div>
    </div>
  )}
</Sidebar.Tab>
```

### 5.4 Footer Button

**File:** `frontend/excalidraw-app/components/Comments/CommentsFooterButton.tsx`

```typescript
import React from "react";
import { useSetAtom } from "jotai";
import { openSidebarAtom } from "../Settings/settingsState";
import { Tooltip } from "@excalidraw/excalidraw";
import { useTranslation } from "react-i18next";
import styles from "./CommentsFooterButton.module.scss";

export const CommentsFooterButton: React.FC = () => {
  const { t } = useTranslation();
  const setOpenSidebar = useSetAtom(openSidebarAtom);

  const handleClick = () => {
    setOpenSidebar({ name: "default", tab: "comments" });
  };

  return (
    <Tooltip label={`${t("comments.addComment")} — C`}>
      <button
        type="button"
        className={styles.button}
        onClick={handleClick}
      >
        <CommentIcon />
      </button>
    </Tooltip>
  );
};
```

**Add to AppFooter.tsx:**

```typescript
// In AppFooter component
<CommentsFooterButton />
```

### 5.5 Search with Highlighting

**In ThreadListItem:**

```typescript
const highlightText = (text: string, query: string) => {
  if (!query) return text;
  const parts = text.split(new RegExp(`(${query})`, 'gi'));
  return parts.map((part, i) =>
    part.toLowerCase() === query.toLowerCase() ? (
      <mark key={i} className={styles.highlight}>{part}</mark>
    ) : part
  );
};
```

### Acceptance Criteria

- [ ] Comments tab shows thread list when scene is open
- [ ] Search filters threads in real-time with highlighting
- [ ] Sort by date works (newest first)
- [ ] Show resolved toggle includes/excludes resolved threads
- [ ] Click on thread navigates to position on canvas
- [ ] Click on thread opens popup
- [ ] Footer button toggles comments sidebar
- [ ] Empty state shown when no comments
- [ ] Loading skeleton while fetching

---

## Phase 6: Real-time Sync (Optional)

**Goal:** Sync comments in real-time during collaboration via room-service WebSocket.

**Complexity:** M (Medium) | **Estimate:** 1-2 days

**Dependencies:** Phase 4 (Comment Popup)

### 6.1 WebSocket Events

**Add to room-service protocol:**

```typescript
// room-service/src/index.ts

// New event types
type CommentEvent =
  | { type: 'comment:thread-created'; thread: CommentThread }
  | { type: 'comment:thread-resolved'; threadId: string; resolved: boolean }
  | { type: 'comment:thread-deleted'; threadId: string }
  | { type: 'comment:added'; threadId: string; comment: Comment }
  | { type: 'comment:updated'; commentId: string; content: string }
  | { type: 'comment:deleted'; threadId: string; commentId: string };

// Relay comment events to room
socket.on('comment:event', (data: CommentEvent) => {
  socket.to(roomId).emit('comment:event', data);
});
```

### 6.2 Frontend Integration

**In Collab.tsx or dedicated hook:**

```typescript
// useCommentSync.ts
import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { queryKeys } from "../lib/queryClient";

export function useCommentSync(sceneId: string | undefined, socket: Socket | null) {
  const queryClient = useQueryClient();

  useEffect(() => {
    if (!socket || !sceneId) return;

    const handleCommentEvent = (event: CommentEvent) => {
      const queryKey = queryKeys.commentThreads.list(sceneId);

      switch (event.type) {
        case 'comment:thread-created':
          queryClient.setQueryData<CommentThread[]>(queryKey, (prev) =>
            prev ? [...prev, event.thread] : [event.thread]
          );
          break;

        case 'comment:thread-resolved':
          queryClient.setQueryData<CommentThread[]>(queryKey, (prev) =>
            prev?.map((t) =>
              t.id === event.threadId ? { ...t, resolved: event.resolved } : t
            ) ?? []
          );
          break;

        case 'comment:thread-deleted':
          queryClient.setQueryData<CommentThread[]>(queryKey, (prev) =>
            prev?.filter((t) => t.id !== event.threadId) ?? []
          );
          break;

        case 'comment:added':
          queryClient.setQueryData<CommentThread[]>(queryKey, (prev) =>
            prev?.map((t) =>
              t.id === event.threadId
                ? { ...t, comments: [...t.comments, event.comment] }
                : t
            ) ?? []
          );
          break;
      }
    };

    socket.on('comment:event', handleCommentEvent);
    return () => {
      socket.off('comment:event', handleCommentEvent);
    };
  }, [socket, sceneId, queryClient]);
}
```

### 6.3 Emit Events on Mutations

**Update useCommentMutations:**

```typescript
const createMutation = useMutation({
  mutationFn: (dto: CreateThreadDto) => createThread(sceneId!, dto),
  onSuccess: (newThread) => {
    // Update local cache
    queryClient.setQueryData<CommentThread[]>(queryKey, (prev) =>
      prev ? [...prev, newThread] : [newThread]
    );
    // Broadcast to collaborators
    if (socket) {
      socket.emit('comment:event', {
        type: 'comment:thread-created',
        thread: newThread,
      });
    }
  },
});
```

### Acceptance Criteria

- [ ] New threads appear for all collaborators
- [ ] Resolved status syncs across clients
- [ ] Deleted threads disappear for all
- [ ] New comments appear in real-time
- [ ] No duplicate updates (optimistic + WebSocket)

---

## Phase 7: Notification Integration

**Goal:** Connect comments to notification system for @mentions and new comments.

**Complexity:** S (Small) | **Estimate:** 0.5-1 day

**Dependencies:** Phase 4 (Comment Popup), Notification System

### 7.1 Backend Integration

**In comments.service.ts:**

```typescript
async addComment(threadId: string, dto: CreateCommentDto, userId: string) {
  const thread = await this.prisma.commentThread.findUnique({
    where: { id: threadId },
    include: { scene: true },
  });

  const comment = await this.prisma.comment.create({
    data: {
      threadId,
      content: dto.content,
      mentions: dto.mentions ?? [],
      createdById: userId,
    },
    include: { createdBy: true },
  });

  // Create MENTION notifications for @mentioned users
  if (dto.mentions?.length) {
    await this.notificationService.createBatch(
      dto.mentions.map((mentionedUserId) => ({
        type: 'MENTION',
        userId: mentionedUserId,
        actorId: userId,
        threadId,
        commentId: comment.id,
        sceneId: thread.sceneId,
      }))
    );
  }

  // Create COMMENT notifications for thread participants (except author)
  const participants = await this.getThreadParticipants(threadId);
  const notifyUsers = participants.filter((id) => id !== userId);
  
  if (notifyUsers.length) {
    await this.notificationService.createBatch(
      notifyUsers.map((participantId) => ({
        type: 'COMMENT',
        userId: participantId,
        actorId: userId,
        threadId,
        commentId: comment.id,
        sceneId: thread.sceneId,
      }))
    );
  }

  return comment;
}

private async getThreadParticipants(threadId: string): Promise<string[]> {
  const comments = await this.prisma.comment.findMany({
    where: { threadId },
    select: { createdById: true },
  });
  return [...new Set(comments.map((c) => c.createdById))];
}
```

### 7.2 Notification Types

Following [NOTIFICATION_SYSTEM_RESEARCH.md](NOTIFICATION_SYSTEM_RESEARCH.md):

| Type | Icon | Message | Trigger |
|------|------|---------|---------|
| COMMENT | 💬 | "{User} posted a comment in {Scene}" | New comment on thread |
| MENTION | @ | "{User} mentioned you in {Scene}" | User @mentioned |

### 7.3 Click-through

Notification links use deep link format:

```
/workspace/{slug}/scene/{sceneId}?thread={threadId}&comment={commentId}
```

### Acceptance Criteria

- [ ] @mentions create MENTION notifications
- [ ] New comments create COMMENT notifications for thread participants
- [ ] Notifications exclude the comment author
- [ ] Clicking notification opens scene with thread/comment focused

---

## File Summary

### Backend Files

| File | Action | Purpose |
|------|--------|---------|
| `prisma/schema.prisma` | Modify | Add CommentThread, Comment models |
| `src/comments/comments.module.ts` | Create | NestJS module |
| `src/comments/comments.controller.ts` | Create | REST endpoints |
| `src/comments/comments.service.ts` | Create | Business logic |
| `src/comments/dto/create-thread.dto.ts` | Create | Thread creation DTO |
| `src/comments/dto/create-comment.dto.ts` | Create | Comment creation DTO |
| `src/comments/dto/update-thread.dto.ts` | Create | Thread update DTO |
| `src/comments/dto/update-comment.dto.ts` | Create | Comment update DTO |

### Frontend Files

| File | Action | Purpose |
|------|--------|---------|
| `auth/api/comments.ts` | Create | API client |
| `auth/api/types.ts` | Modify | Add comment interfaces |
| `lib/queryClient.ts` | Modify | Add query keys |
| `hooks/useCommentThreads.ts` | Create | React Query hooks |
| `components/Comments/index.ts` | Create | Public exports |
| `components/Comments/commentsState.ts` | Create | Jotai atoms |
| `components/Comments/ThreadMarkersLayer.tsx` | Create | Canvas overlay |
| `components/Comments/ThreadMarker.tsx` | Create | Single marker |
| `components/Comments/ThreadMarkerTooltip.tsx` | Create | Hover preview |
| `components/Comments/CommentCreationOverlay.tsx` | Create | Click-to-create |
| `components/Comments/ThreadPopup.tsx` | Create | Thread popup |
| `components/Comments/ThreadPopupHeader.tsx` | Create | Popup header |
| `components/Comments/CommentItem.tsx` | Create | Single comment |
| `components/Comments/CommentInput.tsx` | Create | Reply input |
| `components/Comments/MentionInput.tsx` | Create | @mention input |
| `components/Comments/CommentsSidebar.tsx` | Create | Sidebar panel |
| `components/Comments/CommentsSidebarHeader.tsx` | Create | Search/filter |
| `components/Comments/ThreadListItem.tsx` | Create | Sidebar item |
| `components/Comments/CommentsFooterButton.tsx` | Create | Footer button |
| `components/AppSidebar/AppSidebar.tsx` | Modify | Replace placeholder |
| `components/AppFooter/AppFooter.tsx` | Modify | Add comment button |
| `router.ts` | Modify | Add thread/comment params |
| `hooks/useKeyboardShortcuts.ts` | Modify | Add C hotkey |
| `App.tsx` | Modify | Add ThreadMarkersLayer |

---

## Progress Checklist

### Phase 1: Backend Foundation ✅
- [x] Create Prisma schema migration
- [x] Create comments module structure
- [x] Implement CRUD endpoints for threads
- [x] Implement CRUD endpoints for comments
- [x] Add resolve/reopen endpoints
- [x] Add permission guards (VIEW/EDIT/ADMIN)
- [x] Add field filtering support
- [ ] Write controller tests (deferred - add as future task)

### Phase 2: Frontend State & API ✅
- [x] Create `auth/api/comments.ts`
- [x] Add TypeScript interfaces to `types.ts`
- [x] Add query keys to `queryClient.ts`
- [x] Create `useCommentThreads` hook
- [x] Create `useCommentMutations` hook
- [x] Create Jotai atoms in `commentsState.ts`
- [ ] Write hook tests (deferred - add as future task)

### Phase 3: Canvas Integration ✅
- [x] Create ThreadMarkersLayer component
- [x] Create ThreadMarker component
- [x] Create ThreadMarkerTooltip component
- [x] Implement position updates on pan/zoom
- [x] Add comment mode (C hotkey)
- [x] Create CommentCreationOverlay
- [x] Integrate with App.tsx

### Phase 4: Comment Popup
- [ ] Create ThreadPopup component
- [ ] Create ThreadPopupHeader
- [ ] Create CommentItem component
- [ ] Create CommentInput with @mentions
- [ ] Create MentionInput component
- [ ] Add thread navigation (< > buttons)
- [ ] Add resolve/reopen functionality
- [ ] Add copy link functionality
- [ ] Update router.ts for deep links
- [ ] Handle deep link navigation in App.tsx

### Phase 5: Sidebar Panel
- [ ] Create CommentsSidebar component
- [ ] Create CommentsSidebarHeader (search/filter)
- [ ] Create ThreadListItem component
- [ ] Implement search with highlighting
- [ ] Implement sort (date/unread)
- [ ] Implement show resolved toggle
- [ ] Replace AppSidebar placeholder
- [ ] Add CommentsFooterButton
- [ ] Add translations for all strings

### Phase 6: Real-time Sync (Optional)
- [ ] Add WebSocket events to room-service
- [ ] Create useCommentSync hook
- [ ] Subscribe to events in Collab
- [ ] Emit events on mutations
- [ ] Test multi-user sync

### Phase 7: Notification Integration
- [ ] Create notifications on @mention
- [ ] Create notifications on new comment
- [ ] Test notification click-through

---

## Estimated Effort

| Phase | Complexity | Estimate |
|-------|------------|----------|
| Phase 1: Backend Foundation | M | 2-3 days |
| Phase 2: Frontend State & API | M | 1-2 days |
| Phase 3: Canvas Integration | L | 2-3 days |
| Phase 4: Comment Popup | L | 2-3 days |
| Phase 5: Sidebar Panel | M | 1-2 days |
| Phase 6: Real-time Sync | M | 1-2 days |
| Phase 7: Notification Integration | S | 0.5-1 day |
| **Total** | | **10-16 days** |

---

## Related Documentation

- [COMMENT_SYSTEM_RESEARCH.md](COMMENT_SYSTEM_RESEARCH.md) - UI/UX research from Excalidraw Plus
- [NOTIFICATION_SYSTEM_RESEARCH.md](NOTIFICATION_SYSTEM_RESEARCH.md) - Notification system design
- [STATE_MANAGEMENT.md](../architecture/STATE_MANAGEMENT.md) - Jotai + React Query patterns
- [URL_ROUTING.md](../architecture/URL_ROUTING.md) - URL routing patterns
- [TECHNICAL_DEBT_AND_IMPROVEMENTS.md](TECHNICAL_DEBT_AND_IMPROVEMENTS.md) - Established patterns to follow

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-23 | Phase 3: Canvas Integration complete (markers, tooltip, creation overlay, C hotkey) |
| 2025-12-23 | Phase 2: Frontend State & API complete (API client, types, hooks, atoms) |
| 2025-12-23 | Phase 1: All 13 API tests passed, documented testing pattern |
| 2025-12-23 | Phase 1: Fixed controller path duplication (`@Controller()` not `@Controller('api/v2')`) |
| 2025-12-23 | Phase 1 Backend Foundation complete (schema, module, endpoints, permissions) |
| 2025-12-23 | Initial implementation plan created |

