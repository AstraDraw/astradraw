# Roles, Teams & Collections

This document explains the workspace-level access control system in AstraDraw, including roles, teams, collections, and how they work together to provide granular permissions.

## Overview

AstraDraw implements a multi-tenant workspace model where:
- **Workspaces** are isolated environments for teams or organizations
- **Roles** define what actions users can perform within a workspace
- **Teams** are named groups of users that share access to collections
- **Collections** are folders that organize scenes with configurable visibility

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Frontend (React)                               │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────────────┐ │
│  │ WorkspaceSidebar │  │  SettingsLayout  │  │   TeamsCollections    │ │
│  │ - Workspace list │  │ - Profile page   │  │   - Team CRUD         │ │
│  │ - Collections    │  │ - Members page   │  │   - Collection CRUD   │ │
│  │ - Scene list     │  │ - Teams page     │  │   - Access management │ │
│  └────────┬─────────┘  └────────┬─────────┘  └───────────┬───────────┘ │
│           │                     │                        │              │
│           └─────────────────────┴────────────────────────┘              │
│                                 │                                        │
│                    ┌────────────┴────────────┐                          │
│                    │      workspaceApi       │                          │
│                    │ - Workspaces, Members   │                          │
│                    │ - Teams, Collections    │                          │
│                    └────────────┬────────────┘                          │
└─────────────────────────────────│────────────────────────────────────────┘
                                  │ HTTP (JWT Cookie)
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        Backend (NestJS)                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────────────┐ │
│  │WorkspacesController│  │ TeamsController │  │CollectionsController │ │
│  │ /api/v2/workspaces│  │ /api/v2/teams   │  │ /api/v2/collections  │ │
│  └────────┬─────────┘  └────────┬─────────┘  └───────────┬───────────┘ │
│           │                     │                        │              │
│           └─────────────────────┴────────────────────────┘              │
│                                 │                                        │
│  ┌──────────────────────────────┴──────────────────────────────────┐   │
│  │                    WorkspaceRoleGuard                            │   │
│  │         (Enforces ADMIN/MEMBER/VIEWER permissions)               │   │
│  └──────────────────────────────┬──────────────────────────────────┘   │
│                                 │                                        │
│  ┌──────────────────────────────┴──────────────────────────────────┐   │
│  │                       Prisma ORM                                 │   │
│  │    Workspace → Members → Users                                   │   │
│  │    Workspace → Teams → TeamMembers → Users                       │   │
│  │    Workspace → Collections → Scenes                              │   │
│  │    Teams ←→ Collections (many-to-many via TeamCollection)        │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         PostgreSQL Database                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │  Workspace  │  │    Team     │  │ Collection  │  │    Scene    │   │
│  │  - name     │  │  - name     │  │  - name     │  │  - title    │   │
│  │  - slug     │  │  - color    │  │  - icon     │  │  - data     │   │
│  │  - members  │  │  - members  │  │  - isPrivate│  │  - roomId   │   │
│  └─────────────┘  │  - collections│ │  - userId   │  └─────────────┘   │
│                   └─────────────┘  └─────────────┘                      │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Model

### Workspace

The top-level container for all resources:

```prisma
model Workspace {
  id          String   @id @default(cuid())
  name        String
  slug        String   @unique  // URL-friendly identifier
  avatarUrl   String?
  
  members     WorkspaceMember[]
  teams       Team[]
  collections Collection[]
  inviteLinks InviteLink[]
  
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}
```

### WorkspaceMember

Links users to workspaces with a role:

```prisma
model WorkspaceMember {
  id          String        @id @default(cuid())
  role        WorkspaceRole @default(MEMBER)
  
  workspaceId String
  workspace   Workspace     @relation(...)
  userId      String
  user        User          @relation(...)
  
  createdAt   DateTime      @default(now())
  
  @@unique([workspaceId, userId])
}

enum WorkspaceRole {
  ADMIN   // Full control over workspace
  MEMBER  // Can create/edit scenes, limited admin access
  VIEWER  // Read-only access to allowed collections
}
```

### Team

A named group of users with shared collection access:

