# AstraDraw

A fully self-hosted, feature-rich fork of [Excalidraw](https://excalidraw.com) with real-time collaboration, user workspaces, video recordings, presentation mode, and more.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> [!WARNING]
> ## 🚧 Alpha Release
>
> **This is a hobby project in active development.** I created AstraDraw because I wanted to share some of my [Obsidian](https://obsidian.md) whiteboards with my team — while keeping the files local in my vault. Inspired by the excellent [Obsidian Excalidraw Plugin](https://github.com/zsviczian/obsidian-excalidraw-plugin) by [@zsviczian](https://github.com/zsviczian).
>
> A few things to keep in mind:
> - 🤖 **Most code is AI-assisted** (written with [Cursor](https://cursor.com))
> - 👤 **Solo developer** — no team behind this, just me working in spare time
> - ⚠️ **Expect bugs and breaking changes** as the project evolves
>
> That said, it works for my use case and I'm actively improving it. If you find this useful, contributions are very welcome! 🙌
>
> ---
>
> ### 🔮 Planned: Obsidian Vault Sync
>
> The end goal is to selectively sync `.excalidraw` files from your Obsidian vault to a self-hosted AstraDraw instance (via [Syncthing](https://syncthing.net/), mounted volumes, or similar). The synced boards appear in your private workspace, where you can share specific boards with different teams using AstraDraw's role-based access control. All changes sync back to your Obsidian vault — **your vault remains the source of truth, AstraDraw becomes the collaboration layer.**
>
> *Not yet implemented — focusing on core features first.*

## About

AstraDraw extends the open-source Excalidraw whiteboard with enterprise-ready features while remaining fully self-hostable. It's designed for teams and organizations that need:

- **User authentication** via OIDC (Authentik, Keycloak, Dex) or local accounts
- **Workspaces** with teams, collections, and role-based access (Admin/Member/Viewer)
- **Real-time collaboration** with presence indicators and cursor tracking
- **Threaded comments** with @mentions and real-time sync
- **In-app notifications** for mentions and comment replies
- **Video walkthroughs** (Talktrack) with camera picture-in-picture
- **Presentation mode** using frames as slides with laser pointer
- **Custom pen presets** (highlighter, fountain, marker, etc.)
- **Quick search** (Cmd+K) to find scenes across workspaces
- **GIF/Sticker search** via GIPHY integration

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
| **Workspaces** | Personal & shared workspaces with scene organization | [docs/features/WORKSPACE.md](docs/features/WORKSPACE.md) |
| **Roles & Teams** | Role-based access (Admin/Member/Viewer), team management | [docs/guides/ROLES_TEAMS_COLLECTIONS.md](docs/guides/ROLES_TEAMS_COLLECTIONS.md) |
| **Collaboration** | Real-time collaboration with presence & cursor tracking | [docs/features/COLLABORATION.md](docs/features/COLLABORATION.md) |
| **Comments** | Threaded canvas comments with @mentions | [docs/features/COMMENTS.md](docs/features/COMMENTS.md) |
| **Notifications** | In-app notifications for mentions and replies | [docs/features/NOTIFICATIONS.md](docs/features/NOTIFICATIONS.md) |
| **Talktrack** | Record canvas walkthroughs with camera PIP | [docs/features/TALKTRACK.md](docs/features/TALKTRACK.md) |
| **Presentation** | Use frames as slides with laser pointer | [docs/features/PRESENTATION_MODE.md](docs/features/PRESENTATION_MODE.md) |
| **Custom Pens** | Highlighter, fountain, marker presets | [docs/features/PENS_IMPLEMENTATION.md](docs/features/PENS_IMPLEMENTATION.md) |
| **Quick Search** | Cmd+K to search scenes across workspaces | [docs/features/QUICK_SEARCH.md](docs/features/QUICK_SEARCH.md) |

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

AstraDraw consists of multiple repositories:

| Repository | Description |
|------------|-------------|
| [astradraw](https://github.com/AstraDraw/astradraw) | Main orchestration (this repo) - deployment, docs |
| [astradraw-app](https://github.com/AstraDraw/astradraw-app) | React frontend (Excalidraw fork) |
| [astradraw-api](https://github.com/AstraDraw/astradraw-api) | NestJS backend API |
| [astradraw-room](https://github.com/AstraDraw/astradraw-room) | WebSocket collaboration server |

```
astradraw/
├── frontend/           # React app (clone astradraw-app here)
├── backend/            # NestJS API (clone astradraw-api here)
├── room-service/       # WebSocket server (clone astradraw-room here)
├── docs/               # Documentation
├── deploy/             # Docker Compose, configs
└── Justfile            # Development commands
```

## Quick Start

### Development

```bash
# 1. Clone all repositories
git clone https://github.com/AstraDraw/astradraw.git
cd astradraw
git clone https://github.com/AstraDraw/astradraw-app.git frontend
git clone https://github.com/AstraDraw/astradraw-api.git backend
git clone https://github.com/AstraDraw/astradraw-room.git room-service

# 2. Setup (first time only)
just setup

# 3. Start development with hot-reload
just dev

# 4. Access at https://draw.local
```

### Docker Deployment

```bash
# 1. Clone this repository
git clone https://github.com/AstraDraw/astradraw.git
cd astradraw/deploy

# 2. Copy environment template
cp env.example .env

# 3. Create secrets
mkdir -p secrets
openssl rand -base64 32 > secrets/jwt_secret
openssl rand -base64 32 > secrets/postgres_password
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

Copy `deploy/env.example` to `deploy/.env` and configure:

| Variable | Description |
|----------|-------------|
| `APP_DOMAIN` | Your domain (e.g., `draw.example.com`) |
| `APP_PROTOCOL` | `http` or `https` |
| `POSTGRES_*` | PostgreSQL credentials |
| `OIDC_*` | OIDC provider settings (optional) |
| `GIPHY_API_KEY` | For Stickers & GIFs sidebar |

### Authentication Options

1. **Local Auth** (default): Email/password with admin account
2. **OIDC/SSO**: Authentik, Keycloak, Dex, or any OIDC provider
3. **Hybrid**: Both local and SSO enabled

See [docs/deployment/SSO_OIDC_SETUP.md](docs/deployment/SSO_OIDC_SETUP.md) for detailed auth setup.

### Docker Secrets

All sensitive variables support the `_FILE` suffix pattern for Docker secrets:

```yaml
environment:
  - JWT_SECRET_FILE=/run/secrets/jwt_secret
```

See [docs/deployment/DOCKER_SECRETS.md](docs/deployment/DOCKER_SECRETS.md) for details.

## Documentation

| Document | Description |
|----------|-------------|
| [docs/README.md](docs/README.md) | Full documentation index |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Development setup guide |
| [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) | Technical architecture |
| [docs/deployment/](docs/deployment/) | Deployment guides |

## Tech Stack

**Frontend:** React 18, TypeScript, Vite, Jotai, SCSS

**Backend:** NestJS, Prisma, PostgreSQL, MinIO/S3, JWT

**Infrastructure:** Docker Compose, Traefik, Let's Encrypt

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for development setup.

**Note:** All issues should be filed in this repository, not in the sub-repos.

## Credits

AstraDraw is built on the shoulders of giants:

- [Excalidraw](https://github.com/excalidraw/excalidraw) - The amazing open-source whiteboard (MIT License)
- [excalidraw-room](https://github.com/excalidraw/excalidraw-room) - Official collaboration server (MIT License)
- [excalidraw-storage-backend](https://github.com/alswl/excalidraw-storage-backend) - Storage backend foundation (MIT License)
- [Obsidian Excalidraw Plugin](https://github.com/zsviczian/obsidian-excalidraw-plugin) - Inspiration for pens and presentation mode

## License

MIT License - see [LICENSE](LICENSE) for details.

This project includes code from:
- Excalidraw © 2020 Excalidraw (MIT License)
- excalidraw-storage-backend © 2022 Kilian Decaderincourt (MIT License)
