# =============================================================================
# AstraDraw Development Commands
# =============================================================================
# Run `just` to see all available commands
#
# QUICK REFERENCE:
#   just dev          - Start everything with hot-reload
#   just dev-stop     - Stop everything
#   just check        - Run all code checks before commit
#   just up           - Start with Docker (production images)
#   just up-local     - Start with Docker (local builds)
# =============================================================================

# Default: show help
default:
    @just --list

# =============================================================================
# DAILY DEVELOPMENT (most used commands)
# =============================================================================
# Use these for day-to-day development with hot-reload.
# Native services (frontend/backend/room) + Docker infrastructure.

# Start everything for development (infrastructure + native services with hot-reload)
dev:
    #!/usr/bin/env bash
    set -e
    
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           AstraDraw Development Mode                       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Check if draw.local is in /etc/hosts
    if ! grep -q "draw.local" /etc/hosts 2>/dev/null; then
        echo "⚠️  WARNING: 'draw.local' is not in /etc/hosts!"
        echo ""
        echo "   Add it with:"
        echo "   sudo sh -c 'echo \"127.0.0.1 draw.local\" >> /etc/hosts'"
        echo ""
        read -p "   Press Enter to continue anyway, or Ctrl+C to abort..."
        echo ""
    fi
    
    # Clean up any existing processes
    echo "🧹 Cleaning up existing processes..."
    pkill -f "vite" 2>/dev/null || true
    pkill -f "nest start" 2>/dev/null || true
    pkill -f "ts-node-dev" 2>/dev/null || true
    sleep 1
    
    # Start infrastructure
    echo ""
    echo "🐳 Starting Docker infrastructure..."
    just _up-infra-oidc
    
    # Wait for infrastructure
    echo ""
    echo "⏳ Waiting for infrastructure to be ready..."
    for i in {1..30}; do
        if docker compose -f deploy/docker-compose.infra.yml ps 2>/dev/null | grep -q "healthy"; then
            echo "   ✅ Infrastructure is healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "   ⚠️  Timeout waiting for infrastructure (continuing anyway)"
        fi
        sleep 1
    done
    
    # Configure MinIO thumbnails
    echo ""
    echo "🖼️  Configuring MinIO thumbnails public access..."
    just _configure-minio-thumbnails
    
    # Generate frontend env
    echo ""
    echo "📝 Generating frontend env-config.js..."
    just _generate-frontend-env
    
    # Run migrations
    echo ""
    echo "🗄️  Running database migrations..."
    cd backend && npx prisma migrate deploy 2>&1 | sed 's/^/   /' || echo "   ⚠️  Migration warning (may be OK if already applied)"
    cd ..
    
    # Start services
    echo ""
    echo "🚀 Starting native services..."
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  Service      │  Port   │  URL                             │"
    echo "├─────────────────────────────────────────────────────────────┤"
    echo "│  Frontend     │  3000   │  http://localhost:3000           │"
    echo "│  Backend      │  8080   │  http://localhost:8080           │"
    echo "│  Room         │  3002   │  http://localhost:3002           │"
    echo "│  Traefik      │  443    │  https://draw.local              │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    echo "📌 Access the app at: https://draw.local"
    echo ""
    echo "Press Ctrl+C to stop all services"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Start all services in background
    just _dev-frontend &
    FRONTEND_PID=$!
    just _dev-backend &
    BACKEND_PID=$!
    just _dev-room &
    ROOM_PID=$!
    
    # Trap Ctrl+C
    trap 'echo ""; echo "🛑 Stopping services..."; kill $FRONTEND_PID $BACKEND_PID $ROOM_PID 2>/dev/null; just _down-infra; echo "✅ All services stopped."; exit 0' INT TERM
    
    wait

