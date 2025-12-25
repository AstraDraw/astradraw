# Notification System

AstraDraw includes an in-app notification system to keep users informed about activity in their workspaces.

## Features

### Notification Types

| Type | Trigger | Description |
|------|---------|-------------|
| **Mention** | @username in comment | Someone mentioned you in a comment |
| **Comment** | Reply to thread | Someone replied to a thread you participated in |

### Notification Bell

- Located in the workspace sidebar
- Shows unread count badge
- Click to open notification dropdown
- Quick access to recent notifications

### Notifications Page

- Full timeline view of all notifications
- Infinite scroll for history
- Mark individual or all as read
- Filter by read/unread status

## Usage

### Viewing Notifications

1. Click the bell icon in the sidebar
2. See your recent notifications in the dropdown
3. Click "View All" to see the full notifications page

### Marking as Read

- **Individual:** Click on a notification to mark it as read
- **All:** Click "Mark all as read" button

### Navigating to Source

Click on a notification to:
1. Navigate to the relevant scene
2. Open the comment thread (for comment notifications)
3. Highlight the mentioned content

## API Endpoints

```
GET  /api/v2/notifications           # List notifications (paginated)
GET  /api/v2/notifications/unread-count  # Get unread count
POST /api/v2/notifications/:id/read  # Mark single as read
POST /api/v2/notifications/read-all  # Mark all as read
```

### Query Parameters

| Parameter | Description |
|-----------|-------------|
| `cursor` | Pagination cursor for next page |
| `limit` | Number of notifications per page (default: 20) |
| `unread` | Filter to unread only (`true`/`false`) |

## Notification Behavior

### Who Gets Notified

**Mentions:**
- Only the mentioned user receives a notification
- Self-mentions are ignored (you won't notify yourself)

**Comment Replies:**
- All participants in the thread receive notifications
- The comment author is excluded (you won't notify yourself)
- Users who have been mentioned are excluded (they get a mention notification instead)

### Real-Time Updates

- Notification count updates in real-time via WebSocket
- New notifications appear instantly in the bell dropdown
- No page refresh required

## Permissions

Notifications are only created for users who have at least VIEW access to the scene where the comment was made.

## Related Documentation

- [Comments](COMMENTS.md) - Comment system that triggers notifications
- [Collaboration](COLLABORATION.md) - Real-time collaboration features
- [Workspace](WORKSPACE.md) - Workspace and permission model