```prisma
model Team {
  id          String   @id @default(cuid())
  name        String
  color       String?  // Hex color for UI display
  
  workspaceId String
  workspace   Workspace @relation(...)
  
  members     TeamMember[]
  collections TeamCollection[]
  
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}

model TeamMember {
  id       String @id @default(cuid())
  teamId   String
  team     Team   @relation(...)
  userId   String
  user     User   @relation(...)
  
  @@unique([teamId, userId])
}

model TeamCollection {
  id           String     @id @default(cuid())
  teamId       String
  team         Team       @relation(...)
  collectionId String
  collection   Collection @relation(...)
  
  @@unique([teamId, collectionId])
}
```

### Collection

A folder for organizing scenes:

```prisma
model Collection {
  id          String   @id @default(cuid())
  name        String
  icon        String?  // Emoji or icon identifier
  color       String?
  
  isPrivate   Boolean  @default(false)  // Only owner can see
  userId      String   // Owner (for private collections)
  
  workspaceId String
  workspace   Workspace @relation(...)
  
  scenes      Scene[]
  teamCollections TeamCollection[]
  
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}
```

### InviteLink

Shareable links for joining a workspace:

```prisma
model InviteLink {
  id          String        @id @default(cuid())
  code        String        @unique  // Random code for URL
  role        WorkspaceRole @default(MEMBER)
  
  expiresAt   DateTime?     // Optional expiration
  maxUses     Int?          // Optional usage limit
  uses        Int           @default(0)
  
  workspaceId String
  workspace   Workspace     @relation(...)
  
  createdAt   DateTime      @default(now())
}
```

## Roles & Permissions

### ADMIN

Full control over the workspace:

| Action | Allowed |
|--------|---------|
| View all collections | ✅ |
| Create/edit/delete any scene | ✅ |
| Manage workspace settings | ✅ |
| Invite/remove members | ✅ |
| Change member roles | ✅ |
| Create/edit/delete teams | ✅ |
| Create/edit/delete collections | ✅ |
| Manage team-collection access | ✅ |
| Create/delete invite links | ✅ |
| Delete workspace | ✅ |

### MEMBER

Standard workspace participant:

| Action | Allowed |
|--------|---------|
| View accessible collections | ✅ |
| Create scenes in accessible collections | ✅ |
| Edit own scenes | ✅ |
| Edit team scenes (if team member) | ✅ |
| View own private collection | ✅ |
| Manage workspace settings | ❌ |
| Manage members | ❌ |
| Manage teams | ❌ |

### VIEWER

Read-only access:

| Action | Allowed |
|--------|---------|
| View accessible collections | ✅ |
| View scenes (read-only) | ✅ |
| Create/edit scenes | ❌ |
| Any management actions | ❌ |

## Collection Visibility Rules

A user can **see** a collection if:

1. **User is ADMIN** - sees all collections
2. **Collection is private AND user is owner** - only the creator sees it
3. **Collection is NOT private AND user is member of a team** that has access to the collection

A user can **create/edit scenes** in a collection if:

1. **User is ADMIN** - can edit anywhere
2. **User is owner** of the collection (private collections)
3. **User is MEMBER** of a team with access to the collection (and user role is MEMBER, not VIEWER)

## API Endpoints

### Workspaces

| Method | Endpoint | Description | Role Required |
|--------|----------|-------------|---------------|
| GET | `/api/v2/workspaces` | List user's workspaces | Any |
| GET | `/api/v2/workspaces/:id` | Get workspace details | Member |
| POST | `/api/v2/workspaces` | Create workspace | Any |
| PUT | `/api/v2/workspaces/:id` | Update workspace | ADMIN |
| DELETE | `/api/v2/workspaces/:id` | Delete workspace | ADMIN |

### Members

| Method | Endpoint | Description | Role Required |
|--------|----------|-------------|---------------|
| GET | `/api/v2/workspaces/:id/members` | List members | Member |
| POST | `/api/v2/workspaces/:id/members/invite` | Invite by email | ADMIN |
| PUT | `/api/v2/workspaces/:id/members/:memberId` | Update role | ADMIN |
| DELETE | `/api/v2/workspaces/:id/members/:memberId` | Remove member | ADMIN (or self) |

### Invite Links