# Stop all development services
dev-stop:
    #!/usr/bin/env bash
    echo "🛑 Stopping AstraDraw development environment..."
    echo ""
    
    echo "Stopping native services..."
    if pgrep -f "vite" > /dev/null 2>&1; then
        pkill -f "vite" && echo "   ✅ Frontend stopped"
    else
        echo "   ⚪ Frontend was not running"
    fi
    
    if pgrep -f "nest start" > /dev/null 2>&1; then
        pkill -f "nest start" && echo "   ✅ Backend stopped"
    else
        echo "   ⚪ Backend was not running"
    fi
    
    if pgrep -f "ts-node-dev" > /dev/null 2>&1; then
        pkill -f "ts-node-dev" && echo "   ✅ Room service stopped"
    else
        echo "   ⚪ Room service was not running"
    fi
    
    echo ""
    echo "Stopping Docker infrastructure..."
    just _down-infra
    
    echo ""
    echo "✅ All services stopped."

# Restart backend service only (useful after schema/module changes)
dev-restart-backend:
    #!/usr/bin/env bash
    echo "🔄 Restarting backend service..."
    if pgrep -f "nest start" > /dev/null 2>&1; then
        pkill -f "nest start"
        echo "   ✅ Backend stopped"
    fi
    sleep 1
    echo "   🚀 Starting backend..."
    cd backend && npm run start:dev 2>&1 | sed 's/^/[backend] /' &
    sleep 3
    if curl -s http://localhost:8080/api/v2/auth/status > /dev/null 2>&1; then
        echo "   ✅ Backend restarted successfully"
    else
        echo "   🟡 Backend starting... (may take a few seconds)"
    fi

# Restart frontend service only
dev-restart-frontend:
    #!/usr/bin/env bash
    echo "🔄 Restarting frontend service..."
    if pgrep -f "vite" > /dev/null 2>&1; then
        pkill -f "vite"
        echo "   ✅ Frontend stopped"
    fi
    sleep 1
    echo "   🚀 Starting frontend..."
    cd frontend && yarn start 2>&1 | sed 's/^/[frontend] /' &
    sleep 3
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        echo "   ✅ Frontend restarted successfully"
    else
        echo "   🟡 Frontend starting... (may take a few seconds)"
    fi

# Restart room service only
dev-restart-room:
    #!/usr/bin/env bash
    echo "🔄 Restarting room service..."
    if pgrep -f "ts-node-dev" > /dev/null 2>&1; then
        pkill -f "ts-node-dev"
        echo "   ✅ Room service stopped"
    fi
    sleep 1
    echo "   🚀 Starting room service..."
    cd room-service && yarn start:dev 2>&1 | sed 's/^/[room] /' &
    sleep 3
    if curl -s http://localhost:3002 > /dev/null 2>&1; then
        echo "   ✅ Room service restarted successfully"
    else
        echo "   🟡 Room service starting... (may take a few seconds)"
    fi

# Check status of all services
dev-status:
    #!/usr/bin/env bash
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           AstraDraw Service Status                         ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    echo "🐳 Docker Infrastructure:"
    echo "─────────────────────────"
    docker ps --filter "name=deploy" --format "table {{ "{{" }}.Names{{ "}}" }}\t{{ "{{" }}.Status{{ "}}" }}" 2>/dev/null | tail -n +2 | sed 's/^/   /' || echo "   No containers running"
    
    echo ""
    echo "💻 Native Services:"
    echo "───────────────────"
    
    if pgrep -f "vite" > /dev/null 2>&1; then
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            echo "   ✅ Frontend: running on http://localhost:3000"
        else
            echo "   🟡 Frontend: process running, port not responding"
        fi
    else
        echo "   ❌ Frontend: not running"
    fi
    
    if pgrep -f "nest start" > /dev/null 2>&1; then
        if curl -s http://localhost:8080/api/v2/auth/status > /dev/null 2>&1; then
            echo "   ✅ Backend: running on http://localhost:8080"
        else
            echo "   🟡 Backend: process running, port not responding"
        fi
    else
        echo "   ❌ Backend: not running"
    fi
    
    if pgrep -f "ts-node-dev" > /dev/null 2>&1; then
        if curl -s http://localhost:3002 > /dev/null 2>&1; then
            echo "   ✅ Room: running on http://localhost:3002"
        else
            echo "   🟡 Room: process running, port not responding"
        fi
    else
        echo "   ❌ Room: not running"
    fi
    
    echo ""
    echo "🌐 Traefik Routing:"
    echo "───────────────────"
    if curl -sk https://draw.local > /dev/null 2>&1; then
        echo "   ✅ https://draw.local is accessible"
    else
        echo "   ❌ https://draw.local is not accessible"
    fi

