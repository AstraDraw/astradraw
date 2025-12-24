# AstraDraw Roadmap

This document outlines planned features and their specifications.

## Completed Features

- [x] S3/MinIO storage backend
- [x] Any URL iframe embedding
- [x] Split into separate repos (astradraw-app, astradraw-api, astradraw-room)
- [x] User authentication (local + OIDC)
- [x] Personal workspaces with scene management
- [x] Talktrack video recordings
- [x] Presentation mode
- [x] Custom pens
- [x] GIPHY integration
- [x] User profile management
- [x] Auto-save for workspace scenes

## Planned Features

### Comments System

Add commenting functionality for workspace scenes. Since we already have user authentication and workspaces, this will integrate with existing infrastructure.

**Core Features:**
- Comment markers on canvas (positioned at specific coordinates)
- Threaded replies
- @mentions for other users
- Read/unread tracking
- Resolve/unresolve comments

**Integration Points:**
- Uses existing `User` model for authors
- Uses existing `Scene` model for scene association
- Real-time updates via WebSocket (extend room-service or separate)

**Database Schema (extend existing Prisma schema):**

```prisma
model Comment {
  id          String    @id @default(uuid())
  text        String
  positionX   Float?
  positionY   Float?
  resolved    Boolean   @default(false)
  
  // Relations
  sceneId     String
  scene       Scene     @relation(fields: [sceneId], references: [id], onDelete: Cascade)
  authorId    String
  author      User      @relation(fields: [authorId], references: [id])
  parentId    String?
  parent      Comment?  @relation("CommentReplies", fields: [parentId], references: [id])
  replies     Comment[] @relation("CommentReplies")
  
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt
}

model CommentRead {
  userId      String
  user        User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  commentId   String
  comment     Comment   @relation(fields: [commentId], references: [id], onDelete: Cascade)
  readAt      DateTime  @default(now())
  
  @@id([userId, commentId])
}
```

**API Endpoints:**

```
GET    /api/v2/workspace/scenes/:sceneId/comments
POST   /api/v2/workspace/scenes/:sceneId/comments
PUT    /api/v2/comments/:id
DELETE /api/v2/comments/:id
POST   /api/v2/comments/:id/resolve
POST   /api/v2/comments/:id/read
```

**Frontend Components:**

```
excalidraw-app/components/Comments/
├── CommentsPanel.tsx       # Sidebar panel (list, search, filter)
├── CommentMarker.tsx       # Canvas marker overlay
├── CommentPopup.tsx        # Thread popup on marker click
├── CommentForm.tsx         # Create/edit form
└── commentsApi.ts          # API client
```

**Implementation Notes:**
- Reuse existing `WorkspaceSidebar` pattern for Comments panel
- Reuse existing `workspaceApi.ts` patterns for API client
- Consider adding Comments tab to existing AppSidebar
- Real-time updates can be added later (start with polling/refresh)

---

## Low Priority / Future Considerations

- **Notifications** - Email/push notifications for @mentions
- **Teams/Organizations** - Shared workspaces for teams
- **Version History** - Scene versioning and rollback
- **Export Improvements** - PDF export, batch export
- **Mobile App** - React Native wrapper
- **Offline Support** - Service worker for offline editing
