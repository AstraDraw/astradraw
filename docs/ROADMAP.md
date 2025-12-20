# AstraDraw Roadmap

This document outlines planned features and their specifications.

## Completed Features

- [x] S3/MinIO storage backend
- [x] Any URL iframe embedding
- [x] Split into separate repos (astradraw-app, astradraw-storage)
- [x] User authentication (local + OIDC)
- [x] Personal workspaces with scene management
- [x] Talktrack video recordings
- [x] Presentation mode
- [x] Custom pens
- [x] GIPHY integration
- [x] User profile management
- [x] Auto-save for workspace scenes

## Planned Features

### Named Rooms with Shared Encryption Key

Allow users to create human-readable room URLs like `#room=project-kickoff` instead of random IDs.

**Design:**
- Add `VITE_APP_SHARED_ENCRYPTION_KEY` env var for server-wide shared key
- When creating a session, user can choose:
  - **Quick room** (default): Random ID + unique encryption key → `#room=a1b2c3,<unique-key>`
  - **Named room**: Custom name + shared key → `#room=my-project`
- When joining: If URL has no key, use shared key from config

**UI Changes:**
- Add radio buttons in "Start collaboration" modal
- Add text input for custom room name when "Named room" selected

---

### Path-Based Routing for SSO Integration

Change from hash-based (`/#room=...`) to path-based (`/room/...`) routing to enable per-room access control via forward proxy (Authentik, etc.).

**Current (hash-based):**
```
https://draw.example.com/#room=finance-budget
```
- Server sees: `GET /` (cannot distinguish rooms)
- SSO proxy cannot apply per-room policies

**Proposed (path-based):**
```
https://draw.example.com/room/finance/budget-2025
https://draw.example.com/room/hr/onboarding
https://draw.example.com/room/public/whiteboard
```
- Server sees full path
- SSO proxy can apply policies:
  - `/room/finance/*` → Finance AD group only
  - `/room/hr/*` → HR AD group only
  - `/room/public/*` → All authenticated users

**Implementation Required:**
1. React Router with path-based routes (replace hash routing)
2. Nginx config for SPA fallback (return `index.html` for `/room/*`)
3. Traefik routing updates
4. Support encryption key via query param: `/room/name?key=<key>`

**Benefits:**
- Granular access control per room/department
- Clean, shareable URLs
- Compatible with enterprise SSO policies

---

### Comments System

Add full commenting functionality similar to Excalidraw+ but self-hosted.

**Features:**
- User avatars in header showing online collaborators
- Comment markers on canvas (colored circles with avatars)
- Popup thread view when clicking a marker
- Sidebar with all comments, search, sort, and filter
- Threaded replies with @mentions
- Read/unread tracking
- Resolve/unresolve comments

**Current State:**
- UI placeholder exists in `AppSidebar.tsx`
- Comments tab with icon is present but shows promo for Excalidraw+
- No backend support for comments

**Prerequisites:**
- SSO/Authentication ✅ (completed)
- PostgreSQL ✅ (completed)
- WebSocket support (extend excalidraw-room or separate service)

#### Database Schema

```sql
-- Comments
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id VARCHAR NOT NULL,
  element_id VARCHAR,                   -- Attached to specific element
  parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES users(id),
  text TEXT NOT NULL,
  position_x FLOAT,
  position_y FLOAT,
  resolved BOOLEAN DEFAULT FALSE,
  resolved_by UUID REFERENCES users(id),
  resolved_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Read status tracking
CREATE TABLE comment_reads (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  read_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (user_id, comment_id)
);

-- @mentions
CREATE TABLE comment_mentions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  mentioned_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  notified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Online presence
CREATE TABLE room_presence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id VARCHAR NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  socket_id VARCHAR NOT NULL,
  cursor_x FLOAT,
  cursor_y FLOAT,
  last_seen TIMESTAMP DEFAULT NOW(),
  connected_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(room_id, user_id, socket_id)
);
```

#### API Endpoints

```
# Comments CRUD
GET    /api/v2/rooms/:roomId/comments
POST   /api/v2/rooms/:roomId/comments
GET    /api/v2/comments/:id
PUT    /api/v2/comments/:id
DELETE /api/v2/comments/:id

# Comment actions
POST   /api/v2/comments/:id/resolve
POST   /api/v2/comments/:id/unresolve
POST   /api/v2/comments/:id/read
POST   /api/v2/rooms/:roomId/comments/read-all
GET    /api/v2/comments/:id/link

# Presence
GET    /api/v2/rooms/:roomId/presence

# WebSocket events:
#   - user:join, user:leave, user:cursor
#   - comment:new, comment:update, comment:delete, comment:resolve
```

#### Frontend Components

```
excalidraw-app/
├── comments/
│   ├── CommentsPanel.tsx         # Sidebar panel
│   ├── CommentThread.tsx         # Thread view
│   ├── CommentPopup.tsx          # Canvas popup
│   ├── CommentMarkerLayer.tsx    # Canvas overlay
│   ├── CommentMarker.tsx         # Individual marker
│   ├── CommentForm.tsx           # Create/edit form
│   ├── MentionInput.tsx          # @mention input
│   ├── MentionDropdown.tsx       # User search
│   ├── CommentsContext.tsx       # State management
│   ├── commentsApi.ts            # API client
│   └── commentsSocket.ts         # WebSocket handlers
├── presence/
│   ├── PresenceAvatars.tsx       # Online users header
│   ├── UserCursor.tsx            # Cursor on canvas
│   ├── PresenceContext.tsx       # State management
│   └── presenceSocket.ts         # WebSocket handlers
```

#### Implementation Phases

| Phase | Scope | Estimate |
|-------|-------|----------|
| 1. Presence System | Backend + frontend | 3-4 days |
| 2. Comments Backend | API + database | 3-4 days |
| 3. Comments Sidebar | List, search, filter | 3-4 days |
| 4. Canvas Markers | Markers + popup | 4-5 days |
| 5. @Mentions | Autocomplete + tracking | 2-3 days |
| 6. Polish | Deep links, animations | 2-3 days |
| **Total** | | **~4-5 weeks** |

---

## Low Priority / Future Considerations

- **Notifications** - Email/push notifications for @mentions
- **Teams/Organizations** - Shared workspaces for teams
- **Version History** - Scene versioning and rollback
- **Export Improvements** - PDF export, batch export
- **Mobile App** - React Native wrapper
- **Offline Support** - Service worker for offline editing

