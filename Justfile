# AstraDraw Development Commands
# Run `just` to see all available commands

# Default: show help
default:
    @just --list

# ============================================
# DOCKER DEPLOYMENT
# ============================================

# Start all services (production images)
up:
    cd deploy && docker compose up -d

# Start with local builds
up-dev:
    cd deploy && docker compose up -d --build

# Stop all services
down:
    cd deploy && docker compose down

# Restart all services
restart:
    cd deploy && docker compose restart

# View logs (all services)
logs:
    cd deploy && docker compose logs -f

# View API logs
logs-api:
    cd deploy && docker compose logs -f api

# View frontend logs
logs-app:
    cd deploy && docker compose logs -f app

# Fresh start (remove volumes)
fresh:
    cd deploy && docker compose down -v
    docker volume rm astradraw_postgres_data astradraw_minio_data 2>/dev/null || true
    cd deploy && docker compose up -d

# Start with OIDC testing (Dex)
up-oidc:
    cd deploy && docker compose --profile oidc up -d

# Start with admin tools (pgAdmin, MinIO Console)
up-admin:
    cd deploy && docker compose --profile admin up -d

# ============================================
# FRONTEND CHECKS
# ============================================

# Run all frontend checks
check-frontend:
    cd frontend && yarn test:typecheck && yarn test:other && yarn test:code

# Frontend TypeScript check
check-frontend-types:
    cd frontend && yarn test:typecheck

# Frontend Prettier check
check-frontend-format:
    cd frontend && yarn test:other

# Frontend ESLint check
check-frontend-lint:
    cd frontend && yarn test:code

# Fix frontend formatting issues
fix-frontend:
    cd frontend && yarn fix

# Run frontend tests
test-frontend:
    cd frontend && yarn test:all

# ============================================
# BACKEND CHECKS
# ============================================

# Run all backend checks
check-backend:
    cd backend && npm run build && npm run format && npm run lint

# Backend TypeScript build
check-backend-build:
    cd backend && npm run build

# Backend Prettier check
check-backend-format:
    cd backend && npm run format

# Backend ESLint check
check-backend-lint:
    cd backend && npm run lint

# Run backend tests
test-backend:
    cd backend && npm run test

# ============================================
# ROOM SERVICE CHECKS
# ============================================

# Run all room service checks
check-room:
    cd room-service && yarn build && yarn test

# Fix room service formatting
fix-room:
    cd room-service && yarn fix

# ============================================
# ALL CHECKS
# ============================================

# Run all checks (frontend + backend + room)
check-all: check-frontend check-backend check-room

# Fix all formatting issues
fix-all: fix-frontend fix-room
    cd backend && npm run format

# ============================================
# DEVELOPMENT
# ============================================

# Start frontend dev server
dev-frontend:
    cd frontend && yarn start

# Start backend dev server
dev-backend:
    cd backend && npm run start:dev

# Install all dependencies
install:
    cd frontend && yarn install
    cd backend && npm install
    cd room-service && yarn install

# ============================================
# DATABASE
# ============================================

# Run Prisma migrations
db-migrate:
    cd backend && npx prisma migrate deploy

# Generate Prisma client
db-generate:
    cd backend && npx prisma generate

# Open Prisma Studio
db-studio:
    cd backend && npx prisma studio

# Reset database (development only!)
db-reset:
    cd backend && npx prisma migrate reset

# ============================================
# RELEASE (use with caution)
# ============================================

# Tag and push frontend
release-frontend version:
    cd frontend && git tag v{{version}} && git push origin main --tags

# Tag and push backend
release-backend version:
    cd backend && git tag v{{version}} && git push origin main --tags

# Tag and push room service
release-room version:
    cd room-service && git tag v{{version}} && git push origin main --tags

# ============================================
# GIT STATUS
# ============================================

# Show git status for all repos
status:
    @echo "=== Main Repo ===" && git status -s
    @echo "\n=== Frontend ===" && cd frontend && git status -s
    @echo "\n=== Backend ===" && cd backend && git status -s
    @echo "\n=== Room Service ===" && cd room-service && git status -s

# Pull latest from all repos
pull:
    git pull origin main
    cd frontend && git pull origin main
    cd backend && git pull origin main
    cd room-service && git pull origin main

# ============================================
# SETUP
# ============================================

# Initial setup for new developers
setup:
    @echo "Setting up AstraDraw development environment..."
    @test -d frontend || (echo "Cloning frontend..." && git clone git@github.com:astrateam-net/astradraw-app.git frontend)
    @test -d backend || (echo "Cloning backend..." && git clone git@github.com:astrateam-net/astradraw-api.git backend)
    @test -d room-service || (echo "Cloning room service..." && git clone git@github.com:astrateam-net/astradraw-room.git room-service)
    @test -f deploy/.env || cp deploy/env.example deploy/.env
    @test -d deploy/secrets || mkdir -p deploy/secrets
    @test -f deploy/secrets/minio_access_key || echo "minioadmin" > deploy/secrets/minio_access_key
    @test -f deploy/secrets/minio_secret_key || openssl rand -base64 32 > deploy/secrets/minio_secret_key
    @test -d deploy/certs || mkdir -p deploy/certs
    @test -f deploy/certs/server.crt || openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout deploy/certs/server.key -out deploy/certs/server.crt -subj "/CN=localhost"
    @echo "Installing dependencies..."
    just install
    @echo "\nSetup complete! Run 'just up-dev' to start."

