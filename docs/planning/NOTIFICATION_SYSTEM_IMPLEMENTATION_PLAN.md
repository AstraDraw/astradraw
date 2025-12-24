# Notification System Implementation Plan

This document provides a detailed implementation plan for the Notification System feature in AstraDraw. The system alerts users when they are @mentioned in comments or when new comments appear on threads they participate in.

> **Research:** See [NOTIFICATION_SYSTEM_RESEARCH.md](NOTIFICATION_SYSTEM_RESEARCH.md) for UI/UX research, HTML structures, and design decisions.
> **Related:** See [COMMENT_SYSTEM_IMPLEMENTATION_PLAN.md](COMMENT_SYSTEM_IMPLEMENTATION_PLAN.md) for the comment system that triggers notifications.

---

## Overview

### Feature Goals

1. **Bell Icon with Badge** - Notification bell in sidebar footer showing unread count
2. **Quick Popup** - Click bell to see recent notifications with mark-as-read
3. **Full Page View** - Timeline view of all notifications with infinite scroll
4. **Comment Notifications** - Alert thread participants when new comments are posted
5. **Mention Notifications** - Alert users when @mentioned in comments
6. **Deep Link Navigation** - Click notification to open scene with thread/comment focused

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Frontend                                   │
│                                                                     │
│  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │ auth/api/        │    │ hooks/           │    │ components/   │  │
│  │ notifications.ts │───►│ useNotifications │───►│ Notifications/│  │
│  │ (API client)     │    │ (React Query)    │    │ (UI)          │  │
│  └──────────────────┘    └──────────────────┘    └───────────────┘  │
│                                                         │           │
│                          ┌──────────────────┐           │           │
│                          │ notificationsState│◄─────────┘           │
│                          │ (Jotai atoms)    │                       │
│                          └──────────────────┘                       │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           Backend                                    │
│                                                                     │
│  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │ notifications/   │    │ notifications.   │    │ Prisma        │  │
│  │ controller.ts    │───►│ service.ts       │───►│ Notification  │  │
│  │ (REST API)       │    │ (Business logic) │    │ model         │  │
│  └──────────────────┘    └──────────────────┘    └───────────────┘  │
│                                    ▲                                │
│                                    │                                │
│  ┌──────────────────┐              │                                │
│  │ comments/        │──────────────┘                                │
│  │ service.ts       │  (triggers notifications)                     │
│  └──────────────────┘                                               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Backend - Database & Module

**Goal:** Create database schema and REST API for notifications.

**Complexity:** M (Medium) | **Estimate:** 1-2 days

### 1.1 Prisma Schema

**File:** `backend/prisma/schema.prisma`

Add the Notification model and enum:

```prisma
// ============================================================================
// Notification Types
// ============================================================================
enum NotificationType {
  COMMENT   // New comment on thread user participated in
  MENTION   // User was @mentioned in a comment
}

// ============================================================================
// Notification Model
// ============================================================================
model Notification {
  id        String           @id @default(cuid())
  type      NotificationType
  
  // Recipient - who receives the notification
  userId    String
  user      User             @relation("UserNotifications", fields: [userId], references: [id], onDelete: Cascade)
  
  // Actor - who triggered the notification
  actorId   String
  actor     User             @relation("ActorNotifications", fields: [actorId], references: [id])
  
  // References to comment system
  threadId  String?
  thread    CommentThread?   @relation(fields: [threadId], references: [id], onDelete: Cascade)
  commentId String?
  comment   Comment?         @relation(fields: [commentId], references: [id], onDelete: Cascade)
  sceneId   String
  scene     Scene            @relation(fields: [sceneId], references: [id], onDelete: Cascade)
  
  // Read status
  read      Boolean          @default(false)
  readAt    DateTime?
  
  createdAt DateTime         @default(now())
  
  @@index([userId, read])
  @@index([userId, createdAt])
  @@map("notifications")
}
```

**Update existing models:**

```prisma
// Add to User model
model User {
  // ... existing fields ...
  
  notifications      Notification[] @relation("UserNotifications")
  actorNotifications Notification[] @relation("ActorNotifications")
}

// Add to Scene model
model Scene {
  // ... existing fields ...
  
  notifications      Notification[]
}

// Add to CommentThread model (already has notifications relation in schema)
model CommentThread {
  // ... existing fields ...
  
  notifications   Notification[]
}

// Add to Comment model (already has notifications relation in schema)
model Comment {
  // ... existing fields ...
  
  notifications   Notification[]
}
```

### 1.2 Backend Module Structure

**Directory:** `backend/src/notifications/`

```
notifications/
├── notifications.module.ts          # NestJS module definition
├── notifications.controller.ts      # REST endpoints
├── notifications.service.ts         # Business logic
└── dto/
    └── notification-response.dto.ts # Response types
```

### 1.3 API Endpoints

| Method | Endpoint | Purpose | Auth |
|--------|----------|---------|------|
| GET | `/api/v2/notifications` | List notifications (cursor pagination) | Required |
| GET | `/api/v2/notifications/unread-count` | Get unread count for badge | Required |
| POST | `/api/v2/notifications/:id/read` | Mark single as read | Required |
| POST | `/api/v2/notifications/read-all` | Mark all as read | Required |

### 1.4 Request/Response Examples

**List Notifications:**
```typescript
// GET /api/v2/notifications?limit=20&cursor=notif-123&unread=true
// Response
{
  "notifications": [
    {
      "id": "notif-abc123",
      "type": "MENTION",
      "actor": {
        "id": "user-456",
        "name": "Mr. Khachaturov",
        "avatar": "https://..."
      },
      "thread": { "id": "thread-789" },
      "comment": { "id": "comment-xyz" },
      "scene": {
        "id": "scene-abc",
        "name": "Project Design"
      },
      "read": false,
      "createdAt": "2025-12-24T15:30:00Z"
    }
  ],
  "nextCursor": "notif-100",
  "hasMore": true
}
```

