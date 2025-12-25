# Comment System

AstraDraw includes a threaded comment system that allows collaborators to discuss specific elements on the canvas.

## Features

### Canvas-Anchored Comments

- Comments are anchored to specific positions on the canvas
- Comment markers follow elements when they move
- Markers are visible to all collaborators in real-time

### Threaded Discussions

- Create comment threads with multiple replies
- @mention other workspace members
- Resolve threads when discussions are complete
- Reopen resolved threads if needed

### Real-Time Sync

- Comments sync instantly across all collaborators
- See when others are typing
- Notifications for mentions and replies

## Usage

### Creating a Comment

1. Click the comment tool in the toolbar (or press `C`)
2. Click on the canvas where you want to add a comment
3. Type your comment and press Enter or click Submit

### Replying to Comments

1. Click on a comment marker on the canvas
2. The comment thread opens in the sidebar
3. Type your reply in the input field
4. Press Enter or click Reply

### Mentioning Users

Type `@` followed by a username to mention someone:

```
@alice Can you review this section?
```

Mentioned users will receive a notification.

### Resolving Threads

1. Open the comment thread
2. Click the "Resolve" button
3. Resolved threads are hidden by default but can be shown via the filter

## Permissions

| Role | Can View | Can Create | Can Edit Own | Can Delete |
|------|----------|------------|--------------|------------|
| Viewer | ✅ | ❌ | ❌ | ❌ |
| Member | ✅ | ✅ | ✅ | Own only |
| Admin | ✅ | ✅ | ✅ | All |

## API Endpoints

### Threads

```
GET    /api/v2/workspaces/:slug/scenes/:id/comments/threads
POST   /api/v2/workspaces/:slug/scenes/:id/comments/threads
GET    /api/v2/workspaces/:slug/scenes/:id/comments/threads/:threadId
PUT    /api/v2/workspaces/:slug/scenes/:id/comments/threads/:threadId
DELETE /api/v2/workspaces/:slug/scenes/:id/comments/threads/:threadId
POST   /api/v2/workspaces/:slug/scenes/:id/comments/threads/:threadId/resolve
POST   /api/v2/workspaces/:slug/scenes/:id/comments/threads/:threadId/reopen
```

### Comments

```
POST   /api/v2/workspaces/:slug/scenes/:id/comments/threads/:threadId/comments
PUT    /api/v2/workspaces/:slug/scenes/:id/comments/threads/:threadId/comments/:commentId
DELETE /api/v2/workspaces/:slug/scenes/:id/comments/threads/:threadId/comments/:commentId
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `C` | Activate comment tool |
| `Escape` | Close comment panel |
| `Enter` | Submit comment (when focused) |

## Related Documentation

- [Collaboration](COLLABORATION.md) - Real-time collaboration features
- [Notifications](NOTIFICATIONS.md) - Notification system for mentions

