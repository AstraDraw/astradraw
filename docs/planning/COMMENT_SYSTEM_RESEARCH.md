# Comment System Research & Implementation Plan

## Overview

This document outlines the research phase for implementing a comment system in AstraDraw. The goal is to allow registered users to leave comments on specific locations on the canvas, similar to how Excalidraw Plus implements this feature.

## Current State in AstraDraw

### Existing Placeholder

AstraDraw already has a placeholder for comments in the sidebar:

```tsx
// frontend/excalidraw-app/components/AppSidebar/AppSidebar.tsx
<Sidebar.Tab tab="comments">
  <div className={styles.promoContainer}>
    <div className={styles.promoImage} ... />
    <div className={styles.promoText}>{t("comments.promoTitle")}</div>
    <div className={styles.promoComingSoon}>{t("comments.comingSoon")}</div>
  </div>
</Sidebar.Tab>
```

Locale strings exist:
```json
// packages/excalidraw/locales/en.json
"comments": {
  "promoTitle": "Make comments with AstraDraw",
  "comingSoon": "Coming soon"
}
```

### Key Extension Points

1. **Sidebar Tab** - Already has a "comments" tab placeholder
2. **`renderTopRightUI` / `renderTopLeftUI`** - Props for custom UI overlays
3. **`children` prop** - Can render custom components inside LayerUI
4. **Canvas coordinates** - `sceneCoordsToViewportCoords` / `viewportCoordsToSceneCoords` utilities available

---

## Research: Gathering Information from Excalidraw Plus

### Option 1: Visual Documentation (Screenshots)

Take screenshots of the following scenarios in Excalidraw Plus:

1. **Comment marker on canvas** - How it appears when placed
2. **Comment creation flow** - Click location → comment input
3. **Comment thread view** - How replies are displayed
4. **Comment sidebar** - List of all comments
5. **Comment editing/deletion** - UI for managing comments
6. **Resolved comments** - How resolved comments appear
7. **Mobile view** - How comments work on mobile

### Option 2: Browser DevTools Analysis

Open Excalidraw Plus and use browser DevTools to extract implementation details:

#### Network Tab Analysis
```bash
# Open DevTools → Network tab → Filter by "XHR/Fetch"
# Perform these actions and capture the API calls:

1. Create a new comment
2. Reply to a comment
3. Resolve a comment
4. Delete a comment
5. Load a scene with existing comments
```

**What to capture:**
- API endpoint URLs
- Request/response payloads (JSON structure)
- HTTP methods used

#### DOM Structure Analysis
```bash
# Open DevTools → Elements tab
# Inspect these UI components:

1. Comment marker on canvas (the pin/bubble)
2. Comment input popover
3. Comment thread panel
4. Comments list in sidebar
```

**What to capture:**
- HTML structure
- CSS classes used
- Component hierarchy

#### React DevTools Analysis
```bash
# Install React DevTools extension
# Open DevTools → Components tab

1. Find comment-related components
2. Inspect their props and state
3. Identify the state management approach
```

**What to capture:**
- Component names
- Props structure
- State shape

#### Console Commands for Analysis
```javascript
// In browser console on Excalidraw Plus page:

// 1. Find React root and explore state
const reactRoot = document.getElementById('root');
const reactFiber = Object.keys(reactRoot).find(key => key.startsWith('__reactFiber'));
console.log(reactRoot[reactFiber]);

// 2. Search for comment-related code in sources
// DevTools → Sources → Ctrl+Shift+F → search for:
//   - "comment"
//   - "thread"
//   - "annotation"

// 3. Monitor Redux/state changes (if using Redux DevTools)
// Look for actions like:
//   - ADD_COMMENT
//   - RESOLVE_COMMENT
//   - DELETE_COMMENT

// 4. Intercept network requests
const originalFetch = window.fetch;
window.fetch = async (...args) => {
  console.log('Fetch:', args[0], args[1]);
  const result = await originalFetch(...args);
  return result;
};
```

### Option 3: Source Code Analysis (if available)

Check if any comment-related code exists in the open-source Excalidraw:

```bash
# In the Excalidraw repository
git log --oneline --all --grep="comment" | head -20
git log --oneline --all --grep="annotation" | head -20

# Search for comment-related files
find . -name "*comment*" -type f
find . -name "*annotation*" -type f
```

---

## Expected Data Model

Based on typical comment system implementations:

### Comment Entity

```typescript
interface Comment {
  id: string;
  sceneId: string;
  
  // Canvas position (scene coordinates)
  x: number;
  y: number;
  
  // Optional: anchor to specific element
  anchoredElementId?: string;
  
  // Content
  content: string;
  
  // Thread management
  parentId?: string;  // null for root comments, set for replies
  threadId: string;   // groups all comments in a thread
  
  // Status
  resolved: boolean;
  resolvedAt?: Date;
  resolvedBy?: string;
  
  // Metadata
  createdAt: Date;
  updatedAt: Date;
  createdBy: string;  // user ID
  
  // Author info (denormalized for display)
  author: {
    id: string;
    name: string;
    avatar?: string;
  };
}
```

### Comment Thread

```typescript
interface CommentThread {
  id: string;
  sceneId: string;
  x: number;
  y: number;
  anchoredElementId?: string;
  resolved: boolean;
  comments: Comment[];
  participantIds: string[];
  createdAt: Date;
  updatedAt: Date;
}
```