**Get Unread Count:**
```typescript
// GET /api/v2/notifications/unread-count
// Response
{
  "count": 5
}
```

### 1.5 NotificationsService

**File:** `backend/src/notifications/notifications.service.ts`

```typescript
@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Create MENTION notifications for @mentioned users
   */
  async createMentionNotifications(params: {
    actorId: string;
    mentions: string[];
    threadId: string;
    commentId: string;
    sceneId: string;
  }): Promise<void> {
    const { actorId, mentions, threadId, commentId, sceneId } = params;
    
    // Filter out self-mentions
    const recipients = mentions.filter(id => id !== actorId);
    if (recipients.length === 0) return;

    await this.prisma.notification.createMany({
      data: recipients.map(userId => ({
        type: 'MENTION',
        userId,
        actorId,
        threadId,
        commentId,
        sceneId,
      })),
    });
  }

  /**
   * Create COMMENT notifications for thread participants
   */
  async createCommentNotifications(params: {
    actorId: string;
    participants: string[];
    threadId: string;
    commentId: string;
    sceneId: string;
  }): Promise<void> {
    const { actorId, participants, threadId, commentId, sceneId } = params;
    
    // Filter out the comment author
    const recipients = participants.filter(id => id !== actorId);
    if (recipients.length === 0) return;

    await this.prisma.notification.createMany({
      data: recipients.map(userId => ({
        type: 'COMMENT',
        userId,
        actorId,
        threadId,
        commentId,
        sceneId,
      })),
    });
  }

  /**
   * List notifications for a user with cursor pagination
   */
  async listNotifications(
    userId: string,
    options?: { cursor?: string; limit?: number; unread?: boolean }
  ): Promise<NotificationsResponse> {
    const limit = options?.limit ?? 20;
    
    const where: Prisma.NotificationWhereInput = { userId };
    if (options?.unread) {
      where.read = false;
    }
    if (options?.cursor) {
      where.id = { lt: options.cursor };
    }

    const notifications = await this.prisma.notification.findMany({
      where,
      include: {
        actor: { select: { id: true, name: true, avatarUrl: true } },
        thread: { select: { id: true } },
        comment: { select: { id: true } },
        scene: { select: { id: true, title: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: limit + 1, // Fetch one extra to check hasMore
    });

    const hasMore = notifications.length > limit;
    const items = hasMore ? notifications.slice(0, -1) : notifications;
    const nextCursor = hasMore ? items[items.length - 1]?.id : undefined;

    return {
      notifications: items.map(this.mapToResponse),
      nextCursor,
      hasMore,
    };
  }

  /**
   * Get unread notification count
   */
  async getUnreadCount(userId: string): Promise<number> {
    return this.prisma.notification.count({
      where: { userId, read: false },
    });
  }

  /**
   * Mark a single notification as read
   */
  async markAsRead(notificationId: string, userId: string): Promise<void> {
    await this.prisma.notification.updateMany({
      where: { id: notificationId, userId },
      data: { read: true, readAt: new Date() },
    });
  }

  /**
   * Mark all notifications as read
   */
  async markAllAsRead(userId: string): Promise<void> {
    await this.prisma.notification.updateMany({
      where: { userId, read: false },
      data: { read: true, readAt: new Date() },
    });
  }
}
```

### Acceptance Criteria

- [x] Migration creates Notification table with proper indexes
- [x] All CRUD endpoints work with proper authentication
- [x] Cursor pagination works correctly
- [x] Unread count returns accurate number
- [x] Mark as read updates both `read` and `readAt` fields
- [x] Cascade delete works (deleting scene/thread/comment removes notifications)

### Implementation Status ✅

**Completed:** 2025-12-24

**Files Created:**
- `backend/prisma/migrations/20251224095717_add_notifications/migration.sql` - Database migration
- `backend/src/notifications/notifications.module.ts` - NestJS module definition
- `backend/src/notifications/notifications.controller.ts` - REST endpoints (4 endpoints)
- `backend/src/notifications/notifications.service.ts` - Business logic + notification creation methods

**Files Modified:**
- `backend/prisma/schema.prisma` - Added NotificationType enum, Notification model, relations to User/Scene/CommentThread/Comment
- `backend/src/app.module.ts` - Imported NotificationsModule

**API Testing Results:**

| Test | Endpoint | Method | Result |
|------|----------|--------|--------|
| List notifications (empty) | `/api/v2/notifications` | GET | ✅ Returns `{ notifications: [], hasMore: false }` |
| List notifications (with data) | `/api/v2/notifications` | GET | ✅ Returns notification with actor, scene info |
| Get unread count | `/api/v2/notifications/unread-count` | GET | ✅ Returns `{ count: N }` |
| Mark single as read | `/api/v2/notifications/:id/read` | POST | ✅ Returns `{ success: true }` |
| Mark all as read | `/api/v2/notifications/read-all` | POST | ✅ Returns `{ success: true }` |

**Service Methods Ready for Phase 2:**
- `createMentionNotifications(params)` - Create MENTION notifications for @mentioned users
- `createCommentNotifications(params)` - Create COMMENT notifications for thread participants

---

## Phase 2: Backend - Comment Integration

**Goal:** Trigger notifications when comments are created or users are @mentioned.

**Complexity:** S (Small) | **Estimate:** 0.5 day

**Dependencies:** Phase 1 (Backend Module)

### 2.1 Inject NotificationsService into CommentsService

**File:** `backend/src/comments/comments.service.ts`