| Method | Endpoint | Description | Role Required |
|--------|----------|-------------|---------------|
| GET | `/api/v2/workspaces/:id/invite-links` | List invite links | ADMIN |
| POST | `/api/v2/workspaces/:id/invite-links` | Create invite link | ADMIN |
| DELETE | `/api/v2/workspaces/:id/invite-links/:linkId` | Delete invite link | ADMIN |
| POST | `/api/v2/workspaces/join` | Join via invite code | Any |

### Teams

| Method | Endpoint | Description | Role Required |
|--------|----------|-------------|---------------|
| GET | `/api/v2/workspaces/:id/teams` | List teams | Member |
| POST | `/api/v2/workspaces/:id/teams` | Create team | ADMIN |
| GET | `/api/v2/teams/:id` | Get team details | Member |
| PUT | `/api/v2/teams/:id` | Update team | ADMIN |
| DELETE | `/api/v2/teams/:id` | Delete team | ADMIN |

### Collections

| Method | Endpoint | Description | Role Required |
|--------|----------|-------------|---------------|
| GET | `/api/v2/workspaces/:id/collections` | List accessible collections | Member |
| POST | `/api/v2/workspaces/:id/collections` | Create collection | ADMIN |
| GET | `/api/v2/collections/:id` | Get collection details | Access required |
| PUT | `/api/v2/collections/:id` | Update collection | ADMIN |
| DELETE | `/api/v2/collections/:id` | Delete collection | ADMIN |

## Frontend Components

### Settings Pages

The settings are accessed via full-page views (not modals):

| Page | Location | Description |
|------|----------|-------------|
| Profile | `components/Settings/ProfilePage.tsx` | User profile management |
| Workspace | `components/Settings/WorkspaceSettingsPage.tsx` | Workspace name, icon, danger zone |
| Members | `components/Settings/MembersPage.tsx` | Member list, invites, role management |
| Teams & Collections | `components/Settings/TeamsCollectionsPage.tsx` | Team and collection CRUD |

### State Management

```typescript
// settingsState.ts
import { atom } from "jotai";

export type AppMode = "canvas" | "settings";
export type SettingsPage = "profile" | "workspace" | "members" | "teams-collections";

export const appModeAtom = atom<AppMode>("canvas");
export const settingsPageAtom = atom<SettingsPage>("profile");
```

### Navigation Flow

1. **Canvas Mode** (default): Normal drawing experience
2. **Settings Mode**: Full-page settings with sidebar navigation

```
Click user avatar → Opens Settings (Profile page)
Click "Settings" in sidebar → Opens Settings (Workspace page)
Click "Team members" in sidebar → Opens Settings (Members page)
Click "Back to Board" → Returns to Canvas mode
```

### WorkspaceSidebar

Location: `frontend/excalidraw-app/components/Workspace/WorkspaceSidebar.tsx`

Displays:
- Workspace selector dropdown (top)
- Navigation items (Dashboard, Settings, Members - admin only)
- Collections list with expand/collapse
- Scenes within selected collection
- User profile at bottom

## Default Workspace Setup

When a new user registers or logs in for the first time:

1. A default workspace is created with:
   - Name: "My Workspace"
   - Slug: derived from email (e.g., `john-doe`)
   - User added as ADMIN

2. A default private collection is created:
   - Name: "Private"
   - Icon: 🔒
   - `isPrivate: true`
   - Owner: the new user

This ensures every user has a working workspace immediately after signup.

## Invite Flow

### Creating an Invite Link (Admin)

1. Go to Settings → Members
2. Click "Create Invite Link"
3. Configure:
   - Role (ADMIN, MEMBER, VIEWER)
   - Expiration (optional)
   - Max uses (optional)
4. Copy and share the link

### Joining via Invite Link

1. User receives link: `https://app.example.com/join?code=abc123xyz`
2. If not logged in, redirected to login first
3. After login, `POST /api/v2/workspaces/join` with the code
4. User is added to the workspace with the configured role
5. Link usage counter is incremented

## Security Considerations

### Role Enforcement

- All workspace operations check user's role via `WorkspaceRoleGuard`
- Role hierarchy: ADMIN > MEMBER > VIEWER
- Actions requiring higher role are rejected with 403 Forbidden