---

## Proposed Architecture

### Frontend Components

```
frontend/excalidraw-app/components/Comments/
├── index.ts                      # Public exports
├── types.ts                      # TypeScript interfaces
│
├── # State & Hooks
├── commentsState.ts              # Jotai atoms (selectedThreadId, isCreating, filters)
├── useThreads.ts                 # React Query hook for threads list
├── useThread.ts                  # React Query hook for single thread
├── useThreadMutations.ts         # Create, resolve, delete mutations
├── useCommentMutations.ts        # Add reply, edit, delete mutations
│
├── # Canvas Layer
├── ThreadMarkersLayer.tsx        # Overlay container for all markers
├── ThreadMarker.tsx              # Single marker (pin with avatar)
├── ThreadMarkerTooltip.tsx       # Hover tooltip with preview
├── CommentCreationOverlay.tsx    # Click-to-create cursor mode
│
├── # Sidebar Panel
├── CommentsSidebar.tsx           # Main sidebar panel
├── CommentsSidebarHeader.tsx     # Search + filter controls
├── ThreadListItem.tsx            # Single thread in sidebar list
├── ThreadList.tsx                # Scrollable list of threads
│
├── # Thread Popup
├── ThreadPopup.tsx               # Popup container (positioned near marker)
├── ThreadPopupHeader.tsx         # Resolve, link, delete, close buttons
├── CommentItem.tsx               # Single comment in thread
├── CommentInput.tsx              # Reply input with emoji/mention
├── EmojiPickerButton.tsx         # Emoji picker trigger
├── MentionInput.tsx              # @mention autocomplete input
│
├── # Footer Button
├── CommentsFooterButton.tsx      # Toggle button in footer bar
│
└── # Styles
└── Comments.module.scss          # All comment styles
```

**TypeScript interfaces** (`types.ts`):

```typescript
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

export interface UserSummary {
  id: string;
  name: string;
  avatar?: string;
}

export interface ThreadFilters {
  resolved?: boolean;
  sort: 'date' | 'unread';
  search: string;
}
```

**Jotai atoms** (`commentsState.ts`):

```typescript
// UI State
export const selectedThreadIdAtom = atom<string | null>(null);
export const isCreatingCommentAtom = atom<boolean>(false);
export const commentFiltersAtom = atom<ThreadFilters>({
  resolved: undefined, // show all
  sort: 'date',
  search: '',
});

// Derived
export const isCommentsSidebarOpenAtom = atom((get) => {
  const openSidebar = get(openSidebarAtom);
  return openSidebar?.name === 'default' && openSidebar?.tab === 'comments';
});
```

### Backend API

```
backend/src/comments/
├── comments.module.ts
├── comments.controller.ts
├── comments.service.ts
├── dto/
│   ├── create-comment.dto.ts
│   ├── update-comment.dto.ts
│   └── comment-response.dto.ts
└── entities/
    └── comment.entity.ts
```

### Database Schema (Prisma)

Based on our research, we need **two models**: `CommentThread` (the anchor point on canvas) and `Comment` (individual messages in a thread).

```prisma
// ============================================================================
// Comment Thread - The anchor point on the canvas
// ============================================================================
model CommentThread {
  id        String   @id @default(cuid())
  
  // Scene relationship
  sceneId   String
  scene     Scene    @relation(fields: [sceneId], references: [id], onDelete: Cascade)
  
  // Canvas position (scene coordinates, not viewport)
  x         Float
  y         Float
  
  // Optional: anchor to specific element (for future feature)
  anchoredElementId String?
  
  // Thread status
  resolved    Boolean   @default(false)
  resolvedAt  DateTime?
  resolvedById String?
  resolvedBy  User?     @relation("ResolvedThreads", fields: [resolvedById], references: [id])
  
  // Thread creator (first comment author)
  createdById String
  createdBy   User      @relation("CreatedThreads", fields: [createdById], references: [id])
  
  // Comments in this thread
  comments    Comment[]
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@index([sceneId])
  @@index([createdById])
}

// ============================================================================
// Comment - Individual message in a thread
// ============================================================================
model Comment {
  id        String   @id @default(cuid())
  
  // Thread relationship
  threadId  String
  thread    CommentThread @relation(fields: [threadId], references: [id], onDelete: Cascade)
  
  // Content
  content   String   @db.Text  // Support long comments
  
  // Mentions (stored as JSON array of user IDs)
  mentions  String[] @default([])
  
  // Author
  createdById String
  createdBy   User      @relation("CreatedComments", fields: [createdById], references: [id])
  
  // Edit tracking
  editedAt  DateTime?
  
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  @@index([threadId])
  @@index([createdById])
}

// ============================================================================
// Add to existing User model
// ============================================================================
model User {
  // ... existing fields ...
  
  // Comments
  createdThreads    CommentThread[] @relation("CreatedThreads")
  resolvedThreads   CommentThread[] @relation("ResolvedThreads")
  createdComments   Comment[]       @relation("CreatedComments")
}

// ============================================================================
// Add to existing Scene model
// ============================================================================
model Scene {
  // ... existing fields ...
  
  // Comment threads
  commentThreads    CommentThread[]
}
```

**Why two models?**