```typescript
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class CommentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sceneAccessService: SceneAccessService,
    private readonly notificationsService: NotificationsService, // NEW
  ) {}
  
  // ... existing methods ...
}
```

### 2.2 Update createThread Method

Add notification triggers after creating a thread:

```typescript
async createThread(sceneId: string, userId: string, dto: CreateThreadDto): Promise<ThreadResponse> {
  // ... existing thread creation code ...

  // Create MENTION notifications for @mentioned users
  if (dto.mentions?.length) {
    await this.notificationsService.createMentionNotifications({
      actorId: userId,
      mentions: dto.mentions,
      threadId: thread.id,
      commentId: thread.comments[0].id,
      sceneId,
    });
  }

  return this.mapThreadToResponse(thread);
}
```

### 2.3 Update addComment Method

Add notification triggers after adding a comment:

```typescript
async addComment(threadId: string, userId: string, dto: CreateCommentDto): Promise<CommentResponse> {
  const thread = await this.prisma.commentThread.findUnique({
    where: { id: threadId },
  });

  // ... existing comment creation code ...

  // Create MENTION notifications for @mentioned users
  if (dto.mentions?.length) {
    await this.notificationsService.createMentionNotifications({
      actorId: userId,
      mentions: dto.mentions,
      threadId,
      commentId: comment.id,
      sceneId: thread.sceneId,
    });
  }

  // Create COMMENT notifications for thread participants (except author)
  const participants = await this.getThreadParticipants(threadId);
  const notifyUsers = participants.filter(id => id !== userId);
  
  if (notifyUsers.length) {
    await this.notificationsService.createCommentNotifications({
      actorId: userId,
      participants: notifyUsers,
      threadId,
      commentId: comment.id,
      sceneId: thread.sceneId,
    });
  }

  return this.mapCommentToResponse(comment);
}

/**
 * Get unique user IDs who have commented on a thread
 */
private async getThreadParticipants(threadId: string): Promise<string[]> {
  const comments = await this.prisma.comment.findMany({
    where: { threadId },
    select: { createdById: true },
  });
  return [...new Set(comments.map(c => c.createdById))];
}
```

### 2.4 Update Module Imports

**File:** `backend/src/comments/comments.module.ts`

```typescript
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    PrismaModule,
    NotificationsModule, // NEW
  ],
  // ...
})
export class CommentsModule {}
```

### Acceptance Criteria

- [x] Creating a thread with @mentions creates MENTION notifications
- [x] Adding a comment with @mentions creates MENTION notifications
- [x] Adding a comment creates COMMENT notifications for thread participants
- [x] Comment author is excluded from notifications
- [x] Self-mentions don't create notifications

### Implementation Status ✅

**Completed:** 2025-12-24

**Files Modified:**
- `backend/src/comments/comments.module.ts` - Added NotificationsModule import
- `backend/src/comments/comments.service.ts` - Injected NotificationsService, added notification triggers to createThread and addComment, added getThreadParticipants helper

**API Testing Results:**

| Test | Description | Result |
|------|-------------|--------|
| Create thread with @mention | Admin creates thread mentioning Ruben | ✅ MENTION notification created for Ruben |
| Self-mention excluded | Admin creates thread mentioning self | ✅ No notification created (correctly excluded) |
| Reply creates COMMENT notification | Ruben replies to Admin's thread | ✅ COMMENT notification created for Admin |
| Author excluded from COMMENT | Admin replies to own thread (no other participants) | ✅ No notification (author excluded) |

---

## Phase 3: Frontend - API & State

**Goal:** Create API client, React Query hooks, and Jotai atoms for notification state.

**Complexity:** S (Small) | **Estimate:** 0.5 day

**Dependencies:** Phase 1 (Backend)

### 3.1 API Client Module

**File:** `frontend/excalidraw-app/auth/api/notifications.ts`

```typescript
/**
 * Notifications API - CRUD operations for user notifications
 */

import { apiRequest } from "./client";
import type { NotificationsResponse } from "./types";

export interface ListNotificationsOptions {
  cursor?: string;
  limit?: number;
  unread?: boolean;
}

export async function listNotifications(
  options?: ListNotificationsOptions
): Promise<NotificationsResponse> {
  const params = new URLSearchParams();
  if (options?.cursor) {
    params.append('cursor', options.cursor);
  }
  if (options?.limit) {
    params.append('limit', String(options.limit));
  }
  if (options?.unread) {
    params.append('unread', 'true');
  }
  
  return apiRequest(`/notifications?${params}`, {
    errorMessage: "Failed to list notifications",
  });
}

export async function getUnreadCount(): Promise<{ count: number }> {
  return apiRequest('/notifications/unread-count', {
    errorMessage: "Failed to get unread count",
  });
}

export async function markAsRead(notificationId: string): Promise<void> {
  return apiRequest(`/notifications/${notificationId}/read`, {
    method: "POST",
    errorMessage: "Failed to mark notification as read",
  });
}

export async function markAllAsRead(): Promise<void> {
  return apiRequest('/notifications/read-all', {
    method: "POST",
    errorMessage: "Failed to mark all notifications as read",
  });
}
```

### 3.2 TypeScript Interfaces

**File:** `frontend/excalidraw-app/auth/api/types.ts`

Add to existing types file:

```typescript
// ============================================================================
// Notification System Types
// ============================================================================

export type NotificationType = 'COMMENT' | 'MENTION';

export interface Notification {
  id: string;
  type: NotificationType;
  actor: UserSummary;
  thread?: { id: string };
  comment?: { id: string };
  scene: {
    id: string;
    name: string;
  };
  read: boolean;
  readAt?: string;
  createdAt: string;
}

export interface NotificationsResponse {
  notifications: Notification[];
  nextCursor?: string;
  hasMore: boolean;
}
```

