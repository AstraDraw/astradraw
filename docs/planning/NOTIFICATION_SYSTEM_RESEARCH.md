# Notification System Research & Implementation Plan

## Overview

This document outlines the notification system for AstraDraw, based on research from Excalidraw Plus. The notification system is primarily used for comment-related notifications but can be extended for other events.

> **Related:** See [Comment System Research](COMMENT_SYSTEM_RESEARCH.md) for the comment/thread implementation.

---

## Notification Types

| Type | Icon | Message Format | Trigger |
|------|------|----------------|---------|
| **COMMENT** | 💬 (speech bubble) | "{User} **posted a comment** in {Scene}" | New comment on a scene user has access to |
| **MENTION** | @ (at symbol) | "{User} **mentioned you** in {Scene}" | User is @mentioned in a comment |

---

## UI Components

### 1. Notification Bell Icon (Sidebar Footer)

**Location:** Bottom of left sidebar, next to user profile

**HTML Structure:**
```html
<button class="hover:bg-transparent active:bg-transparent">
  <div class="relative flex cursor-pointer items-center justify-center rounded-md border-[1px] border-solid border-surface-high bg-transparent p-2 text-xl text-on-surface hover:!bg-surface-high">
    <!-- Bell SVG icon -->
    <svg viewBox="0 0 24 24" fill="none">
      <path d="M12 1.996a7.49 7.49 0 0 1 7.496 7.25l.004.25v4.097l1.38 3.156a1.25 1.25 0 0 1-1.145 1.75L15 18.502a3 3 0 0 1-5.995.177L9 18.499H4.275a1.251 1.251 0 0 1-1.147-1.747L4.5 13.594V9.496c0-4.155 3.352-7.5 7.5-7.5ZM13.5 18.5l-3 .002a1.5 1.5 0 0 0 2.993.145l.006-.147ZM12 3.496c-3.32 0-6 2.674-6 6v4.41L4.656 17h14.697L18 13.907V9.509l-.004-.225A5.988 5.988 0 0 0 12 3.496Z" fill="currentColor"/>
    </svg>
    
    <!-- Badge with count -->
    <div class="pointer-events-none absolute -right-2 -top-2 rounded-full bg-primary px-[5px] py-[1px] text-[9px] leading-3 text-white">
      5+
    </div>
  </div>
</button>
```

**Badge behavior:**
- Shows count of unread notifications
- If count > 5: shows "5+"
- Hidden when count is 0

---

### 2. Notification Popup (Quick View)

**Trigger:** Click bell icon

**Width:** 300px

**Structure:**
```
┌─────────────────────────────────────────────────┐
│ Notifications              Mark all as read     │
├─────────────────────────────────────────────────┤
│ [👤] Mr. Khachaturov posted a new        [✓]   │
│     comment in Collub                           │
│     a minute ago                                │
├─────────────────────────────────────────────────┤
│ [👤] Mr. Khachaturov mentioned you       [✓]   │
│ [@]  in Collub                                  │
│     a minute ago                                │
├─────────────────────────────────────────────────┤
│        [View all notifications]                 │
└─────────────────────────────────────────────────┘
```

**HTML Structure:**
```html
<div class="w-[300px] rounded-md bg-white shadow-context-menu dark:bg-surface-low">
  <!-- Header -->
  <h3 class="m-0 flex items-center justify-between px-3 py-2 text-lg font-bold text-primary shadow-border-b">
    Notifications
    <span class="cursor-pointer text-xs font-normal text-gray-80 hover:underline">
      Mark all as read
    </span>
  </h3>
  
  <!-- Notification items -->
  <div class="shadow-border-b mt-2 pb-2">
    <!-- Each notification item -->
    <div class="group/parent mx-3 flex rounded px-1 py-2 hover:bg-surface-high">
      <div class="flex cursor-pointer select-none flex-row">
        <!-- Avatar -->
        <div class="flex h-10 w-10 flex-shrink-0 items-center justify-center">
          <img class="rounded-full" src="..." style="width: 36px; height: 36px;">
        </div>
        <!-- Content -->
        <div class="ml-2 p-1">
          <div class="text-sm">
            <b>Mr. Khachaturov</b> posted a new comment in <b>Collub</b>
          </div>
          <div class="text-xs text-gray-60">a minute ago</div>
        </div>
      </div>
      <!-- Mark as read button (visible on hover) -->
      <div class="group/button invisible group-hover/parent:visible">
        <div class="flex h-6 w-6 cursor-pointer items-center justify-center rounded-md">
          <svg class="Icon-check"><!-- Checkmark --></svg>
        </div>
      </div>
    </div>
  </div>
  
  <!-- Footer -->
  <div class="px-3 py-2">
    <a href="/workspace/{slug}/notifications">
      <button class="w-full bg-primary text-white rounded-md py-2.5">
        View all notifications
      </button>
    </a>
  </div>
</div>
```

