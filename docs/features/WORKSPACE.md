# AstraDraw Workspace Feature

The Workspace feature allows users to save, organize, and access their drawings from any device using OIDC authentication (e.g., Authentik) or local email/password authentication.

## Features

- **User Authentication**: Sign in with SSO (OIDC) or local email/password
- **Multi-Workspace Support**: Create and switch between multiple workspaces
- **Dashboard View**: Central hub showing recently modified and visited scenes
- **Collection Views**: Browse scenes organized by collection in the main content area
- **Scene Management**: Save, open, rename, duplicate, and delete scenes
- **Collections**: Organize scenes into folders with team-based access control
  - Emoji picker for collection icons (category tabs, search, frequently used)
  - Edit collection name and icon from context menu
- **Teams & Roles**: Collaborate with team members using ADMIN/MEMBER/VIEWER roles
- **Navigation Sidebar**: Quick access to dashboard, settings, and collections
- **Auto-save**: Scene data is automatically saved with change detection
- **Localization**: Full Russian translation support including time formats

> **See also:** [Roles, Teams & Collections](../guides/ROLES_TEAMS_COLLECTIONS.md) for detailed access control documentation.

## User Interface Modes

AstraDraw has two main UI modes:

### 1. Canvas Mode (Drawing)
When you open a scene or create a new one, you're in canvas mode:
- Full drawing canvas with Excalidraw tools
- Minimal sidebar navigation (BoardModeNav) showing scenes from active collection
- "Dashboard" link to return to dashboard
- Scene list with the current scene highlighted

### 2. Dashboard Mode
The central hub for managing your scenes and settings. The dashboard has multiple views accessible from the sidebar:

**Dashboard Home** (`dashboardView: "home"`):
- **Recently Modified by You**: Grid of scenes you've recently edited
- **Recently Visited by You**: Grid of scenes you've recently viewed
- **Team Members**: Shows active collaborators (placeholder)

**Collection View** (`dashboardView: "collection"`):
- Collection header with icon and name
- Sort options (Last created / Last modified)
- Import scenes and Create scene buttons
- Scene grid showing all scenes in that collection
- Empty state with call-to-action when no scenes exist

**Settings Views** (integrated into dashboard):
- **Profile** (`dashboardView: "profile"`): User profile, avatar, display name
- **Workspace Settings** (`dashboardView: "workspace"`): Workspace name, icon, danger zone
- **Team Members** (`dashboardView: "members"`): Invite members, manage roles
- **Teams & Collections** (`dashboardView: "teams-collections"`): Manage teams and collections

All views share the full navigation sidebar (FullModeNav) with:
- Workspace selector
- Quick search
- Dashboard, Profile, Workspace settings, Team members, Teams & Collections links
- Collections list with context menu (Create Scene, Edit, Delete)
- User profile footer

## Navigation Flow

### Creating a New Scene from Collection Context Menu

When a user creates a new scene from a collection's context menu:

1. **Scene Creation**: Backend creates the scene in the specified collection
   - For **shared workspace non-private collections**: Backend auto-generates `roomId` and `roomKey` for collaboration
2. **Canvas Preparation**: Canvas is reset for the new scene
3. **State Updates**:
   - `currentSceneId` and `currentSceneTitle` are set
   - `activeCollectionId` is set to the collection where scene was created
4. **Collaboration Initialization** (for shared workspaces):
   - If workspace type is `SHARED` and scene has `roomId`:
     - Call `startCollaboration(sceneId)` API to get `roomKey`
     - Call `collabAPI.startCollaboration({ roomId, roomKey, isAutoCollab: true })`
     - Set `isAutoCollabScene` to `true`
   - This ensures the scene is immediately ready for real-time collaboration
5. **Sidebar Behavior**: Sidebar stays open and switches to "board" mode
6. **Mode Switch**: App switches from dashboard to canvas mode
7. **Result**: User sees the canvas with sidebar showing the collection's scenes, new scene highlighted

This ensures continuity - the user can immediately start drawing while seeing their new scene in the collection's scene list.

> **See also:** [Auto-Collaboration](AUTO_COLLABORATION.md) for full details on automatic collaboration for shared collections.

### Opening an Existing Scene

When a user clicks on a scene card:

1. **Data Loading**: Scene data is fetched from backend via `loadWorkspaceScene()`
   - Response includes `access`, `roomId`, and `roomKey` (if user has `canCollaborate` permission)