| Aspect | Single `Comment` model | Separate `Thread` + `Comment` |
|--------|----------------------|-------------------------------|
| Position storage | Every comment stores x,y (redundant) | Only thread stores position |
| Resolved status | Need to track "root" comment | Thread has resolved flag |
| URL linking | Link to root comment ID | Link to thread ID (cleaner) |
| Reply count | COUNT(*) with threadId | `thread.comments.length` |
| Moving thread | Update all comments | Update single thread |

**Key design decisions:**

1. **Thread = anchor point** - Position stored once, not per comment
2. **Thread ID in URL** - `?thread={threadId}` not `?comment={commentId}`
3. **Cascade delete** - Deleting thread deletes all comments
4. **Mentions as array** - Simple string array of user IDs for @mentions
5. **Scene coordinates** - Store x,y in scene coords, convert to viewport on render

### API Endpoints

```
# Thread endpoints
GET    /api/scenes/:sceneId/threads              # List all threads for a scene
POST   /api/scenes/:sceneId/threads              # Create new thread (with first comment)
GET    /api/threads/:threadId                    # Get thread with all comments
PATCH  /api/threads/:threadId                    # Update thread (position)
DELETE /api/threads/:threadId                    # Delete thread and all comments
POST   /api/threads/:threadId/resolve            # Mark thread as resolved
POST   /api/threads/:threadId/reopen             # Reopen resolved thread

# Comment endpoints (within a thread)
POST   /api/threads/:threadId/comments           # Add reply to thread
PATCH  /api/comments/:commentId                  # Edit comment content
DELETE /api/comments/:commentId                  # Delete single comment
```

**Request/Response examples:**

```typescript
// POST /api/scenes/:sceneId/threads
// Create new thread with first comment
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

// GET /api/scenes/:sceneId/threads
// List threads with pagination and filters
{
  "threads": [...],
  "total": 15,
  "hasMore": true
}

// Query params:
// ?resolved=true|false  - Filter by resolved status
// ?sort=date|unread     - Sort order
// ?search=query         - Search in comment content
```

---

## Canvas Integration Approaches

### Approach 1: HTML Overlay Layer

Render comment markers as HTML elements positioned over the canvas:

```tsx
// CommentMarkersLayer.tsx
const CommentMarkersLayer: React.FC<{
  comments: CommentThread[];
  appState: AppState;
}> = ({ comments, appState }) => {
  return (
    <div className="comment-markers-layer">
      {comments.map(thread => {
        const viewport = sceneCoordsToViewportCoords(
          { sceneX: thread.x, sceneY: thread.y },
          appState
        );
        return (
          <CommentMarker
            key={thread.id}
            thread={thread}
            style={{
              position: 'absolute',
              left: viewport.x,
              top: viewport.y,
              transform: 'translate(-50%, -100%)', // anchor at bottom center
            }}
          />
        );
      })}
    </div>
  );
};
```

**Pros:**
- Easy to implement with React components
- Full CSS styling capabilities
- Click handlers work naturally
- Accessibility (keyboard nav, screen readers)

**Cons:**
- Needs manual position updates on pan/zoom
- May have slight position lag during animations

### Approach 2: Canvas Rendering

Render markers directly on the interactive canvas:

```typescript
// Extend renderInteractiveScene to draw comment markers
const renderCommentMarkers = (
  context: CanvasRenderingContext2D,
  comments: CommentThread[],
  appState: AppState
) => {
  comments.forEach(thread => {
    const { x, y } = sceneCoordsToViewportCoords(
      { sceneX: thread.x, sceneY: thread.y },
      appState
    );
    // Draw marker icon
    drawCommentMarker(context, x, y, thread.resolved);
  });
};
```

**Pros:**
- Perfect synchronization with canvas
- Better performance for many markers
- Consistent with other canvas elements

**Cons:**
- More complex click detection (hit testing)
- Harder to style
- Less accessible

### Recommended: Hybrid Approach

Use HTML overlay for markers (Approach 1) but:
- Subscribe to `appState` changes for position updates
- Use `requestAnimationFrame` for smooth updates during pan/zoom
- Keep markers simple (just icons) to minimize DOM updates

---

## Real-time Collaboration Considerations

If comments should sync in real-time during collaboration:

### Option A: Extend Room Service

Add comment events to the existing WebSocket protocol:

```typescript
// room-service/src/index.ts
socket.on('comment:create', (data) => {
  socket.to(roomId).emit('comment:created', data);
});

socket.on('comment:resolve', (data) => {
  socket.to(roomId).emit('comment:resolved', data);
});
```

### Option B: Polling

Simple polling approach for MVP:

```typescript
// Poll every 30 seconds when scene is active
const { data: comments } = useQuery({
  queryKey: ['comments', sceneId],
  queryFn: () => fetchComments(sceneId),
  refetchInterval: 30000,
});
```

### Option C: Server-Sent Events

Backend pushes comment updates:

```typescript
// Backend: SSE endpoint
@Sse('comments/stream/:sceneId')
streamComments(@Param('sceneId') sceneId: string) {
  return this.commentsService.getCommentStream(sceneId);
}
```

---

## Permission Model (To Be Defined)

Questions to answer:

1. **Who can create comments?**
   - All authenticated users?
   - Only workspace members?
   - Only users with EDIT permission on the scene?