**Popup features:**
- "Mark all as read" link in header
- Hover on item shows checkmark button to mark single as read
- Marked items disappear from popup
- "View all notifications" button navigates to full page

---

### 3. Notifications Page (Full View)

**URL Pattern:** `/workspace/{slug}/notifications`

**Layout:** Timeline view with vertical line connecting items

**Structure:**
```
┌─────────────────────────────────────────────────────────────┐
│ Notifications                                               │
├─────────────────────────────────────────────────────────────┤
│ ─────────────────────────────────────────────────────────── │
│                                                             │
│ [👤]  Mr. Khachaturov posted a comment in 📄 Collub        │
│ [💬]  ⏱ 4 minutes ago                                      │
│   │                                                         │
│   │                                                         │
│ [👤]  Mr. Khachaturov mentioned you in 📄 Collub           │
│ [@]   ⏱ 4 minutes ago   [● Unread]                         │
│   │                      ↑ animated pulsing dot            │
│   │                                                         │
│   ▼                                                         │
│                                                             │
│ No more notifications                                       │
└─────────────────────────────────────────────────────────────┘
```

**Notification item features:**
- Avatar with type icon overlay (💬 for comment, @ for mention)
- Clickable action text → navigates to comment with focus
- Clickable scene name → navigates to scene without comment focus
- Relative timestamp ("4 minutes ago")
- "Unread" badge with pulsing animation for unread items
- Vertical timeline line connecting items
- Infinite scroll (notifications are kept forever)
- "No more notifications" message at bottom

**Unread Badge HTML:**
```html
<span class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-primary-light">
  <div class="relative mr-1.5 flex h-3 w-3">
    <!-- Pulsing animation -->
    <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-indigo-400 opacity-75 dark:bg-indigo-200"></span>
    <span class="relative inline-flex h-3 w-3 rounded-full bg-indigo-500 dark:bg-indigo-300"></span>
  </div>
  Unread
</span>
```

---

## Notification Links

**Link format:** `/workspace/{slug}/scene/{sceneId}?thread={threadId}`

**Click behaviors:**
| Click Target | Navigation |
|--------------|------------|
| Action text ("posted a comment", "mentioned you") | Scene + comment focused |
| Scene name | Scene only (no comment focus) |

**Auto-read behavior:** Navigating via notification link marks it as read automatically when returning.

---

## Data Retention

- **Notifications are kept forever** (no auto-deletion)
- Users can scroll back to notifications from years ago
- No manual delete option - only "mark as read"

---

## Database Schema

```prisma
model Notification {
  id        String   @id @default(cuid())
  
  // Recipient
  userId    String
  user      User     @relation("UserNotifications", fields: [userId], references: [id], onDelete: Cascade)
  
  // Type
  type      NotificationType  // COMMENT | MENTION
  
  // Actor (who triggered the notification)
  actorId   String
  actor     User              @relation("ActorNotifications", fields: [actorId], references: [id])
  
  // References
  threadId  String?
  thread    CommentThread?    @relation(fields: [threadId], references: [id], onDelete: Cascade)
  commentId String?
  comment   Comment?          @relation(fields: [commentId], references: [id], onDelete: Cascade)
  sceneId   String
  scene     Scene             @relation(fields: [sceneId], references: [id], onDelete: Cascade)
  
  // Status
  read      Boolean  @default(false)
  readAt    DateTime?
  
  createdAt DateTime @default(now())
  
  @@index([userId, read])
  @@index([userId, createdAt])
}

enum NotificationType {
  COMMENT   // Someone posted a comment on a scene you have access to
  MENTION   // Someone mentioned you in a comment
}
```