### Collection Access

- Private collections only visible to owner (even admins can't see others' private collections)
- Team-based access is checked for non-private collections
- Scene operations verify collection access

### Invite Links

- Codes are random 10-character alphanumeric strings
- Expired links are rejected
- Used-up links (max uses reached) are rejected
- Links can be deleted by admins at any time

## Localization

Translation keys are in `packages/excalidraw/locales/`:

**English (`en.json`):**
```json
{
  "settings": {
    "title": "Settings",
    "profile": "Profile",
    "workspace": "Workspace",
    "members": "Members",
    "teamsCollections": "Teams & Collections",
    "backToBoard": "Back to Board",
    "inviteMember": "Invite Member",
    "createTeam": "Create Team",
    "createCollection": "Create Collection",
    "teams": "Teams",
    "collections": "Collections"
  }
}
```

## Testing Checklist

### Workspace Management

- [ ] New user gets default workspace on first login
- [ ] Workspace selector shows all user's workspaces
- [ ] Can create new workspace
- [ ] Can update workspace name (admin only)
- [ ] Can delete workspace (admin only)

### Members

- [ ] Member list shows all workspace members
- [ ] Can invite user by email (admin only)
- [ ] Can create invite link (admin only)
- [ ] Can join via invite link
- [ ] Can change member role (admin only)
- [ ] Can remove member (admin only, or self-leave)
- [ ] Cannot demote last admin

### Teams

- [ ] Team list shows all teams (visible to all members)
- [ ] Can create team (admin only)
- [ ] Can add/remove team members (admin only)
- [ ] Can assign collections to team (admin only)
- [ ] Can delete team (admin only)

### Collections

- [ ] Collection list shows accessible collections
- [ ] Private collection only visible to owner
- [ ] Can create collection (admin only)
- [ ] Can edit collection (admin only)
- [ ] Can delete collection (admin only)
- [ ] Team members can see team's collections

### Access Control

- [ ] ADMIN can see all collections
- [ ] MEMBER can only see accessible collections
- [ ] VIEWER cannot create/edit scenes
- [ ] Non-members cannot access workspace

## Related Files

### Backend (`backend/`)

```
src/workspaces/
├── workspaces.controller.ts  # Workspace & member endpoints
├── workspaces.service.ts     # Workspace business logic
├── workspaces.module.ts      # Module definition
└── workspace-role.guard.ts   # Role-based access guard

src/teams/
├── teams.controller.ts       # Team endpoints
├── teams.service.ts          # Team business logic
└── teams.module.ts           # Module definition

src/collections/
├── collections.controller.ts # Collection endpoints
├── collections.service.ts    # Collection business logic
└── collections.module.ts     # Module definition

prisma/
└── schema.prisma             # Database schema
```

### Frontend (`frontend/`)

```
excalidraw-app/
├── auth/
│   └── workspaceApi.ts       # API client functions
├── components/
│   ├── Settings/
│   │   ├── settingsState.ts           # Jotai atoms
│   │   ├── SettingsLayout.tsx         # Full-page layout
│   │   ├── ProfilePage.tsx            # Profile settings
│   │   ├── WorkspaceSettingsPage.tsx  # Workspace settings
│   │   ├── MembersPage.tsx            # Member management
│   │   └── TeamsCollectionsPage.tsx   # Teams & collections
│   └── Workspace/
│       └── WorkspaceSidebar.tsx       # Main sidebar
packages/excalidraw/locales/
├── en.json                   # English translations
└── ru-RU.json                # Russian translations
```

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-21 | Initial implementation of roles, teams & collections |
| 2025-12-21 | Added default workspace creation on user signup |
| 2025-12-21 | Implemented full-page settings views |
| 2025-12-21 | Fixed sidebar layout to match reference design (compact workspace header, small nav items, collections section with "+" button, user footer) |
| 2025-12-21 | Fixed scene creation to use private collection by default when no collection is selected |
| 2025-12-21 | Personal workspace now named "{Username}'s Workspace" on registration |
| 2025-12-21 | Added workspace change tracking to ensure scenes are saved to correct workspace's private collection |