2. **Who can resolve comments?**
   - Comment author only?
   - Any workspace member?
   - Only ADMIN/MEMBER roles?

3. **Who can delete comments?**
   - Comment author only?
   - Workspace admins?
   - Scene owner?

4. **Visibility of comments**
   - All comments visible to all viewers?
   - Comments visible only to workspace members?
   - Private comments (author + mentions only)?

---

## Next Steps

### Phase 1: Research (Current)
- [ ] Gather screenshots from Excalidraw Plus
- [ ] Analyze API structure using DevTools
- [ ] Document UI/UX patterns observed
- [ ] Define permission model

### Phase 2: Backend Implementation
- [ ] Create Prisma schema
- [ ] Implement CRUD endpoints
- [ ] Add permission checks
- [ ] Write tests

### Phase 3: Frontend - Core
- [ ] Create Comments components
- [ ] Implement React Query hooks
- [ ] Build sidebar panel
- [ ] Add comment markers layer

### Phase 4: Frontend - Canvas Integration
- [ ] Position markers on canvas
- [ ] Handle pan/zoom updates
- [ ] Click-to-create flow
- [ ] Element anchoring (optional)

### Phase 5: Real-time (Optional)
- [ ] Add WebSocket events to room-service
- [ ] Sync comments during collaboration

---

## Appendix: Research Findings from Excalidraw Plus

> **Research conducted:** December 2024
> **Source:** Excalidraw Plus (app.excalidraw.com) - paid subscription

### Key Architecture Discovery

**Excalidraw Plus uses Google Firestore** for comments storage with real-time listeners:

```
Endpoint: firestore.googleapis.com/google.firestore.v1.Firestore/Listen/channel
Database: projects/quickstart-1595168317408/databases/(default)
```

This means:
- No traditional REST API calls for comments
- Real-time sync via Firestore listeners
- Comments stored in Firebase, not their own backend

**For AstraDraw:** We'll use our existing backend (NestJS + PostgreSQL) with optional WebSocket sync via room-service.

---

### UI Components Identified

#### 1. Right Sidebar Panel
- Search box: "Search comments"
- Filter/sort button
- Comment list items showing: avatar, name, time, preview text with emoji
- Click on comment → navigates to position on canvas + opens popup

#### 2. Comment Marker on Canvas
- Circular badge with comment count number
- Author avatar attached
- Positioned at specific canvas coordinates (scene coords)
- Changes appearance when resolved (TBD)

#### 3. Comment Thread Popup
- Fixed width: 320px
- Absolute positioning based on marker location
- Header with action buttons
- Scrollable comment list (max-height: 230px)
- Reply input at bottom

#### 4. Comment Tool Button (Footer)
- Location: Bottom footer bar, next to presentation mode button
- Icon: Speech bubble (💬)
- Tooltip on hover: "Add comment — C"
- **Click behavior:** 
  - First click: Opens comments sidebar tab
  - Second click: Closes comments sidebar
- Does NOT directly enter "comment mode" - just toggles sidebar
- Hotkey `C` activates comment cursor mode for placing comments

---

### HTML Structure: Comment Popup

**Container:**
```html
<div class="left-3 z-20 overflow-hidden bg-surface-low-for-dropdown absolute -mt-2 h-auto w-[320px] rounded-lg shadow-lg" 
     style="top: 244.828px; left: 647.828px;">
```

**Key CSS classes:**
- `w-[320px]` - Fixed width 320px
- `rounded-lg` - Border radius
- `shadow-lg` - Drop shadow
- `bg-surface-low-for-dropdown` - Background color (theme-aware)
- `z-20` - Z-index for layering
- Absolute positioning with `top` and `left` in pixels

**Header Actions Bar:**
```html
<div class="border-b-surface-high flex w-full justify-between border-b px-3 py-2">
  <!-- Action buttons: Resolve, Link, Delete, Close -->
</div>
```

| Button | Icon | CSS on Hover | Purpose |
|--------|------|--------------|---------|
| Resolve | ✓ (checkmark in circle) | `hover:bg-primary hover:text-white` | Mark thread resolved |
| Copy Link | 🔗 (chain link) | `hover:bg-surface-high` | Copy link to comment |
| Delete | 🗑 (trash) | `hover:bg-surface-high` | Delete entire thread |
| Close | ✕ (X) | `hover:bg-surface-high` | Close popup |

**Comment Item Structure:**
```html
<div id="KVbNH82Vbijg" class="border-b-surface-high box-border flex w-full flex-col border-b py-2">
  <!-- Comment ID: KVbNH82Vbijg (their identifier format) -->
  
  <!-- Author row -->
  <div class="flex-center flex w-full flex-row gap-1">
    <img class="rounded-full" alt="Mr. Khachaturov" 
         src="https://avatars.githubusercontent.com/u/105451445?v=4" 
         style="width: 22px; height: 22px;">
    <span class="text-sm font-bold text-surface-text">Mr. Khachaturov</span>
    <span class="text-sm text-surface-text-variant">•</span>
    <span class="text-xs text-surface-text-variant">5 days ago</span>
    <!-- Three-dot menu (⋮) -->
  </div>
  
  <!-- Comment text -->
  <div class="whitespace-pre-line break-words pl-1 pt-2 text-sm text-surface-text">
    что то думаю😍
  </div>
  
  <!-- Emoji reaction button -->
  <div class="mt-2 grid grid-cols-8">
    <button class="flex h-6 w-6 items-center justify-center rounded-md p-0.5">
      <!-- Smiley icon -->
    </button>
  </div>
</div>
```

