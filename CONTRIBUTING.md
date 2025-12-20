# Contributing to AstraDraw

Thank you for your interest in contributing to AstraDraw! This guide will help you set up your local development environment.

## Prerequisites

- **Node.js** 18+ 
- **Yarn** 1.22+ (for frontend)
- **npm** 9+ (for backend)
- **Docker** and **Docker Compose**
- **Git**

## Repository Structure

AstraDraw consists of multiple repositories:

| Repository | Description | Local Folder |
|------------|-------------|--------------|
| [astradraw](https://github.com/astrateam-net/astradraw) | Main orchestration (this repo) | `/` |
| [astradraw-app](https://github.com/astrateam-net/astradraw-app) | React frontend (Excalidraw fork) | `frontend/` |
| [astradraw-api](https://github.com/astrateam-net/astradraw-api) | NestJS backend API | `backend/` |
| [astradraw-room](https://github.com/astrateam-net/astradraw-room) | WebSocket server | `room-service/` |

## Getting Started

### 1. Clone the Main Repository

```bash
git clone https://github.com/astrateam-net/astradraw.git
cd astradraw
```

### 2. Clone the Sub-repositories

```bash
# Frontend (Excalidraw fork)
git clone https://github.com/astrateam-net/astradraw-app.git frontend

# Backend (NestJS API)
git clone https://github.com/astrateam-net/astradraw-api.git backend

# Room service (WebSocket)
git clone https://github.com/astrateam-net/astradraw-room.git room-service
```

### 3. Set Up the Deploy Environment

```bash
cd deploy

# Copy environment template
cp env.example .env

# Create secrets
mkdir -p secrets
echo "minioadmin" > secrets/minio_access_key
openssl rand -base64 32 > secrets/minio_secret_key

# Create self-signed certificates for local HTTPS
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/server.key -out certs/server.crt \
  -subj "/CN=localhost"

# Enable local builds
cp docker-compose.override.yml.disabled docker-compose.override.yml
```

### 4. Build and Run

```bash
# From the deploy/ folder
docker compose up -d --build

# View logs
docker compose logs -f app   # Frontend logs
docker compose logs -f api   # Backend logs
```

### 5. Access the Application

Open https://localhost in your browser (accept the self-signed certificate warning).

## Development Workflow

### Working on Frontend

```bash
cd frontend
yarn install
yarn start          # Development server on http://localhost:5173
```

**Before committing:**
```bash
yarn test:typecheck    # TypeScript type checking
yarn test:other        # Prettier formatting
yarn test:code         # ESLint code quality
```

### Working on Backend

```bash
cd backend
npm install
npm run start:dev      # Development server with hot reload
```

**Before committing:**
```bash
npm run build          # Build (includes TypeScript)
npm run format         # Prettier formatting
npm run lint           # ESLint code quality
```

### Working on Room Service

The room service is typically used as-is from upstream. If you need to modify it:

```bash
cd room-service
yarn install
yarn start:dev
```

## Running Tests

### Frontend
```bash
cd frontend
yarn test:all          # Run all checks + unit tests
```

### Backend
```bash
cd backend
npm run test           # Unit tests
npm run test:e2e       # End-to-end tests
```

## Docker Profiles

```bash
cd deploy

# Standard services
docker compose up -d

# With admin tools (pgAdmin, MinIO Console)
docker compose --profile admin up -d

# With OIDC testing (Dex)
docker compose --profile oidc up -d
```

## Making Changes

### 1. Create Feature Branches

Create branches in **all affected repositories** with the same name:

```bash
# If changing frontend
cd frontend
git checkout -b feature/my-feature

# If changing backend
cd backend
git checkout -b feature/my-feature
```

### 2. Make Your Changes

Follow the patterns documented in:
- `docs/ARCHITECTURE.md` - Technical architecture
- `.cursor/rules/` - Development patterns (if using Cursor IDE)

### 3. Test Locally

```bash
# Run checks
cd frontend && yarn test:all
cd backend && npm run build && npm run lint

# Test with Docker
cd deploy && docker compose up -d --build
```

### 4. Commit and Push

```bash
# Frontend
cd frontend
git add -A
git commit -m "feat: description of changes"
git push origin feature/my-feature

# Backend (if changed)
cd backend
git add -A
git commit -m "feat: description of changes"
git push origin feature/my-feature
```

### 5. Create Pull Requests

Create PRs in each affected repository. Link related PRs in the description.

## Commit Message Format

We use conventional commits:

```
type(scope): description

[optional body]
```

**Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `chore:` - Maintenance

**Examples:**
```
feat(workspace): add auto-save functionality
fix(auth): resolve JWT cookie not being sent
docs: update API documentation
```

## Code Style

### Frontend (TypeScript/React)
- Use functional components with hooks
- Use Jotai for shared state
- Add translations to both `en.json` and `ru-RU.json`
- Stop keyboard event propagation in input fields

### Backend (TypeScript/NestJS)
- Use Prisma for database operations
- JWT guard is at `auth/jwt.guard.ts`
- Use `@types/multer` for file uploads

## Getting Help

- Check existing documentation in `docs/`
- Look at similar features for patterns
- Open an issue for questions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