### 3.3 Query Keys and Mutation Keys

**File:** `frontend/excalidraw-app/lib/queryClient.ts`

Add to existing query key factory:

```typescript
export const queryKeys = {
  // ... existing keys ...
  
  // Notifications
  notifications: {
    all: ["notifications"] as const,
    list: (cursor?: string) => ["notifications", "list", cursor] as const,
    unreadCount: ["notifications", "unreadCount"] as const,
  },

  // Mutations (add to existing mutations object)
  mutations: {
    // ... existing mutation keys ...
    markNotificationRead: ["markNotificationRead"] as const,
    markAllNotificationsRead: ["markAllNotificationsRead"] as const,
  },
} as const;
```

### 3.4 React Query Hooks

**File:** `frontend/excalidraw-app/hooks/useNotifications.ts`

```typescript
import { useInfiniteQuery, useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { queryKeys } from "../lib/queryClient";
import {
  listNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
} from "../auth/api/notifications";
import type { Notification, NotificationsResponse } from "../auth/api/types";

/**
 * Hook for fetching notifications with infinite scroll
 */
export function useNotifications(options?: { unread?: boolean }) {
  return useInfiniteQuery({
    queryKey: queryKeys.notifications.all,
    queryFn: ({ pageParam }) => listNotifications({ cursor: pageParam, unread: options?.unread }),
    getNextPageParam: (lastPage) => lastPage.hasMore ? lastPage.nextCursor : undefined,
    initialPageParam: undefined as string | undefined,
  });
}

/**
 * Hook for unread notification count (polls every 60s)
 */
export function useUnreadCount(enabled: boolean = true) {
  return useQuery({
    queryKey: queryKeys.notifications.unreadCount,
    queryFn: getUnreadCount,
    enabled,
    refetchInterval: 60 * 1000, // Poll every 60 seconds
    staleTime: 30 * 1000,
  });
}

/**
 * Hook for notification mutations
 */
export function useNotificationMutations() {
  const queryClient = useQueryClient();

  const markReadMutation = useMutation({
    mutationFn: markAsRead,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.notifications.all });
      queryClient.invalidateQueries({ queryKey: queryKeys.notifications.unreadCount });
    },
  });

  const markAllReadMutation = useMutation({
    mutationFn: markAllAsRead,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.notifications.all });
      queryClient.setQueryData(queryKeys.notifications.unreadCount, { count: 0 });
    },
  });

  return {
    markAsRead: markReadMutation.mutateAsync,
    markAllAsRead: markAllReadMutation.mutateAsync,
    isMarkingRead: markReadMutation.isPending,
    isMarkingAllRead: markAllReadMutation.isPending,
  };
}
```

### 3.5 Jotai Atoms

**File:** `frontend/excalidraw-app/components/Notifications/notificationsState.ts`

```typescript
import { atom } from "jotai";

/** Whether the notification popup is currently open */
export const isNotificationPopupOpenAtom = atom<boolean>(false);

/** Toggle notification popup open/closed */
export const toggleNotificationPopupAtom = atom(null, (get, set) => {
  set(isNotificationPopupOpenAtom, !get(isNotificationPopupOpenAtom));
});

/** Close notification popup */
export const closeNotificationPopupAtom = atom(null, (get, set) => {
  set(isNotificationPopupOpenAtom, false);
});
```

### Acceptance Criteria

- [x] API client functions match all backend endpoints
- [x] TypeScript interfaces match backend DTOs
- [x] React Query hooks fetch and cache notifications correctly
- [x] Infinite scroll pagination works
- [x] Unread count polls every 60 seconds
- [x] Mutations invalidate relevant queries
- [x] Jotai atoms manage popup open/close state

### Implementation Status ✅

**Completed:** 2025-12-24

**Files Created:**
- `frontend/excalidraw-app/auth/api/notifications.ts` - API client (listNotifications, getUnreadCount, markAsRead, markAllAsRead)
- `frontend/excalidraw-app/hooks/useNotifications.ts` - React Query hooks (useNotifications, useUnreadCount, useNotificationMutations)
- `frontend/excalidraw-app/components/Notifications/notificationsState.ts` - Jotai atoms for popup state
- `frontend/excalidraw-app/utils/dateUtils.ts` - Date formatting utilities (formatDistanceToNow)

**Files Modified:**
- `frontend/excalidraw-app/auth/api/types.ts` - Added Notification, NotificationType, NotificationsResponse types
- `frontend/excalidraw-app/auth/api/index.ts` - Added notification exports
- `frontend/excalidraw-app/lib/queryClient.ts` - Added notifications query keys and mutation keys

---

## Phase 4: Frontend - Bell Icon & Popup

**Goal:** Build notification bell with badge and quick popup view.

**Complexity:** M (Medium) | **Estimate:** 1-2 days

**Dependencies:** Phase 3 (Frontend State)

### 4.1 Component Structure

**Directory:** `frontend/excalidraw-app/components/Notifications/`

```
Notifications/
├── index.ts                        # Public exports
├── notificationsState.ts           # Jotai atoms
├── NotificationBell/
│   ├── index.ts
│   ├── NotificationBell.tsx
│   └── NotificationBell.module.scss
├── NotificationBadge/
│   ├── index.ts
│   ├── NotificationBadge.tsx
│   └── NotificationBadge.module.scss
├── NotificationPopup/
│   ├── index.ts
│   ├── NotificationPopup.tsx
│   ├── NotificationPopup.module.scss
│   └── NotificationPopupItem.tsx
├── Skeletons/                      # Loading skeletons (Tech Debt #7 pattern)
│   ├── index.ts
│   ├── NotificationItemSkeleton.tsx
│   └── NotificationItemSkeleton.module.scss
```