**Reply Input Structure:**
```html
<div class="space-y-2 p-3 rounded-lg">
  <div class="border-gray-20 bg-surface-low rounded border">
    <!-- Textarea with mentions support -->
    <textarea placeholder="Reply, @mention someone..." 
              class="mentions__input">
    </textarea>
    
    <!-- Bottom toolbar -->
    <div class="flex items-center justify-between p-1">
      <!-- Left: Emoji picker, @ mention button -->
      <div class="flex items-center gap-1">
        <button>😊</button>  <!-- Emoji picker -->
        <button>@</button>   <!-- Mention trigger -->
      </div>
      
      <!-- Right: Send button -->
      <button class="bg-primary h-6 w-6 disabled:bg-surface-low disabled:cursor-not-allowed">
        <!-- Arrow up icon -->
      </button>
    </div>
  </div>
</div>
```

**Key Observations:**
- Send button is disabled when input is empty
- @ mention button is disabled when no users to mention
- Uses `mentions` library for @mention functionality
- Emoji picker is a popover/dialog

---

### Thread Popup - Navigation & Important Behaviors

**Header Navigation (< > buttons):**
```
┌─────────────────────────────────────────────────┐
│ [<] [>]              [✓] [🔗] [🗑] [✕]         │
│  ↑   ↑                                          │
│  │   └── Next thread                            │
│  └────── Previous thread                        │
└─────────────────────────────────────────────────┘
```

- **< >** buttons navigate between threads on the canvas
- When switching threads, the reply input is **automatically focused** (ready to type)

**⚠️ IMPORTANT: Resolved Threads**
- Resolved threads **disappear from canvas** (marker hidden)
- They remain in sidebar (if "Show resolved" toggle is ON)
- Shows green checkmark + "This thread was resolved" message at bottom of popup

**⚠️ IMPORTANT: Scrollable Messages**
- Messages area is scrollable (`max-h-[230px]` with `overflow-auto`)
- Reply input area is **always static/visible** at bottom (never scrolls away)

**⚠️ IMPORTANT: Per-Comment Deep Links**
- Each comment (not just thread) has its own deep link
- Click three-dot menu (⋮) on any comment → "Copy link"
- Link format: `/workspace/{slug}/scene/{sceneId}?thread={threadId}&comment={commentId}`
- Deep link behavior:
  1. Opens the scene
  2. Opens comments sidebar tab
  3. Selects the thread in sidebar
  4. Opens thread popup on canvas
  5. **Scrolls to the specific comment** within the thread

**@Mention Display in Comments:**
```html
<button class="hover:bg-transparent">
  <span class="box-border inline-flex rounded-md px-1 py-px font-semibold 
               bg-yellow-50 text-yellow-800 
               dark:bg-yellow-900 dark:text-yellow-100">
    @Ruben Khachaturov
  </span>
</button>
```

- Mentions are clickable buttons with yellow background
- Light mode: `bg-yellow-50 text-yellow-800`
- Dark mode: `bg-yellow-900 text-yellow-100`
- Clicking mention could show user profile (TBD)

---

### CSS Theme Variables Used

```css
/* Backgrounds */
--bg-surface-low-for-dropdown
--bg-surface-high
--bg-surface-low
--bg-primary

/* Text colors */
--text-surface-text          /* Primary text */
--text-surface-text-variant  /* Secondary text (timestamps) */

/* Borders */
--border-b-surface-high
--border-gray-20

/* Interactive states */
hover:bg-primary             /* Resolve button */
hover:bg-surface-high        /* Other buttons */
hover:bg-brand-hover         /* Send button */
active:bg-brand-active
```

---

### Data Model Observations

**Comment ID format:** `KVbNH82Vbijg` (12 characters, alphanumeric)

**Author data includes:**
- Name: "Mr. Khachaturov"
- Avatar URL: GitHub avatar URL
- User ID: (not visible in HTML, but referenced)

**Timestamp:** Relative format ("5 days ago")

---

### HTML Structure: Comment Marker on Canvas

**Container:**
```html
<div id="BfAZmVSJZrwn" 
     class="comment-thread absolute z-3 flex touch-none select-none self-start hover:z-20" 
     style="top: 244.833px; left: 607.833px;">
  
  <div tabindex="-1" 
       class="comments-pin z-1 flex flex-row self-start rounded-bl-[0px] rounded-br-[67px] rounded-tl-[66px] rounded-tr-[67px] bg-surface-low-for-dropdown transition-all duration-200 hover:scale-[103%] hover:shadow-button-lg p-0.5 shadow-button-md">
    
    <div class="relative flex w-full flex-row" style="height: 24px;">
      <img class="pointer-events-none !select-none rounded-full object-contain hover:brightness-95 active:brightness-75 undefined border border-surface-lowest" 
           alt="Mr. Khachaturov" 
           referrerpolicy="no-referrer" 
           src="https://avatars.githubusercontent.com/u/105451445?v=4" 
           style="width: 24px; height: 24px;">
    </div>
  </div>
</div>
```

