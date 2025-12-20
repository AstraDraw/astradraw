# AstraDraw Workspace Feature

The Workspace feature allows users to save, organize, and access their drawings from any device using OIDC authentication (e.g., Authentik) or local email/password authentication.

## Features

- **User Authentication**: Sign in with SSO (OIDC) or local email/password
- **Multi-Workspace Support**: Create and switch between multiple workspaces
- **Scene Management**: Save, open, and delete scenes organized in collections
- **Collections**: Organize scenes into folders with team-based access control
- **Teams & Roles**: Collaborate with team members using ADMIN/MEMBER/VIEWER roles
- **Left Sidebar**: Quick access to collections and scenes
- **Auto-save**: Scene data is automatically saved with change detection

> **See also:** [Roles, Teams & Collections](./ROLES_TEAMS_COLLECTIONS.md) for detailed access control documentation.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (Vite)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐ │
│  │ AuthProvider │  │WorkspaceSidebar│  │   ExcalidrawWrapper  │ │
│  └──────────────┘  └──────────────┘  └───────────────────────┘ │
│                    ┌──────────────┐                             │
│                    │SettingsLayout│  (Full-page settings)       │
│                    └──────────────┘                             │
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

> **See also:** [Roles, Teams & Collections](./ROLES_TEAMS_COLLECTIONS.md) for the complete schema including Teams and InviteLinks.

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