### 4.2 NotificationBell Component

**File:** `frontend/excalidraw-app/components/Notifications/NotificationBell/NotificationBell.tsx`

```typescript
import React, { useRef } from "react";
import { useAtom } from "jotai";
import { useUnreadCount } from "../../../hooks/useNotifications";
import { isNotificationPopupOpenAtom } from "../notificationsState";
import { NotificationBadge } from "../NotificationBadge";
import { NotificationPopup } from "../NotificationPopup";
import { bellIcon } from "../../Workspace/WorkspaceSidebar/icons";
import styles from "./NotificationBell.module.scss";

export const NotificationBell: React.FC = () => {
  const [isPopupOpen, setIsPopupOpen] = useAtom(isNotificationPopupOpenAtom);
  const { data: unreadData } = useUnreadCount();
  const buttonRef = useRef<HTMLButtonElement>(null);

  const handleClick = () => {
    setIsPopupOpen(!isPopupOpen);
  };

  const handleClose = () => {
    setIsPopupOpen(false);
  };

  return (
    <div className={styles.container}>
      <button
        ref={buttonRef}
        className={styles.button}
        onClick={handleClick}
        aria-label="Notifications"
      >
        {bellIcon}
        {unreadData && unreadData.count > 0 && (
          <NotificationBadge count={unreadData.count} />
        )}
      </button>
      
      {isPopupOpen && (
        <NotificationPopup onClose={handleClose} />
      )}
    </div>
  );
};
```

### 4.3 NotificationBadge Component

**File:** `frontend/excalidraw-app/components/Notifications/NotificationBadge/NotificationBadge.tsx`

```typescript
import React from "react";
import styles from "./NotificationBadge.module.scss";

interface Props {
  count: number;
}

export const NotificationBadge: React.FC<Props> = ({ count }) => {
  const displayCount = count > 5 ? "5+" : String(count);
  
  return (
    <span className={styles.badge}>
      {displayCount}
    </span>
  );
};
```

### 4.4 NotificationItemSkeleton Component (Loading State)

**File:** `frontend/excalidraw-app/components/Notifications/Skeletons/NotificationItemSkeleton.tsx`

Following the established skeleton pattern from Tech Debt #7:

```typescript
import React from "react";
import styles from "./NotificationItemSkeleton.module.scss";

export const NotificationItemSkeleton: React.FC = () => (
  <div className={styles.skeleton}>
    <div className={styles.avatar} />
    <div className={styles.content}>
      <div className={styles.line} />
      <div className={styles.lineShort} />
    </div>
  </div>
);

interface NotificationSkeletonListProps {
  count?: number;
}

export const NotificationSkeletonList: React.FC<NotificationSkeletonListProps> = ({ 
  count = 3 
}) => (
  <>
    {Array.from({ length: count }).map((_, i) => (
      <NotificationItemSkeleton key={i} />
    ))}
  </>
);
```

**File:** `frontend/excalidraw-app/components/Notifications/Skeletons/NotificationItemSkeleton.module.scss`

```scss
@use "../../../styles/mixins" as *;
@use "../../../styles/animations" as *;

.skeleton {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px 16px;
}

.avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: linear-gradient(90deg, #e0e0e0 25%, #f0f0f0 50%, #e0e0e0 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}

.content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.line {
  height: 14px;
  border-radius: 4px;
  background: linear-gradient(90deg, #e0e0e0 25%, #f0f0f0 50%, #e0e0e0 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}

.lineShort {
  @extend .line;
  width: 60%;
}

@include dark-mode {
  .avatar,
  .line,
  .lineShort {
    background: linear-gradient(90deg, #3a3a3a 25%, #4a4a4a 50%, #3a3a3a 75%);
    background-size: 200% 100%;
  }
}
```

### 4.5 NotificationPopup Component

**File:** `frontend/excalidraw-app/components/Notifications/NotificationPopup/NotificationPopup.tsx`

```typescript
import React from "react";
import { useTranslation } from "react-i18next";
import { useNotifications, useNotificationMutations } from "../../../hooks/useNotifications";
import { NotificationPopupItem } from "./NotificationPopupItem";
import { NotificationSkeletonList } from "../Skeletons";
import { buildNotificationsUrl } from "../../../router";
import styles from "./NotificationPopup.module.scss";

interface Props {
  onClose: () => void;
}

export const NotificationPopup: React.FC<Props> = ({ onClose }) => {
  const { t } = useTranslation();
  const { data, isLoading } = useNotifications();
  const { markAllAsRead, isMarkingAllRead } = useNotificationMutations();

  const notifications = data?.pages[0]?.notifications.slice(0, 5) ?? [];

  const handleMarkAllRead = async () => {
    await markAllAsRead();
  };

  const handleViewAll = () => {
    // Navigate to notifications page
    window.location.href = buildNotificationsUrl(workspaceSlug);
    onClose();
  };

  return (
    <div className={styles.popup}>
      <div className={styles.header}>
        <h3>{t("notifications.title")}</h3>
        <button
          className={styles.markAllRead}
          onClick={handleMarkAllRead}
          disabled={isMarkingAllRead}
        >
          {t("notifications.markAllRead")}
        </button>
      </div>
      
      <div className={styles.list}>
        {isLoading ? (
          <NotificationSkeletonList count={3} />
        ) : notifications.length === 0 ? (
          <div className={styles.empty}>{t("notifications.empty")}</div>
        ) : (
          notifications.map((notification) => (
            <NotificationPopupItem
              key={notification.id}
              notification={notification}
              onClose={onClose}
            />
          ))
        )}
      </div>
      
      <div className={styles.footer}>
        <button className={styles.viewAll} onClick={handleViewAll}>
          {t("notifications.viewAll")}
        </button>
      </div>
    </div>
  );
};
```