**Key observations:**
- Thread ID in element: `id="BfAZmVSJZrwn"`
- Absolute positioning with `top` and `left` in pixels (viewport coords)
- Avatar size: 24x24px
- Unique border-radius creates "pin" shape: `rounded-bl-[0px] rounded-br-[67px] rounded-tl-[66px] rounded-tr-[67px]`
- Hover effect: `hover:scale-[103%] hover:shadow-button-lg`
- Z-index management: `z-3` default, `hover:z-20` on hover
- `touch-none select-none` - prevents touch/selection interference

**Marker visual shape:**
```
    ┌──────┐
   /        \      ← rounded top (66-67px radius)
  │  avatar  │
  │    👤    │
   \        /
    └──┘         ← flat bottom-left corner (0px radius)
```

---

### HTML Structure: Hover Tooltip on Marker

When hovering on a marker, shows a tooltip with:
- Author name
- Timestamp ("5 days ago")
- Comment text preview
- Thread count ("1 comment")

```
┌─────────────────────────────────────┐
│ [👤] Mr. Khachaturov  5 days ago    │
│                                     │
│ что то думаю😍                      │
│                            1 comment │
└─────────────────────────────────────┘
```

---

### UX Flow: Creating a Comment

1. **Activate comment mode:**
   - Press **`C`** hotkey (keyboard shortcut)
   - OR click comment tool in toolbar (💬 speech bubble icon)

2. **Cursor changes:**
   - Arrow cursor becomes message/comment icon

3. **Click on canvas:**
   - Opens comment input at click position
   - Shows: avatar + textarea + emoji/mention buttons

4. **Type comment:**
   - Textarea auto-expands as you type
   - Can use `@` to mention someone (shows dropdown)
   - Can click emoji button (😊) to open emoji picker

5. **Submit comment:**
   - Click send button (↑ arrow)
   - OR press **Enter** key

---

### UX Flow: Comment Input Features

**Textarea behavior:**
- Placeholder: "Comment, @mention someone..."
- Auto-expands vertically as text grows
- Supports multi-line text
- Preserves line breaks

**Emoji Picker:**
- Opens as popover above input
- Has search field
- "Frequently used" section
- Categories: "Smileys & People", etc.
- Click emoji to insert at cursor

**@Mention:**
- Type `@` or click @ button
- Shows dropdown of workspace members
- Select user to insert mention

**Submit methods:**
- Enter key
- Click send button (↑)
- Send button disabled when empty

---

### UX Flow: Interacting with Comments

**Marker on canvas:**
- **Hover:** Shows tooltip with preview (author, text, count)
- **Click:** Opens full thread popup
- **Drag:** Can reposition marker (hold mouse button and move)

**Sidebar:**
- **Click item:** Navigates canvas to comment position + opens popup
- **Search:** Filter comments by text
- **Filter button:** (functionality TBD)

---

### HTML Structure: Comments Sidebar Panel

**Full sidebar container:**
```html
<div data-state="active" data-orientation="horizontal" role="tabpanel" 
     aria-labelledby="radix-«r4b»-trigger-comments" 
     id="radix-«r4b»-content-comments" tabindex="0" 
     class="!flex !min-h-0 !flex-1 !basis-0 !flex-col" 
     data-testid="comments">
```

**Search bar:**
```html
<div class="relative flex items-center px-3 pt-3">
  <svg class="absolute left-6 h-5 w-5 text-border-outline"><!-- Search icon --></svg>
  <input class="comments-search box-border w-full rounded-sm !border-0 !bg-surface-low !pl-10 !pr-9 text-sm outline-none placeholder:text-xs placeholder:tracking-wide placeholder:text-border-outline focus:!shadow-none dark:!bg-surface-high" 
         placeholder="Search comments" type="text" value="">
</div>
```

**Filter button (below search):**
```html
<div class="flex h-6 w-6 items-center justify-center hover:bg-surface-high">
  <!-- Filter/sliders icon -->
</div>
```

**Filter dropdown options:**
- Sort by date (↑↓ icon)
- Sort by unread (↑↓ icon)  
- Show resolved comments (toggle switch, default ON)

**Sidebar comment item:**
```html
<span data-state="closed">
  <div class="flex flex-col px-3 !text-color-text !no-underline hover:!bg-surface-low hover:!no-underline active:!text-inherit active:!no-underline break-word hover:bg-surface-high dark:hover:!bg-surface-high hover:cursor-pointer group gap-1">
    <div class="flex flex-col gap-1 border-b border-b-surface-high py-2">
      
      <!-- Row 1: Avatar + hover actions -->
      <div class="flex items-center justify-between">
        <div class="flex">
          <div class="relative flex w-full flex-row" style="height: 24px;">
            <img class="rounded-full border border-primary p-[1px]" 
                 alt="Mr. Khachaturov" 
                 src="https://avatars.githubusercontent.com/u/105451445?v=4" 
                 style="width: 24px; height: 24px;">
          </div>
        </div>
        
        <!-- Hover actions (hidden by default, shown on group-hover) -->
        <div class="gap-0.5 group-hover:flex hidden">
          <!-- Three-dot menu button -->
          <div class="flex h-6 w-6 items-center justify-center">⋮</div>
          <!-- Resolve button (checkmark) -->
          <svg class="h-6 w-6 cursor-pointer rounded p-1 hover:bg-primary hover:text-white">✓</svg>
        </div>
      </div>
      
      <!-- Row 2: Author name + timestamp -->
      <div class="flex items-center gap-x-1">
        <span class="block max-w-[60%] truncate text-sm font-semibold text-surface-text">Mr. Khachaturov</span>
        <span class="text-sm text-surface-text-variant">•</span>
        <span class="text-xs text-surface-text-variant">5 minutes ago</span>
      </div>
      
      <!-- Row 3: Comment preview text -->
      <div class="pointer-events-none whitespace-pre-line text-sm text-surface-text-variant">
        asdasda
      </div>
      
      <!-- Row 4: Reply count (if has replies) -->
      <div class="text-xs text-surface-text-variant">1 reply</div>
      
    </div>
  </div>
</span>
```