2. **Canvas Update**: Canvas is populated with scene elements and app state
3. **State Updates**: `currentSceneId` and `currentSceneTitle` are set
4. **Collaboration Auto-Join** (for shared workspaces):
   - If `access.canCollaborate && roomId && roomKey`:
     - Call `collabAPI.startCollaboration({ roomId, roomKey, isAutoCollab: true })`
     - Data is loaded from **room storage** (source of truth for collaboration)
     - Set `isAutoCollabScene` to `true`
   - If not eligible for collaboration:
     - Data is loaded from **workspace storage** (backend API)
     - Set `isAutoCollabScene` to `false`
5. **Mode Switch**: App switches to canvas mode
6. **Sidebar**: Switches to "board" mode showing scenes from the active collection

> **Important:** For collaboration scenes, room storage (`/rooms/{roomId}`) is the source of truth, not workspace storage (`/scenes/{storageKey}`). See [Auto-Collaboration](AUTO_COLLABORATION.md) for storage architecture details.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (Vite)                          │
│  ┌──────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ AuthProvider │  │ WorkspaceSidebar │  │ ExcalidrawWrapper│  │
│  └──────────────┘  │  ├─ BoardModeNav │  └──────────────────┘  │
│                    │  └─ FullModeNav  │                         │
│                    └──────────────────┘                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              WorkspaceMainContent (Router)                │  │
│  │  ┌─────────────────┐  ┌──────────────────────────────┐   │  │
│  │  │  DashboardView  │  │      CollectionView          │   │  │
│  │  │  - Recently     │  │  - Collection header         │   │  │
│  │  │    modified     │  │  - Sort options              │   │  │
│  │  │  - Recently     │  │  - Scene grid                │   │  │
│  │  │    visited      │  │  - Empty state               │   │  │
│  │  └─────────────────┘  └──────────────────────────────┘   │  │
│  │  ┌─────────────────┐  ┌──────────────────────────────┐   │  │
│  │  │   ProfilePage   │  │   WorkspaceSettingsPage      │   │  │
│  │  │   MembersPage   │  │   TeamsCollectionsPage       │   │  │
│  │  └─────────────────┘  └──────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    SceneCardGrid                          │   │
│  │              (Reusable scene display)                     │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Storage Backend (NestJS)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐ │
│  │ AuthController│  │WorkspaceCtrl │  │   Storage Service     │ │
│  │  (OIDC/JWT)  │  │ (Scenes API) │  │   (S3/MinIO)          │ │
│  └──────────────┘  └──────────────┘  └───────────────────────┘ │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐ │
│  │WorkspacesCtrl│  │ TeamsCtrl    │  │  CollectionsCtrl      │ │
│  │(Members/Roles)│  │(Team CRUD)  │  │  (Collection CRUD)    │ │
│  └──────────────┘  └──────────────┘  └───────────────────────┘ │
│                              │                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                     Prisma ORM                            │   │
│  │   Users, Workspaces, Members, Teams, Collections, Scenes  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┴───────────────────┐
          ▼                                       ▼
┌─────────────────────┐               ┌─────────────────────┐
│    PostgreSQL       │               │    MinIO/S3         │
│  (User metadata,    │               │  (Scene data,       │
│   Scene metadata,   │               │   Files)            │
│   Workspaces/Teams) │               └─────────────────────┘
└─────────────────────┘
```

## Setup

### 1. Configure Authentik (or other OIDC provider)

1. Create a new OAuth2/OIDC Provider in Authentik
2. Set the Redirect URI to: `https://your-domain.com/api/v2/auth/callback`
3. Note the Client ID and Client Secret

### 2. Update Environment Variables

Add to your `.env` file:

```bash
# OIDC Configuration (Authentik)
OIDC_ISSUER_URL=https://auth.yourdomain.com/application/o/astradraw/
OIDC_CLIENT_ID=your-client-id
OIDC_CLIENT_SECRET=your-client-secret

# JWT Secret (generate with: openssl rand -base64 32)
JWT_SECRET=your-secure-jwt-secret

# PostgreSQL is already configured for workspace metadata
# Uses existing POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
```

### 3. Restart Services

```bash
cd deploy
docker compose down
docker compose up -d --build
```

The storage backend will automatically run Prisma migrations on startup.

## Default Workspace Behavior

When a new user registers (via OIDC or local auth):

1. **Personal Workspace** is automatically created:
   - Name: `"{Username}'s Workspace"` (e.g., "John's Workspace")
   - User is added as **ADMIN**
   - Slug derived from email (e.g., `john-doe`)