### 4.6 Update SidebarFooter

**File:** `frontend/excalidraw-app/components/Workspace/WorkspaceSidebar/SidebarFooter.tsx`

Replace the placeholder bell button with the NotificationBell component:

```typescript
import { NotificationBell } from "../../Notifications";

// Replace:
// <button className={styles.notificationButton} title={t("workspace.notifications")}>
//   {bellIcon}
// </button>

// With:
<NotificationBell />
```

### Acceptance Criteria

- [x] Bell icon shows in sidebar footer
- [x] Badge shows unread count (max "5+")
- [x] Badge hidden when count is 0
- [x] Click bell opens popup
- [x] Popup shows up to 5 recent notifications
- [x] "Mark all as read" clears all notifications
- [x] Hover on item shows mark-as-read button
- [ ] Click item navigates to scene with thread focused (requires onNavigate implementation)
- [x] "View all" navigates to notifications page
- [x] Click outside popup closes it

### Implementation Status ✅

**Completed:** 2025-12-24

**Files Created:**
- `frontend/excalidraw-app/components/Notifications/index.ts` - Module exports
- `frontend/excalidraw-app/components/Notifications/NotificationBell/NotificationBell.tsx` - Bell icon with badge
- `frontend/excalidraw-app/components/Notifications/NotificationBell/NotificationBell.module.scss` - Bell styles
- `frontend/excalidraw-app/components/Notifications/NotificationBadge/NotificationBadge.tsx` - Red badge component
- `frontend/excalidraw-app/components/Notifications/NotificationBadge/NotificationBadge.module.scss` - Badge styles
- `frontend/excalidraw-app/components/Notifications/NotificationPopup/NotificationPopup.tsx` - Popup container
- `frontend/excalidraw-app/components/Notifications/NotificationPopup/NotificationPopupItem.tsx` - Single notification row
- `frontend/excalidraw-app/components/Notifications/NotificationPopup/NotificationPopup.module.scss` - Popup styles
- `frontend/excalidraw-app/components/Notifications/Skeletons/NotificationItemSkeleton.tsx` - Loading skeleton
- `frontend/excalidraw-app/components/Notifications/Skeletons/NotificationItemSkeleton.module.scss` - Skeleton styles

**Files Modified:**
- `frontend/excalidraw-app/components/Workspace/WorkspaceSidebar/SidebarFooter.tsx` - Replaced placeholder bell with NotificationBell
- `frontend/excalidraw-app/components/Workspace/WorkspaceSidebar/WorkspaceSidebar.tsx` - Pass workspaceSlug to SidebarFooter
- `frontend/packages/excalidraw/locales/en.json` - Added notification translations
- `frontend/packages/excalidraw/locales/ru-RU.json` - Added notification translations (Russian)

---

## Phase 5: Frontend - Notifications Page

**Goal:** Full page view with timeline and infinite scroll.

**Complexity:** M (Medium) | **Estimate:** 1-2 days

**Dependencies:** Phase 4 (Bell & Popup)

### 5.1 Route Setup

**File:** `frontend/excalidraw-app/router.ts`

Add notifications route:

```typescript
// Add to RouteType
| { type: "notifications"; workspaceSlug: string }

// Add pattern
const WORKSPACE_NOTIFICATIONS_PATTERN = /^\/workspace\/([^/]+)\/notifications\/?$/;

// Add to parseUrl()
const notificationsMatch = pathname.match(WORKSPACE_NOTIFICATIONS_PATTERN);
if (notificationsMatch) {
  return { type: "notifications", workspaceSlug: notificationsMatch[1] };
}

// Add URL builder
export function buildNotificationsUrl(workspaceSlug: string): string {
  return `/workspace/${encodeURIComponent(workspaceSlug)}/notifications`;
}
```

### 5.2 Component Structure

```
Notifications/
├── NotificationsPage/
│   ├── index.ts
│   ├── NotificationsPage.tsx
│   ├── NotificationsPage.module.scss
│   └── NotificationTimelineItem.tsx
└── UnreadBadge/
    ├── index.ts
    ├── UnreadBadge.tsx
    └── UnreadBadge.module.scss
```

### 5.3 NotificationsPage Component

**File:** `frontend/excalidraw-app/components/Notifications/NotificationsPage/NotificationsPage.tsx`

```typescript
import React, { useEffect } from "react";
import { useInView } from "react-intersection-observer";
import { useTranslation } from "react-i18next";
import { useNotifications } from "../../../hooks/useNotifications";
import { NotificationTimelineItem } from "./NotificationTimelineItem";
import { NotificationSkeletonList } from "../Skeletons";
import styles from "./NotificationsPage.module.scss";

export const NotificationsPage: React.FC = () => {
  const { t } = useTranslation();
  const { ref, inView } = useInView();
  const {
    data,
    isLoading,
    isFetchingNextPage,
    hasNextPage,
    fetchNextPage,
  } = useNotifications();

  // Infinite scroll - fetch more when bottom is visible
  useEffect(() => {
    if (inView && hasNextPage && !isFetchingNextPage) {
      fetchNextPage();
    }
  }, [inView, hasNextPage, isFetchingNextPage, fetchNextPage]);

  const notifications = data?.pages.flatMap(page => page.notifications) ?? [];

  return (
    <div className={styles.page}>
      <h1 className={styles.title}>{t("notifications.title")}</h1>
      
      <div className={styles.timeline}>
        {isLoading ? (
          <NotificationSkeletonList count={5} />
        ) : notifications.length === 0 ? (
          <div className={styles.empty}>{t("notifications.empty")}</div>
        ) : (
          <>
            {notifications.map((notification, index) => (
              <NotificationTimelineItem
                key={notification.id}
                notification={notification}
                isLast={index === notifications.length - 1}
              />
            ))}
            
            {/* Infinite scroll trigger */}
            <div ref={ref} className={styles.loadMore}>
              {isFetchingNextPage ? (
                <NotificationSkeletonList count={2} />
              ) : hasNextPage ? (
                <span>{t("notifications.scrollForMore")}</span>
              ) : (
                <span>{t("notifications.noMore")}</span>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
};
```

