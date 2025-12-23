# AstraDraw - Self-hosted Excalidraw with Collaboration & Workspaces

A fully self-hosted, feature-rich fork of [Excalidraw](https://excalidraw.com) with real-time collaboration, user workspaces, video recordings, presentation mode, custom pens, and more.

## About This Project

AstraDraw extends the open-source Excalidraw whiteboard with enterprise-ready features while remaining fully self-hostable. It's designed for teams and organizations that need:

- **User authentication** via OIDC (Authentik, Keycloak, Dex) or local accounts
- **Personal workspaces** to save, organize, and sync drawings across devices
- **Video walkthroughs** (Talktrack) with camera PIP and Kinescope integration
- **Presentation mode** using frames as slides with laser pointer
- **Custom pen presets** (highlighter, fountain, marker, etc.)
- **GIF/Sticker search** via GIPHY integration
- **Pre-bundled libraries** for team-wide shape collections

All features are documented in the `/docs` folder for AI assistants and developers.

## Features

### Core Features (from Excalidraw)
- 🎨 **Infinite canvas** with hand-drawn style
- 🔒 **End-to-end encryption** for all scene data
- 🤝 **Real-time collaboration** via WebSocket
- 📱 **Responsive design** for desktop and mobile
- 🌙 **Dark mode** support

### AstraDraw Extensions

| Feature | Description | Documentation |
|---------|-------------|---------------|
| **Workspace** | Save/organize scenes with user accounts | [docs/features/WORKSPACE.md](docs/features/WORKSPACE.md) |
| **Roles, Teams & Collections** | Multi-workspace support with ADMIN/MEMBER/VIEWER roles | [docs/guides/ROLES_TEAMS_COLLECTIONS.md](docs/guides/ROLES_TEAMS_COLLECTIONS.md) |
| **User Profile** | Avatar upload, name editing, profile management | [docs/guides/USER_PROFILE.md](docs/guides/USER_PROFILE.md) |
| **Collaboration** | Real-time collaboration with profile integration | [docs/features/COLLABORATION.md](docs/features/COLLABORATION.md) |
| **Talktrack** | Record canvas walkthroughs with camera PIP | [docs/features/TALKTRACK.md](docs/features/TALKTRACK.md) |
| **Presentation Mode** | Use frames as slides with laser pointer | [docs/features/PRESENTATION_MODE.md](docs/features/PRESENTATION_MODE.md) |
| **Custom Pens** | Highlighter, fountain, marker presets | [docs/features/PENS_IMPLEMENTATION.md](docs/features/PENS_IMPLEMENTATION.md) |
| **Stickers & GIFs** | GIPHY integration for inserting media | [docs/features/GIPHY_SUPPORT.md](docs/features/GIPHY_SUPPORT.md) |
| **Libraries** | Pre-bundled shape libraries via Docker | [docs/features/LIBRARIES_SYSTEM.md](docs/features/LIBRARIES_SYSTEM.md) |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Traefik Proxy (HTTPS)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐   │
│  │ /            │  │ /socket.io/  │  │ /api/v2/                 │   │
│  │ Frontend     │  │ Room Server  │  │ Backend API              │   │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
         │                  │                      │
         ▼                  ▼                      ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────────────────┐
│ React + Vite    │ │ Socket.io       │ │ NestJS + Prisma             │
│ Excalidraw Fork │ │ Collaboration   │ │ - Auth (OIDC/Local)         │
│                 │ │                 │ │ - Workspace API             │
│                 │ │                 │ │ - Talktrack API             │
│                 │ │                 │ │ - Storage (S3/MinIO)        │
└─────────────────┘ └─────────────────┘ └─────────────────────────────┘
                                                   │
                           ┌───────────────────────┴───────────────────┐
                           ▼                                           ▼
                  ┌─────────────────────┐               ┌─────────────────────┐
                  │    PostgreSQL       │               │    MinIO/S3         │
                  │  (Users, Scenes,    │               │  (Scene data,       │
                  │   Metadata)         │               │   Files, Rooms)     │
                  └─────────────────────┘               └─────────────────────┘
```

## Repository Structure

```
astradraw/
├── frontend/           # React app (Excalidraw fork) - separate git repo
├── backend/            # NestJS API - separate git repo
├── room-service/       # WebSocket server - separate git repo
├── docs/               # Feature documentation (organized by category)
│   ├── architecture/   # Technical architecture docs
│   ├── features/       # Feature documentation
│   ├── guides/         # How-to guides
│   ├── deployment/     # Deployment & configuration
│   ├── planning/       # Roadmap & implementation plans
│   └── troubleshooting/# Common issues & fixes
├── deploy/             # Docker Compose, configs, secrets
│   ├── docker-compose.yml
│   ├── .env, env.example
│   ├── certs/          # SSL certificates
│   ├── secrets/        # Docker secrets
│   └── libraries/      # Excalidraw shape libraries
└── .cursor/rules/      # AI assistant rules
```

| Folder | Description |
|--------|-------------|
| `frontend/` | Modified Excalidraw frontend with all AstraDraw features |
| `backend/` | NestJS API for auth, workspace, storage, and Talktrack |
| `room-service/` | WebSocket server for real-time collaboration (upstream) |
| `docs/` | Detailed documentation for each feature |
| `deploy/` | All deployment files (Docker, configs, secrets, certs) |

## Quick Start

### Development (Recommended)

```bash
# 1. Clone all repositories
git clone https://github.com/astrateam-net/astradraw.git
cd astradraw
git clone https://github.com/astrateam-net/astradraw-app.git frontend
git clone https://github.com/astrateam-net/astradraw-api.git backend
git clone https://github.com/astrateam-net/astradraw-room.git room-service

# 2. Setup (first time only)
just setup

# 3. Start development with hot-reload
just dev

# 4. Access at https://draw.local
```

### Docker Deployment

```bash
# 1. Clone this repository
git clone https://github.com/astrateam-net/astradraw.git
cd astradraw/deploy

# 2. Copy environment template
cp env.example .env

# 3. Create secrets directory
mkdir -p secrets
echo "minioadmin" > secrets/minio_access_key
openssl rand -base64 32 > secrets/minio_secret_key

# 4. Generate self-signed certs for local testing
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/server.key -out certs/server.crt \
  -subj "/CN=draw.local"

# 5. Start all services
docker compose up -d

# 6. Access at https://draw.local (add to /etc/hosts if needed)
```

## Configuration

### Environment Variables

In `deploy/`, copy `env.example` to `.env` and configure:

| Variable | Description |
|----------|-------------|
| `APP_DOMAIN` | Your domain (e.g., `draw.example.com`) |
| `APP_PROTOCOL` | `http` or `https` |
| `POSTGRES_*` | PostgreSQL credentials |
| `OIDC_*` | OIDC provider settings (optional) |
| `GIPHY_API_KEY` | For Stickers & GIFs sidebar |
| `KINESCOPE_*` | For Talktrack video hosting |

### Authentication Options

1. **Local Auth** (default): Email/password with admin account
2. **OIDC/SSO**: Authentik, Keycloak, Dex, or any OIDC provider
3. **Hybrid**: Both local and SSO enabled

See [docs/deployment/SSO_OIDC_SETUP.md](docs/deployment/SSO_OIDC_SETUP.md) for detailed auth setup.

### Docker Secrets Support

All sensitive variables support the `_FILE` suffix pattern:

```yaml
environment:
  - S3_ACCESS_KEY_FILE=/run/secrets/minio_access_key
volumes:
  - ./secrets:/run/secrets:ro
```

See [docs/deployment/DOCKER_SECRETS.md](docs/deployment/DOCKER_SECRETS.md) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed setup instructions.

## API Endpoints

### Authentication
- `GET /api/v2/auth/status` - Check auth configuration
- `GET /api/v2/auth/login` - Start OIDC login flow
- `POST /api/v2/auth/login` - Local login
- `POST /api/v2/auth/register` - Local registration
- `GET /api/v2/auth/me` - Get current user

### Workspace & Scenes
- `GET /api/v2/workspace/scenes` - List user's scenes
- `POST /api/v2/workspace/scenes` - Create scene
- `GET /api/v2/workspace/scenes/:id/data` - Get scene data
- `PUT /api/v2/workspace/scenes/:id` - Update scene

### Workspaces, Teams & Collections
- `GET /api/v2/workspaces` - List user's workspaces
- `GET /api/v2/workspaces/:id/members` - List workspace members
- `POST /api/v2/workspaces/:id/members/invite` - Invite member (admin)
- `GET /api/v2/workspaces/:id/teams` - List teams
- `GET /api/v2/workspaces/:id/collections` - List collections
- `POST /api/v2/workspaces/join` - Join via invite link

### User Profile
- `GET /api/v2/users/me` - Get profile
- `PUT /api/v2/users/me` - Update profile
- `POST /api/v2/users/me/avatar` - Upload avatar

### Talktrack
- `GET /api/v2/workspace/scenes/:id/talktracks` - List recordings
- `POST /api/v2/workspace/scenes/:id/talktracks` - Create recording

## Documentation

| Document | Description |
|----------|-------------|
| [CONTRIBUTING.md](CONTRIBUTING.md) | **How to set up for development** |
| [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) | Technical architecture and design decisions |
| [docs/planning/ROADMAP.md](docs/planning/ROADMAP.md) | Planned features and specifications |

### Feature Documentation

| Feature | Documentation |
|---------|---------------|
| Workspace & Auth | [docs/features/WORKSPACE.md](docs/features/WORKSPACE.md) |
| Roles, Teams & Collections | [docs/guides/ROLES_TEAMS_COLLECTIONS.md](docs/guides/ROLES_TEAMS_COLLECTIONS.md) |
| User Profile | [docs/guides/USER_PROFILE.md](docs/guides/USER_PROFILE.md) |
| Collaboration | [docs/features/COLLABORATION.md](docs/features/COLLABORATION.md) |
| Talktrack | [docs/features/TALKTRACK.md](docs/features/TALKTRACK.md) |
| Presentation Mode | [docs/features/PRESENTATION_MODE.md](docs/features/PRESENTATION_MODE.md) |
| Custom Pens | [docs/features/PENS_IMPLEMENTATION.md](docs/features/PENS_IMPLEMENTATION.md) |
| Stickers & GIFs | [docs/features/GIPHY_SUPPORT.md](docs/features/GIPHY_SUPPORT.md) |
| Libraries | [docs/features/LIBRARIES_SYSTEM.md](docs/features/LIBRARIES_SYSTEM.md) |

## Tech Stack

### Frontend
- React 18 + TypeScript
- Vite build system
- Jotai state management
- SCSS modules

### Backend
- NestJS framework
- Prisma ORM
- PostgreSQL database
- MinIO/S3 object storage
- JWT authentication

### Infrastructure
- Docker Compose orchestration
- Traefik reverse proxy
- Let's Encrypt SSL (optional)

## AI-Assisted Development

This project is optimized for development with Cursor IDE. Open `astradraw/` as your workspace to get AI assistance across all repositories.

### Cursor Rules

The `.cursor/rules/` folder contains AI instructions for:
- Project structure and patterns
- Common issues and solutions
- Multi-repo workflow
- Context management

## Credits

- [Excalidraw](https://github.com/excalidraw/excalidraw) - The amazing whiteboard app
- [excalidraw-room](https://github.com/excalidraw/excalidraw-room) - Official collaboration server (upstream)
- [Obsidian Excalidraw Plugin](https://github.com/zsviczian/obsidian-excalidraw-plugin) - Inspiration for pens and presentation mode
- [alswl/excalidraw-storage-backend](https://github.com/alswl/excalidraw-storage-backend) - Storage backend foundation

## License

MIT