**Key sidebar behaviors:**
- `group-hover:flex hidden` - Action buttons appear only on hover
- `border border-primary` - Avatar has primary color border (unread indicator?)
- Long text is truncated with `whitespace-pre-line`
- Reply count shown at bottom if thread has replies

---

### Sidebar Item Three-Dot Menu

**Menu options:**
```
┌─────────────────┐
│ ⊙ Resolve       │  ← Mark thread as resolved (or "Reopen" if already resolved)
│ 📋 Copy link    │  ← Copy shareable link to comment
│ 🗑 Remove       │  ← Delete thread (red text, shows confirmation)
└─────────────────┘
```

**Delete confirmation dialog:**
```
┌──────────────────────────────────────────────────┐
│ Delete whole thread                              │
│                                                  │
│ Are you sure that you want to delete whole       │
│ thread and related comments?                     │
│                                                  │
│                    [Cancel]  [Confirm]           │
│                              (red button)        │
└──────────────────────────────────────────────────┘
```

---

### Deep Link URL Structure

**Excalidraw Plus format:** `https://app.excalidraw.com/s/{workspaceId}/{sceneId}`

**Example:** `https://app.excalidraw.com/s/AEloUCCjjMP/A0v76VjkrmW`

**Behavior when opening link:**
1. Opens the scene/canvas
2. Navigates viewport to comment position
3. Opens comments sidebar
4. Selects the linked comment in sidebar
5. Opens comment popup on canvas

---

### AstraDraw URL Structure for Comments

**Current AstraDraw URL patterns** (from `router.ts`):

| View | URL Pattern |
|------|-------------|
| Dashboard | `/workspace/{slug}/dashboard` |
| Collection | `/workspace/{slug}/collection/{collectionId}` |
| Private | `/workspace/{slug}/private` |
| **Scene** | `/workspace/{slug}/scene/{sceneId}` |
| Scene + Collab | `/workspace/{slug}/scene/{sceneId}#key={roomKey}` |

**Proposed Comment URL patterns:**

```
# Thread-level link (opens thread, shows first comment)
/workspace/{slug}/scene/{sceneId}?thread={threadId}

# Comment-level link (opens thread, scrolls to specific comment)
/workspace/{slug}/scene/{sceneId}?thread={threadId}&comment={commentId}
```

**Examples:**
```
# Scene without comment focus
https://draw.local/workspace/admin/scene/xyz789

# Scene with specific thread focused
https://draw.local/workspace/admin/scene/xyz789?thread=abc123

# Scene with specific comment in thread (deep link to reply)
https://draw.local/workspace/admin/scene/xyz789?thread=abc123&comment=def456

# Scene with collaboration + thread
https://draw.local/workspace/admin/scene/xyz789?thread=abc123#key=roomKey
```

**URL handling behavior:**
1. Parse `?thread={threadId}` query parameter
2. Load scene normally
3. If `threadId` present:
   - Open comments sidebar
   - Scroll to and highlight the thread in sidebar
   - Pan canvas to thread position
   - Open thread popup