### 5.4 UnreadBadge Component

**File:** `frontend/excalidraw-app/components/Notifications/UnreadBadge/UnreadBadge.tsx`

```typescript
import React from "react";
import { useTranslation } from "react-i18next";
import styles from "./UnreadBadge.module.scss";

export const UnreadBadge: React.FC = () => {
  const { t } = useTranslation();
  
  return (
    <span className={styles.badge}>
      <span className={styles.pulsingDot} />
      {t("notifications.unread")}
    </span>
  );
};
```

### 5.5 Integrate with App.tsx

Add notifications page rendering:

```typescript
// In App.tsx
if (route.type === "notifications") {
  return <NotificationsPage />;
}
```

### Acceptance Criteria

- [x] `/workspace/{slug}/notifications` route works
- [x] Page shows all notifications in timeline view
- [x] Vertical line connects timeline items
- [x] Infinite scroll loads more on scroll
- [x] Unread notifications show pulsing badge
- [x] Click notification navigates to scene with thread focused
- [x] "No more notifications" shown at bottom
- [x] Empty state when no notifications

### Implementation Status ✅

**Completed:** 2025-12-24

**Files Created:**
- `frontend/excalidraw-app/components/Notifications/NotificationsPage/NotificationsPage.tsx` - Main page with infinite scroll
- `frontend/excalidraw-app/components/Notifications/NotificationsPage/NotificationsPage.module.scss` - Timeline styles
- `frontend/excalidraw-app/components/Notifications/NotificationsPage/NotificationTimelineItem.tsx` - Single timeline item
- `frontend/excalidraw-app/components/Notifications/NotificationsPage/index.ts` - Module exports
- `frontend/excalidraw-app/components/Notifications/UnreadBadge/UnreadBadge.tsx` - Pulsing unread badge
- `frontend/excalidraw-app/components/Notifications/UnreadBadge/UnreadBadge.module.scss` - Badge styles with animation
- `frontend/excalidraw-app/components/Notifications/UnreadBadge/index.ts` - Module exports

**Files Modified:**
- `frontend/excalidraw-app/router.ts` - Added notifications route type, pattern, URL builder, route helpers
- `frontend/excalidraw-app/components/Settings/settingsState.ts` - Added "notifications" to DashboardView, navigateToNotificationsAtom
- `frontend/excalidraw-app/hooks/useUrlRouting.ts` - Added notifications case to route handler
- `frontend/excalidraw-app/components/Workspace/WorkspaceMainContent/WorkspaceMainContent.tsx` - Added notifications case
- `frontend/excalidraw-app/components/Notifications/index.ts` - Added new component exports
- `frontend/excalidraw-app/components/Notifications/NotificationPopup/NotificationPopup.tsx` - Use buildNotificationsUrl

---

## Phase 6: Translations

**Goal:** Add all notification-related strings to locale files.

**Complexity:** S (Small) | **Estimate:** 0.5 day

### 6.1 English Translations

**File:** `packages/excalidraw/locales/en.json`

```json
{
  "notifications": {
    "title": "Notifications",
    "markAllRead": "Mark all as read",
    "viewAll": "View all notifications",
    "noMore": "No more notifications",
    "scrollForMore": "Scroll for more",
    "empty": "No notifications yet",
    "postedComment": "posted a comment in",
    "mentionedYou": "mentioned you in",
    "unread": "Unread",
    "loading": "Loading notifications..."
  }
}
```

### 6.2 Russian Translations

**File:** `packages/excalidraw/locales/ru-RU.json`

```json
{
  "notifications": {
    "title": "Уведомления",
    "markAllRead": "Отметить все как прочитанные",
    "viewAll": "Показать все уведомления",
    "noMore": "Больше уведомлений нет",
    "scrollForMore": "Прокрутите для загрузки",
    "empty": "Уведомлений пока нет",
    "postedComment": "оставил(а) комментарий в",
    "mentionedYou": "упомянул(а) вас в",
    "unread": "Не прочитано",
    "loading": "Загрузка уведомлений..."
  }
}
```

### Acceptance Criteria

- [ ] All strings added to en.json
- [ ] All strings added to ru-RU.json
- [ ] Translations display correctly in both languages

---

## File Summary

### Backend Files

| File | Action | Purpose |
|------|--------|---------|
| `prisma/schema.prisma` | Modify | Add Notification model + enum |
| `src/notifications/notifications.module.ts` | Create | NestJS module |
| `src/notifications/notifications.controller.ts` | Create | REST endpoints |
| `src/notifications/notifications.service.ts` | Create | Business logic |
| `src/notifications/dto/notification-response.dto.ts` | Create | Response types |
| `src/comments/comments.module.ts` | Modify | Import NotificationsModule |
| `src/comments/comments.service.ts` | Modify | Inject + trigger notifications |
| `src/app.module.ts` | Modify | Import NotificationsModule |

### Frontend Files