**Add to User model:**
```prisma
model User {
  // ... existing fields ...
  
  notifications      Notification[] @relation("UserNotifications")
  actorNotifications Notification[] @relation("ActorNotifications")
}
```

---

## API Endpoints

```
GET    /api/notifications                    # List notifications (paginated)
GET    /api/notifications/unread-count       # Get unread count for badge
POST   /api/notifications/:id/read           # Mark single as read
POST   /api/notifications/read-all           # Mark all as read
```

**GET /api/notifications query params:**
```
?limit=20           # Items per page (default 20)
?cursor={id}        # Cursor for pagination (last notification ID)
?unread=true        # Filter unread only (optional)
```

**Response:**
```json
{
  "notifications": [
    {
      "id": "notif-123",
      "type": "MENTION",
      "actor": {
        "id": "user-456",
        "name": "Mr. Khachaturov",
        "avatar": "https://..."
      },
      "thread": { "id": "thread-789" },
      "scene": {
        "id": "scene-abc",
        "name": "Collub"
      },
      "read": false,
      "createdAt": "2025-12-23T15:30:00Z"
    }
  ],
  "nextCursor": "notif-100",
  "hasMore": true
}
```

---

## Frontend Components

```
frontend/excalidraw-app/components/Notifications/
├── index.ts                        # Public exports
├── types.ts                        # TypeScript interfaces
│
├── # State & Hooks
├── notificationsState.ts           # Jotai atoms (unreadCount, isPopupOpen)
├── useNotifications.ts             # React Query hook for notifications list
├── useUnreadCount.ts               # React Query hook for badge count
├── useNotificationMutations.ts     # Mark read, mark all read
│
├── # Bell Icon & Popup
├── NotificationBell.tsx            # Bell icon with badge (sidebar footer)
├── NotificationPopup.tsx           # Quick view popup
├── NotificationPopupItem.tsx       # Single item in popup
│
├── # Full Page View
├── NotificationsPage.tsx           # Full notifications page (dashboard view)
├── NotificationTimelineItem.tsx    # Single item in timeline
├── UnreadBadge.tsx                 # Pulsing "Unread" badge
│
└── # Styles
└── Notifications.module.scss
```

**TypeScript interfaces:**

```typescript
export type NotificationType = 'COMMENT' | 'MENTION';

export interface Notification {
  id: string;
  type: NotificationType;
  actor: {
    id: string;
    name: string;
    avatar?: string;
  };
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

---

## URL Routing

Add to `router.ts`:

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

---

## Implementation Phases

### Phase 1: Backend
- [ ] Create Notification model in Prisma
- [ ] Create notifications module (controller, service)
- [ ] Implement CRUD endpoints
- [ ] Create notification on comment/mention events

### Phase 2: Frontend - Bell & Popup
- [ ] Add NotificationBell to sidebar footer
- [ ] Implement unread count hook
- [ ] Create NotificationPopup component
- [ ] Implement mark as read functionality

### Phase 3: Frontend - Full Page
- [ ] Add notifications route
- [ ] Create NotificationsPage component
- [ ] Implement infinite scroll
- [ ] Add timeline UI with unread badges

### Phase 4: Integration
- [ ] Trigger notifications from comment service
- [ ] Handle @mentions → create MENTION notifications
- [ ] Auto-read on navigation via notification link

---

## Screenshots Reference

1. **Notification bell with badge** - Count display (1, 5+)
2. **Notification popup** - Quick view with items
3. **Popup item hover** - Mark as read checkmark
4. **Notifications page** - Full timeline view
5. **Unread badge** - Pulsing animation effect
6. **Notification types** - Comment vs Mention icons

*(Screenshots stored locally, referenced in chat history)*