2. **Private Collection** is created in the workspace:
   - Name: "Private" with 🔒 icon
   - `isPrivate: true` - only the owner can see it
   - All new scenes go here by default

3. **Scene Saving Logic**:
   - When user creates a scene without selecting a collection → **Private collection**
   - When user selects a specific collection → That collection
   - Dashboard view shows all scenes from all accessible collections

Later, the user can:
- Create additional workspaces (for work, projects, etc.)
- Be invited to other users' workspaces
- Create shared collections within workspaces

## Usage

1. **Sign In**: Click the hamburger menu → "Sign in" → Authenticate with your OIDC provider
2. **Open Workspace**: Click the hamburger menu → "Workspace" to open the left sidebar
3. **Save Scene**: Click "Save to Workspace" in the menu or use the sidebar's "New Scene" button
4. **Open Scene**: Click any scene in the workspace sidebar to load it
5. **Sign Out**: Click your user menu in the sidebar → "Sign out"

## API Endpoints

### Authentication
- `GET /api/v2/auth/status` - Check if OIDC is configured
- `GET /api/v2/auth/login?redirect=/path` - Start OIDC login flow
- `GET /api/v2/auth/callback` - OIDC callback (internal)
- `GET /api/v2/auth/me` - Get current user info
- `GET /api/v2/auth/logout` - Sign out

### Workspace Scenes
- `GET /api/v2/workspace/scenes` - List user's scenes
- `GET /api/v2/workspace/scenes/:id` - Get scene metadata
- `GET /api/v2/workspace/scenes/:id/data` - Get scene data (binary)
- `POST /api/v2/workspace/scenes` - Create new scene
- `PUT /api/v2/workspace/scenes/:id` - Update scene metadata
- `PUT /api/v2/workspace/scenes/:id/data` - Update scene data
- `DELETE /api/v2/workspace/scenes/:id` - Delete scene

## Database Schema

```prisma
model User {
  id           String   @id
  email        String   @unique
  name         String?
  avatarUrl    String?
  oidcId       String?  @unique  // For SSO users
  passwordHash String?           // For local auth users
  
  scenes              Scene[]
  workspaceMembers    WorkspaceMember[]
  teamMembers         TeamMember[]
  ownedCollections    Collection[]
}

model Workspace {
  id          String   @id
  name        String
  slug        String   @unique
  avatarUrl   String?
  
  members     WorkspaceMember[]
  teams       Team[]
  collections Collection[]
  inviteLinks InviteLink[]
}

model WorkspaceMember {
  id          String        @id
  role        WorkspaceRole @default(MEMBER)  // ADMIN, MEMBER, VIEWER
  workspaceId String
  userId      String
  
  @@unique([workspaceId, userId])
}

model Collection {
  id          String   @id
  name        String
  icon        String?
  isPrivate   Boolean  @default(false)
  userId      String   // Owner
  workspaceId String
  
  scenes      Scene[]
}

model Scene {
  id           String   @id
  title        String
  thumbnailUrl String?
  storageKey   String   @unique  // S3 key
  roomId       String?           // Collaboration room
  userId       String
  collectionId String?
  isPublic     Boolean
  createdAt    DateTime
  updatedAt    DateTime
}
```

> **See also:** [Roles, Teams & Collections](../guides/ROLES_TEAMS_COLLECTIONS.md) for the complete schema including Teams and InviteLinks.

## Security

- **JWT Tokens**: Session tokens are stored as HTTP-only cookies (not accessible via JavaScript)
- **PKCE**: Authorization flow uses PKCE for enhanced security
- **Ownership**: Users can only access their own scenes unless marked public
- **API Keys**: OIDC secrets are server-side only

## Troubleshooting

### "Authentication not configured" message
- Verify OIDC_ISSUER_URL, OIDC_CLIENT_ID, and OIDC_CLIENT_SECRET are set in `deploy/.env`
- Check API logs: `cd deploy && docker compose logs api`

### Login redirects fail
- Verify OIDC_CALLBACK_URL matches your Authentik redirect URI
- Ensure APP_PROTOCOL and APP_DOMAIN are correct in `deploy/.env`

### Database connection errors
- Check PostgreSQL is running: `cd deploy && docker compose ps`
- Verify DATABASE_URL format: `postgresql://user:password@host:5432/db`

### Migration errors
- Run migrations manually: `cd deploy && docker compose exec api npx prisma migrate deploy`