| File | Action | Purpose |
|------|--------|---------|
| `auth/api/notifications.ts` | Create | API client |
| `auth/api/types.ts` | Modify | Add notification interfaces |
| `auth/api/index.ts` | Modify | Re-export notifications |
| `lib/queryClient.ts` | Modify | Add query keys |
| `hooks/useNotifications.ts` | Create | React Query hooks |
| `components/Notifications/index.ts` | Create | Public exports |
| `components/Notifications/notificationsState.ts` | Create | Jotai atoms |
| `components/Notifications/NotificationBell/*` | Create | Bell icon component |
| `components/Notifications/NotificationBadge/*` | Create | Badge component |
| `components/Notifications/NotificationPopup/*` | Create | Popup component |
| `components/Notifications/NotificationsPage/*` | Create | Full page view |
| `components/Notifications/UnreadBadge/*` | Create | Pulsing badge |
| `components/Notifications/Skeletons/*` | Create | Loading skeleton components |
| `components/Workspace/WorkspaceSidebar/SidebarFooter.tsx` | Modify | Use NotificationBell |
| `router.ts` | Modify | Add notifications route |
| `App.tsx` | Modify | Render notifications page |
| `packages/excalidraw/locales/en.json` | Modify | Add translations |
| `packages/excalidraw/locales/ru-RU.json` | Modify | Add translations |

---

## Progress Checklist

### Phase 1: Backend - Database & Module ✅
- [x] Create Prisma schema migration
- [x] Create notifications module structure
- [x] Implement list notifications endpoint
- [x] Implement unread count endpoint
- [x] Implement mark as read endpoint
- [x] Implement mark all as read endpoint
- [x] Add proper indexes for performance

### Phase 2: Backend - Comment Integration ✅
- [x] Inject NotificationsService into CommentsService
- [x] Add notification triggers to createThread
- [x] Add notification triggers to addComment
- [x] Add getThreadParticipants helper method
- [x] Test notification creation

### Phase 3: Frontend - API & State ✅
- [x] Create `auth/api/notifications.ts`
- [x] Add TypeScript interfaces to `types.ts`
- [x] Add query keys to `queryClient.ts`
- [x] Add mutation keys to `queryClient.ts`
- [x] Create `useNotifications` hook
- [x] Create `useUnreadCount` hook
- [x] Create `useNotificationMutations` hook
- [x] Create Jotai atoms

### Phase 4: Frontend - Bell & Popup ✅
- [x] Create NotificationBell component
- [x] Create NotificationBadge component
- [x] Create NotificationPopup component
- [x] Create NotificationPopupItem component
- [x] Create NotificationItemSkeleton component (loading state)
- [x] Update SidebarFooter to use NotificationBell
- [x] Add click-outside handling

### Phase 5: Frontend - Notifications Page ✅
- [x] Add notifications route to router.ts
- [x] Create NotificationsPage component
- [x] Create NotificationTimelineItem component
- [x] Create UnreadBadge component
- [x] Implement infinite scroll
- [x] Integrate with WorkspaceMainContent

### Phase 6: Translations ✅
- [x] Add strings to en.json
- [x] Add strings to ru-RU.json

---

## Estimated Effort

| Phase | Complexity | Estimate |
|-------|------------|----------|
| Phase 1: Backend Database & Module | M | 1-2 days |
| Phase 2: Backend Comment Integration | S | 0.5 day |
| Phase 3: Frontend API & State | S | 0.5 day |
| Phase 4: Frontend Bell & Popup | M | 1-2 days |
| Phase 5: Frontend Notifications Page | M | 1-2 days |
| Phase 6: Translations | S | 0.5 day |
| **Total** | | **4-7 days** |

---

## Implementation Order

1. **Backend first** (Phases 1-2) - Database, module, comment integration
2. **Frontend state** (Phase 3) - API client, hooks, atoms
3. **Bell + Popup** (Phase 4) - Most visible feature
4. **Full page** (Phase 5) - Complete experience
5. **Translations** (Phase 6) - Polish

This order allows incremental testing - you can verify notifications are being created in the database before building the UI.

---

## Related Documentation

- [NOTIFICATION_SYSTEM_RESEARCH.md](NOTIFICATION_SYSTEM_RESEARCH.md) - UI/UX research from Excalidraw Plus
- [COMMENT_SYSTEM_IMPLEMENTATION_PLAN.md](COMMENT_SYSTEM_IMPLEMENTATION_PLAN.md) - Comment system that triggers notifications
- [TECHNICAL_DEBT_AND_IMPROVEMENTS.md](TECHNICAL_DEBT_AND_IMPROVEMENTS.md) - Established patterns to follow (React Query, skeletons, etc.)
- [STATE_MANAGEMENT.md](../architecture/STATE_MANAGEMENT.md) - Jotai + React Query patterns
- [URL_ROUTING.md](../architecture/URL_ROUTING.md) - URL routing patterns

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-24 | Phase 5: Frontend Notifications Page complete (NotificationsPage, NotificationTimelineItem, UnreadBadge, routing) |
| 2025-12-24 | Phase 6: Translations complete (en.json, ru-RU.json) |
| 2025-12-24 | Phase 4: Frontend Bell & Popup complete (NotificationBell, NotificationBadge, NotificationPopup, skeletons) |
| 2025-12-24 | Phase 3: Frontend API & State complete (API client, types, hooks, atoms) |
| 2025-12-24 | Phase 2: Backend Comment Integration complete (notification triggers in CommentsService) |
| 2025-12-24 | Phase 1: Backend Database & Module complete (schema, migration, endpoints, service) |
| 2025-12-24 | Added skeleton loading components following Tech Debt #7 pattern |
| 2025-12-24 | Added mutation keys to queryClient.ts (Tech Debt #8 pattern) |
| 2025-12-24 | Added additional translation keys (scrollForMore, loading) |
| 2025-12-24 | Initial implementation plan created |