# =============================================================================
# CODE QUALITY (run before commits)
# =============================================================================

# Run all checks (frontend + backend + room)
check: check-frontend check-backend check-room

# Run frontend checks (TypeScript + Prettier + ESLint)
check-frontend:
    cd frontend && yarn test:typecheck && yarn test:other && yarn test:code

# Run backend checks (Build + Prettier + ESLint)
check-backend:
    cd backend && npm run build && npm run format && npm run lint

# Run room service checks
check-room:
    cd room-service && yarn build && yarn test

# Fix all formatting issues
fix:
    cd frontend && yarn fix
    cd backend && npm run format
    cd room-service && yarn fix

# =============================================================================
# DOCKER DEPLOYMENT
# =============================================================================
# Use these when you want to run everything in Docker containers.
# For daily development, use `just dev` instead (hot-reload, no Docker rebuilds).

# Start with production images (from GHCR)
up:
    cd deploy && docker compose up -d

# Start with local builds (builds from ../frontend, ../backend)
up-local:
    cd deploy && docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build

# Start with OIDC testing (Dex)
up-oidc:
    cd deploy && docker compose --profile oidc up -d

# Start with admin tools (pgAdmin, MinIO Console)
up-admin:
    cd deploy && docker compose --profile admin up -d

# Stop all Docker containers
down:
    cd deploy && docker compose --profile oidc --profile admin down

# View logs (all services)
logs:
    cd deploy && docker compose logs -f

# View API logs only
logs-api:
    cd deploy && docker compose logs -f api

# View frontend logs only
logs-app:
    cd deploy && docker compose logs -f app

# Restart all services
restart:
    cd deploy && docker compose restart

# Fresh start with production images (removes all data)
fresh:
    cd deploy && docker compose --profile oidc --profile admin down -v
    docker volume rm astradraw_postgres_data astradraw_minio_data 2>/dev/null || true
    cd deploy && docker compose up -d

# Fresh start with local builds (removes all data)
fresh-local:
    cd deploy && docker compose --profile oidc --profile admin down -v
    docker volume rm astradraw_postgres_data astradraw_minio_data 2>/dev/null || true
    cd deploy && docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build

# Build local images without starting
build:
    cd deploy && docker compose -f docker-compose.yml -f docker-compose.local.yml build

# Build without cache (use when changes aren't being picked up)
build-no-cache:
    cd deploy && docker compose -f docker-compose.yml -f docker-compose.local.yml build --no-cache

# Pull latest production images
pull:
    cd deploy && docker compose pull

# Clean up Docker resources (old images, build cache, etc.)
clean:
    #!/usr/bin/env bash
    set -e
    echo "🧹 Cleaning up Docker resources..."
    echo ""
    
    # Remove dangling images (untagged)
    echo "Removing dangling images..."
    docker image prune -f
    
    # Remove unused build cache
    echo ""
    echo "Removing build cache..."
    docker builder prune -f
    
    echo ""
    echo "✅ Cleanup complete!"
    echo ""
    echo "📊 Current disk usage:"
    docker system df

# Deep clean - removes ALL unused data (images, containers, volumes, networks)
clean-all:
    #!/usr/bin/env bash
    set -e
    echo "🧹 Deep cleaning Docker resources..."
    echo "⚠️  This will remove ALL unused images, containers, volumes, and networks!"
    echo ""
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker system prune -a --volumes -f
        echo ""
        echo "✅ Deep cleanup complete!"
    else
        echo "Cancelled."
    fi

# =============================================================================
# DATABASE
# =============================================================================

# Run Prisma migrations
db-migrate:
    cd backend && npx prisma migrate deploy

# Generate Prisma client
db-generate:
    cd backend && npx prisma generate

# Open Prisma Studio (database GUI)
db-studio:
    cd backend && npx prisma studio