**Router changes needed** (`router.ts`):
```typescript
// Add to RouteType
| { type: "scene"; workspaceSlug: string; sceneId: string; threadId?: string }

// Update parseUrl to extract threadId from query params
const params = new URLSearchParams(urlObj.search);
const threadId = params.get("thread") || undefined;

// Add URL builder
export function buildSceneUrlWithThread(
  workspaceSlug: string,
  sceneId: string,
  threadId: string,
  roomKey?: string,
): string {
  let url = `/workspace/${encodeURIComponent(workspaceSlug)}/scene/${encodeURIComponent(sceneId)}?thread=${encodeURIComponent(threadId)}`;
  if (roomKey) {
    url += `#key=${roomKey}`;
  }
  return url;
}
```

---

### Search Functionality

**Behavior:**
- Real-time filtering as you type
- Searches through all comment text
- **Highlights matches** with yellow background (`<mark>` or CSS)
- Includes resolved/closed threads in search
- Shows matching comments only

**CSS for highlighting:**
```css
/* Yellow highlight for search matches */
background-color: yellow; /* or var(--color-highlight) */
```

---

### Filter & Sort Options

| Option | Icon | Description |
|--------|------|-------------|
| Sort by date | ↑↓ | Newest first (default) |
| Sort by unread | ↑↓ | Unread comments first |
| Show resolved | Toggle | Include/exclude resolved threads |

---

### Resolved Thread Appearance

**⚠️ CRITICAL: Resolved markers DISAPPEAR from canvas**

**Canvas behavior:**
- Resolved thread markers are **completely hidden** from canvas
- No visual indicator (no grayed out marker, just gone)

**Popup behavior (when opened from sidebar):**
- Resolve button in header becomes **filled/active** (purple background)
- Shows message at bottom: "✓ This thread was resolved" (green checkmark)
- Reply input is still visible (can reopen by replying or clicking resolve again)

**Sidebar behavior:**
- Resolved threads become **gray/muted** color
- Hidden by default if "Show resolved comments" toggle is OFF
- "Resolve" option in menu changes to "Reopen"

**Reopen behavior:**
- Click resolve button again to reopen
- Or add a new reply to the thread
- Marker reappears on canvas

---

---

### @Mention System

**Trigger:** Type `@` in comment input or click @ button

**Dropdown behavior:**
- Shows message: "You can tag anyone with access to the **{collection name}** collection:"
- Lists users who have access to the scene's collection
- Click user to insert mention

**Mention display in input:**
```
┌──────────────────────────────────────────────────┐
│ [Ruben Khachaturov] askdasjdlkajald          [●] │
│  ↑ highlighted with background color             │
└──────────────────────────────────────────────────┘
```

**Key points:**
- Mentioned username has background color (not just plain text)
- Mentions are stored as user IDs, displayed as names
- Only users with collection access can be mentioned
- @mentions trigger notifications to mentioned users

---

## Notification System

> **See separate document:** [Notification System Research](NOTIFICATION_SYSTEM_RESEARCH.md)

**Summary:**
- Bell icon in sidebar footer with unread count badge
- Quick popup view with recent notifications
- Full notifications page at `/workspace/{slug}/notifications`
- Two notification types: COMMENT and MENTION
- Notifications are kept forever (infinite scroll timeline)
- Mark as read: individual or all at once

---

### Research Complete ✅

All major features have been documented:
- [x] Comment popup structure and behavior
- [x] Thread marker on canvas
- [x] Sidebar panel with search/filter
- [x] Thread navigation (< > buttons)
- [x] Resolved thread behavior (disappears from canvas)
- [x] Per-comment deep links
- [x] @mention system
- [x] Notification system (separate doc)

---

---

### HTML Structure: Comment Toolbar Button

**Location:** Footer bar (bottom of screen)

```html
<div class="w-fit" data-state="closed">
  <button type="button" 
          class="excalidraw-button !border-0 shadow-[0_0_0_1px_var(--box-shadow-normal)] active:shadow-[--box-shadow-active]" 
          style="--button-bg: var(--color-surface-low); 
                 --button-width: var(--lg-button-size); 
                 --button-height: var(--lg-button-size); 
                 --box-shadow-normal: var(--color-surface-lowest); 
                 --box-shadow-active: var(--color-brand-active);">
    <svg aria-hidden="true" focusable="false" role="img" 
         class="!flex-auto Icon" viewBox="0 0 24 24" 
         fill="none" stroke-width="2" stroke="currentColor" stroke-linecap="round">
      <g stroke-width="1.5" stroke="currentColor" fill="none" stroke-linecap="round" stroke-linejoin="round">
        <path d="M3 20l1.3 -3.9c-2.324 -3.437 -1.426 -7.872 2.1 -10.374c3.526 -2.501 8.59 -2.296 11.845 .48c3.255 2.777 3.695 7.266 1.029 10.501c-2.666 3.235 -7.615 4.215 -11.574 2.293l-4.7 1"></path>
      </g>
    </svg>
  </button>
</div>
```

**Key observations:**
- Uses `excalidraw-button` class (existing Excalidraw component)
- Size: `--lg-button-size` (large button)
- Uses CSS custom properties for theming
- `data-state="closed"` tracks sidebar state
- SVG icon: speech bubble with tail

**Button behavior:**
- Hover: Shows tooltip "Add comment — C"
- Click: Toggles comments sidebar panel open/closed
- Hotkey `C`: Activates comment cursor mode (different from button click!)

---

---

### Screenshots Reference

**Comment System:**
1. Main comment interface - Shows sidebar, marker, and popup
2. Comment marker on canvas - Pin shape with avatar
3. Marker hover tooltip - Shows preview info
4. Comment creation input - Empty state with placeholder
5. Comment input expanded - With long text, shows auto-expand
6. Emoji picker - Search + categories + emoji grid
7. Comment toolbar button - Footer button with tooltip
8. Comments sidebar panel - Full list with search
9. Sidebar filter dropdown - Sort by date/unread, show resolved toggle
10. Sidebar item hover - Shows action buttons (⋮ and ✓)
11. Three-dot menu - Resolve, Copy link, Remove options
12. Delete confirmation dialog - "Delete whole thread" modal
13. Search with highlighting - Yellow highlight on matches
14. Full page view - Canvas + sidebar + popup together
15. @mention dropdown - User selection with collection context
16. @mention in input - Highlighted username with background

**Technical:**
17. IndexedDB storage - Shows React Query cache structure
18. Firebase storage - Shows Firestore authentication

*(Screenshots stored locally, referenced in chat history)*

**Notification screenshots:** See [Notification System Research](NOTIFICATION_SYSTEM_RESEARCH.md)

