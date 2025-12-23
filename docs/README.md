# AstraDraw Documentation

This is the documentation index for AstraDraw, a self-hosted Excalidraw fork with enterprise features.

## Quick Navigation for AI Agents

**Use this decision tree to find relevant documentation:**

| If you need to... | Read these docs |
|-------------------|-----------------|
| Understand the project | [Architecture](architecture/ARCHITECTURE.md) |
| Set up development environment | [Development Guide](getting-started/DEVELOPMENT.md) |
| Work on frontend UI/components | [Workspace UI Styling](guides/WORKSPACE_UI_STYLING.md), [State Management](architecture/STATE_MANAGEMENT.md) |
| Work on backend API | [Architecture](architecture/ARCHITECTURE.md), [Roles & Teams](guides/ROLES_TEAMS_COLLECTIONS.md) |
| Fix navigation/routing bugs | [URL Routing](architecture/URL_ROUTING.md), [Scene Navigation](architecture/SCENE_NAVIGATION.md) |
| Fix scene loading issues | [CSS Hide/Show Fix](troubleshooting/CRITICAL_CSS_HIDE_SHOW_FIX.md) |
| Implement a new feature | [Implementation Plans](planning/IMPLEMENTATION_PLANS.md), [Technical Debt](planning/TECHNICAL_DEBT_AND_IMPROVEMENTS.md) |
| Work on collaboration | [Collaboration](features/COLLABORATION.md), [Auto-Collaboration](features/AUTO_COLLABORATION.md) |
| Deploy or configure Docker | [Docker Secrets](deployment/DOCKER_SECRETS.md), [SSO Setup](deployment/SSO_OIDC_SETUP.md) |
| Debug issues | See [Troubleshooting](#troubleshooting) section |

---

## Documentation by Category

### Getting Started

| Document | Description |
|----------|-------------|
| [DEVELOPMENT.md](getting-started/DEVELOPMENT.md) | Development environment setup with hot-reload |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | Contribution guidelines and workflow |

### Architecture

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](architecture/ARCHITECTURE.md) | System architecture, components, database schema |
| [STATE_MANAGEMENT.md](architecture/STATE_MANAGEMENT.md) | Jotai atoms, when to use useState vs atoms |
| [URL_ROUTING.md](architecture/URL_ROUTING.md) | URL patterns, navigation atoms, router utilities |
| [SCENE_NAVIGATION.md](architecture/SCENE_NAVIGATION.md) | Scene loading flow, CSS hide/show pattern |

### Features

| Document | Description |
|----------|-------------|
| [WORKSPACE.md](features/WORKSPACE.md) | Authentication, workspaces, scene management |
| [COLLABORATION.md](features/COLLABORATION.md) | Real-time collaboration system |
| [AUTO_COLLABORATION.md](features/AUTO_COLLABORATION.md) | Auto-collaboration for shared collections |
| [TALKTRACK.md](features/TALKTRACK.md) | Video recording feature |
| [PRESENTATION_MODE.md](features/PRESENTATION_MODE.md) | Slideshow/presentation functionality |
| [QUICK_SEARCH.md](features/QUICK_SEARCH.md) | Quick search (Cmd+K) implementation |
| [PENS_IMPLEMENTATION.md](features/PENS_IMPLEMENTATION.md) | Custom pen presets |
| [GIPHY_SUPPORT.md](features/GIPHY_SUPPORT.md) | Stickers and GIFs integration |
| [LIBRARIES_SYSTEM.md](features/LIBRARIES_SYSTEM.md) | Shape library system |
| [THUMBNAIL_PREVIEW.md](features/THUMBNAIL_PREVIEW.md) | Scene thumbnail generation |
| [INVITE_LINKS.md](features/INVITE_LINKS.md) | Workspace invite links |

### Deployment

| Document | Description |
|----------|-------------|
| [DOCKER_SECRETS.md](deployment/DOCKER_SECRETS.md) | Docker secrets configuration |
| [SSO_OIDC_SETUP.md](deployment/SSO_OIDC_SETUP.md) | OIDC/SSO authentication setup |

### Guides

| Document | Description |
|----------|-------------|
| [USER_PROFILE.md](guides/USER_PROFILE.md) | User profile management |
| [WORKSPACE_UI_STYLING.md](guides/WORKSPACE_UI_STYLING.md) | CSS patterns, dark mode, fonts |
| [AUTOSAVE.md](guides/AUTOSAVE.md) | Auto-save implementation details |
| [ROLES_TEAMS_COLLECTIONS.md](guides/ROLES_TEAMS_COLLECTIONS.md) | Permission model, teams, collections |

### Troubleshooting

| Document | Description |
|----------|-------------|
| [CRITICAL_CSS_HIDE_SHOW_FIX.md](troubleshooting/CRITICAL_CSS_HIDE_SHOW_FIX.md) | Fix for scene data loss on navigation |
| [SCENE_NAVIGATION_TESTS.md](troubleshooting/SCENE_NAVIGATION_TESTS.md) | Navigation test scenarios |
| [MAX_FILE_SIZE_ISSUE.md](troubleshooting/MAX_FILE_SIZE_ISSUE.md) | File size limit troubleshooting |

### Planning

| Document | Description |
|----------|-------------|
| [ROADMAP.md](planning/ROADMAP.md) | Planned features and specifications |
| [IMPLEMENTATION_PLANS.md](planning/IMPLEMENTATION_PLANS.md) | Ready-to-implement improvement plans |
| [TECHNICAL_DEBT_AND_IMPROVEMENTS.md](planning/TECHNICAL_DEBT_AND_IMPROVEMENTS.md) | Technical debt analysis |
| [COLLABORATION_IMPLEMENTATION_PLAN.md](planning/COLLABORATION_IMPLEMENTATION_PLAN.md) | Collaboration system implementation |
| [SCENES_CACHE.md](planning/SCENES_CACHE.md) | Scenes caching system |

---

## Key Commands

```bash
# Development (hot-reload)
just dev              # Start everything
just dev-status       # Check status
just dev-stop         # Stop everything

# Checks
just check-all        # Run all checks (frontend + backend + room)
just check-frontend   # TypeScript + Prettier + ESLint
just check-backend    # Build + Prettier + ESLint

# Docker
just up-dev           # Start with local builds
just fresh-dev        # Fresh start with local builds
just up               # Start with production images
```

---

## Key File Locations

| Purpose | Path |
|---------|------|
| Frontend entry | `frontend/excalidraw-app/App.tsx` |
| Backend entry | `backend/src/main.ts` |
| State atoms | `frontend/excalidraw-app/components/Settings/settingsState.ts` |
| API client | `frontend/excalidraw-app/auth/api/` (modular structure) |
| URL router | `frontend/excalidraw-app/router.ts` |
| Prisma schema | `backend/prisma/schema.prisma` |
| Docker config | `deploy/docker-compose.yml` |
| Cursor rules | `.cursor/rules/` (folder format with RULE.md files) |

