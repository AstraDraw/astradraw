# Changelog

All notable changes to AstraDraw will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-25

### Added

**Authentication & User Management**
- User authentication with OIDC/SSO support (Authentik, Keycloak, Dex, or any OIDC provider)
- Local authentication with email/password
- User profiles with avatar upload and name editing
- Super admin role for instance-level management

**Workspaces & Organization**
- Personal workspaces (owner-only, no collaboration)
- Shared workspaces with team collaboration
- Collections for organizing scenes within workspaces
- Teams with role-based access control (Admin/Member/Viewer)
- Invite links for workspace sharing

**Real-time Collaboration**
- Real-time collaboration with presence indicators
- Cursor tracking for collaborators
- Auto-collaboration for scenes in shared collections
- End-to-end encryption for scene data

**Comments & Notifications**
- Threaded canvas comments anchored to elements
- @mentions in comments
- In-app notification system for mentions and replies
- Real-time comment sync across collaborators

**Content Creation**
- Talktrack video recordings with camera PIP (Kinescope integration)
- Presentation mode using frames as slides
- Implicit laser pointer in presentation mode
- Custom pen presets (highlighter, fountain, marker)
- GIPHY integration for stickers and GIFs
- Pre-bundled shape libraries

**User Experience**
- Quick search (Cmd+K) across workspaces
- Scene thumbnail previews in dashboard
- Dark mode support
- Responsive design for desktop and mobile

**Infrastructure**
- Docker Compose deployment with Traefik reverse proxy
- S3/MinIO storage backend
- PostgreSQL database with Prisma ORM
- Docker secrets support for secure credential management
- Let's Encrypt SSL support

### Based On

- Frontend forked from [Excalidraw](https://github.com/excalidraw/excalidraw) (MIT License)
- Backend inspired by [excalidraw-storage-backend](https://github.com/alswl/excalidraw-storage-backend) (MIT License)
- Room service forked from [excalidraw-room](https://github.com/excalidraw/excalidraw-room) (MIT License)