# Reset database (development only!)
db-reset:
    cd backend && npx prisma migrate reset

# Seed database with test data (users, workspaces, teams, collections, scenes)
db-seed:
    cd backend && npx prisma db seed

# Fresh development start with seed data (reset + seed + dev)
dev-fresh:
    #!/usr/bin/env bash
    set -e
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           AstraDraw Fresh Development Start                ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Stop any running services
    echo "🛑 Stopping existing services..."
    just dev-stop 2>/dev/null || true
    
    # Start infrastructure (needed for database)
    echo ""
    echo "🐳 Starting infrastructure..."
    just _up-infra-oidc
    
    # Wait for database
    echo ""
    echo "⏳ Waiting for database..."
    for i in {1..30}; do
        if docker exec deploy-postgres-1 pg_isready -U excalidraw > /dev/null 2>&1; then
            echo "   ✅ Database is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "   ❌ Timeout waiting for database"
            exit 1
        fi
        sleep 1
    done
    
    # Reset and seed database
    echo ""
    echo "🗄️  Resetting database..."
    cd backend && npx prisma migrate reset --force --skip-seed
    
    echo ""
    echo "🌱 Seeding database with test data..."
    cd backend && npx prisma db seed
    
    echo ""
    echo "✅ Fresh database ready! Starting dev environment..."
    echo ""
    
    # Continue with normal dev startup
    cd .. && just dev

# =============================================================================
# GIT
# =============================================================================

# Show git status for all repos
status:
    @echo "=== Main Repo ===" && git status -s
    @echo "\n=== Frontend ===" && cd frontend && git status -s
    @echo "\n=== Backend ===" && cd backend && git status -s
    @echo "\n=== Room Service ===" && cd room-service && git status -s

# Pull latest from all repos
pull-all:
    git pull origin main
    cd frontend && git pull origin main
    cd backend && git pull origin main
    cd room-service && git pull origin main

# =============================================================================
# SETUP (one-time)
# =============================================================================

# Initial setup for new developers
setup:
    #!/usr/bin/env bash
    set -e
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           AstraDraw Development Setup                      ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Step 1: Check /etc/hosts
    echo "📋 Step 1: Checking /etc/hosts..."
    if grep -q "draw.local" /etc/hosts 2>/dev/null; then
        echo "   ✅ draw.local is in /etc/hosts"
    else
        echo "   ⚠️  draw.local is NOT in /etc/hosts"
        echo ""
        echo "   Please add it with:"
        echo "   sudo sh -c 'echo \"127.0.0.1 draw.local\" >> /etc/hosts'"
        echo ""
        read -p "   Press Enter after adding, or Ctrl+C to abort..."
    fi
    echo ""
    
    # Step 2: Clone repos
    echo "📋 Step 2: Cloning repositories..."
    test -d frontend || (echo "   Cloning frontend..." && git clone git@github.com:astrateam-net/astradraw-app.git frontend)
    test -d backend || (echo "   Cloning backend..." && git clone git@github.com:astrateam-net/astradraw-api.git backend)
    test -d room-service || (echo "   Cloning room service..." && git clone git@github.com:astrateam-net/astradraw-room.git room-service)
    echo "   ✅ Repositories ready"
    echo ""
    
    # Step 3: Environment file
    echo "📋 Step 3: Setting up environment..."
    test -f deploy/.env || cp deploy/env.example deploy/.env
    echo "   ✅ deploy/.env ready"
    echo ""
    
    # Step 4: Secrets
    echo "📋 Step 4: Generating secrets..."
    mkdir -p deploy/secrets
    test -f deploy/secrets/minio_access_key || echo "minioadmin" > deploy/secrets/minio_access_key
    test -f deploy/secrets/minio_secret_key || openssl rand -base64 32 > deploy/secrets/minio_secret_key
    echo "   ✅ Secrets ready"
    echo ""
    
    # Step 5: SSL Certificate
    echo "📋 Step 5: Generating SSL certificate..."
    if [ ! -f deploy/certs/server.crt ]; then
        just setup-certs
    else
        echo "   ✅ Certificate already exists"
    fi
    echo ""
    
    # Step 6: Install dependencies
    echo "📋 Step 6: Installing dependencies..."
    just install
    echo ""
    
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    Setup Complete! 🎉                      ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  To start development:                                     ║"
    echo "║    just dev                                                ║"
    echo "║                                                            ║"
    echo "║  Then open: https://draw.local                             ║"
    echo "╚════════════════════════════════════════════════════════════╝"

# Generate self-signed SSL certificate for draw.local
setup-certs:
    #!/usr/bin/env bash
    set -e
    echo "🔐 Generating SSL certificate for draw.local..."
    mkdir -p deploy/certs
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout deploy/certs/server.key \
        -out deploy/certs/server.crt \
        -subj "/CN=draw.local" \
        -addext "subjectAltName=DNS:draw.local,DNS:localhost,IP:127.0.0.1"
    
    echo "✅ Certificate generated at deploy/certs/"
    echo ""
    echo "📝 Note: Your browser will show a security warning."
    echo "   Click 'Advanced' → 'Proceed to draw.local' to accept it."

# Install all dependencies
install:
    cd frontend && yarn install
    cd backend && npm install
    cd room-service && yarn install

# =============================================================================
# TESTING
# =============================================================================

# Run backend API tests (requires running services)
test-api url="https://draw.local":
    chmod +x deploy/tests/test-backend-api.sh
    deploy/tests/test-backend-api.sh {{url}}

# Run interactive scene navigation test
test-navigation:
    @cd deploy/tests && node test-scene-navigation.js

# Setup test data for collaboration testing
test-setup-collab url="https://draw.local":
    chmod +x deploy/tests/setup-collab-test.sh
    deploy/tests/setup-collab-test.sh {{url}}

# =============================================================================
# GIT PUSH COMMANDS
# =============================================================================

# Push all repositories (main, frontend, backend, room-service)
push-all:
    #!/usr/bin/env bash
    echo "🚀 Pushing all repositories..."
    echo ""
    echo "=== Main Repo ===" && git push && echo ""
    echo "=== Frontend ===" && cd frontend && git push && cd .. && echo ""
    echo "=== Backend ===" && cd backend && git push && cd .. && echo ""
    echo "=== Room Service ===" && cd room-service && git push && cd .. && echo ""
    echo "✅ All repositories pushed!"

# Push main repository only
push-main:
    git push

# Push frontend repository only
push-frontend:
    cd frontend && git push

# Push backend repository only
push-backend:
    cd backend && git push

# Push room-service repository only
push-room:
    cd room-service && git push

# =============================================================================
# RELEASE (use with caution)
# =============================================================================

# Tag and push frontend release
release-frontend version:
    cd frontend && git tag v{{version}} && git push origin main --tags

# Tag and push backend release
release-backend version:
    cd backend && git tag v{{version}} && git push origin main --tags

# Tag and push room service release
release-room version:
    cd room-service && git tag v{{version}} && git push origin main --tags

# =============================================================================
# INTERNAL HELPERS (prefixed with _ to hide from list)
# =============================================================================

# Start frontend dev server
_dev-frontend:
    cd frontend && yarn start 2>&1 | sed 's/^/[frontend] /'

# Start backend dev server
_dev-backend:
    cd backend && npm run start:dev 2>&1 | sed 's/^/[backend] /'

# Start room service dev server
_dev-room:
    cd room-service && yarn start:dev 2>&1 | sed 's/^/[room] /'

# Start infrastructure only
_up-infra:
    cd deploy && docker compose -f docker-compose.infra.yml up -d

# Start infrastructure with OIDC
_up-infra-oidc:
    cd deploy && docker compose -f docker-compose.infra.yml --profile oidc up -d

# Stop infrastructure
_down-infra:
    cd deploy && docker compose -f docker-compose.infra.yml --profile oidc --profile admin down

# Generate frontend env-config.js
_generate-frontend-env:
    ./deploy/generate-frontend-env.sh

# Configure MinIO thumbnails for public access
_configure-minio-thumbnails:
    ./deploy/configure-minio-thumbnails.sh
