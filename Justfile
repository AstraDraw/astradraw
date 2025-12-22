# AstraDraw Development Commands
# Run `just` to see all available commands

# Default: show help
default:
    @just --list

# ============================================
# DOCKER DEPLOYMENT
# ============================================

# Start with production images (from GHCR)
up:
    @test ! -f deploy/docker-compose.override.yml || (echo "Warning: override file exists, using local builds. Run 'just up-prod' to force production images." && exit 1)
    cd deploy && docker compose up -d

# Start with production images (ignores override file)
up-prod:
    cd deploy && docker compose -f docker-compose.yml up -d

# Start with local builds (enables override file)
up-dev:
    @test -f deploy/docker-compose.override.yml || cp deploy/docker-compose.override.yml.disabled deploy/docker-compose.override.yml
    cd deploy && docker compose up -d --build

# Build local images without starting
build:
    @test -f deploy/docker-compose.override.yml || cp deploy/docker-compose.override.yml.disabled deploy/docker-compose.override.yml
    cd deploy && docker compose build

# Build local images without Docker cache (use when changes aren't being picked up)
build-no-cache:
    @test -f deploy/docker-compose.override.yml || cp deploy/docker-compose.override.yml.disabled deploy/docker-compose.override.yml
    cd deploy && docker compose build --no-cache

# Build and restart a specific service without cache
rebuild service:
    @test -f deploy/docker-compose.override.yml || cp deploy/docker-compose.override.yml.disabled deploy/docker-compose.override.yml
    cd deploy && docker compose build --no-cache {{service}}
    cd deploy && docker compose up -d {{service}}

# Stop all services (including OIDC/admin profiles)
down:
    cd deploy && docker compose --profile oidc --profile admin down

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

# Fresh start with production images (removes volumes)
fresh:
    cd deploy && docker compose --profile oidc --profile admin down -v
    docker volume rm astradraw_postgres_data astradraw_minio_data 2>/dev/null || true
    @test ! -f deploy/docker-compose.override.yml || rm deploy/docker-compose.override.yml
    cd deploy && docker compose up -d

# Fresh start with local builds (removes volumes)
fresh-dev:
    cd deploy && docker compose --profile oidc --profile admin down -v
    docker volume rm astradraw_postgres_data astradraw_minio_data 2>/dev/null || true
    @test -f deploy/docker-compose.override.yml || cp deploy/docker-compose.override.yml.disabled deploy/docker-compose.override.yml
    cd deploy && docker compose up -d --build

# Pull latest production images
pull:
    cd deploy && docker compose -f docker-compose.yml pull

# Pull third-party images only (traefik, postgres, minio, etc.) then build local app images
pull-and-build:
    @test -f deploy/docker-compose.override.yml || cp deploy/docker-compose.override.yml.disabled deploy/docker-compose.override.yml
    cd deploy && docker compose pull traefik postgres minio
    cd deploy && docker compose build

# Pull third-party images and start with local builds
up-dev-pull:
    @test -f deploy/docker-compose.override.yml || cp deploy/docker-compose.override.yml.disabled deploy/docker-compose.override.yml
    cd deploy && docker compose pull traefik postgres minio
    cd deploy && docker compose up -d --build

# Enable local builds (copy override file)
enable-dev:
    @test -f deploy/docker-compose.override.yml && echo "Already enabled" || cp deploy/docker-compose.override.yml.disabled deploy/docker-compose.override.yml
    @echo "Local builds enabled. Run 'just up-dev' to start."

# Disable local builds (remove override file)
disable-dev:
    @test -f deploy/docker-compose.override.yml && rm deploy/docker-compose.override.yml && echo "Local builds disabled" || echo "Already disabled"
    @echo "Production images enabled. Run 'just up' to start."

# Show current mode (production or development)
mode:
    @test -f deploy/docker-compose.override.yml && echo "Mode: DEVELOPMENT (local builds)" || echo "Mode: PRODUCTION (GHCR images)"

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

# Start frontend dev server (with prefix for logs)
dev-frontend:
    cd frontend && yarn start 2>&1 | sed 's/^/[frontend] /'

# Start backend dev server (with prefix for logs)
dev-backend:
    cd backend && npm run start:dev 2>&1 | sed 's/^/[backend] /'

# Start room service dev server (with prefix for logs)
dev-room:
    cd room-service && yarn start:dev 2>&1 | sed 's/^/[room] /'

# Install all dependencies
install:
    cd frontend && yarn install
    cd backend && npm install
    cd room-service && yarn install

# ============================================
# HYBRID DEVELOPMENT (Native + Docker Infra)
# ============================================
# Run frontend/backend/room natively with hot-reload while
# infrastructure (Postgres, MinIO, Traefik) runs in Docker.
# CSS/code changes apply instantly without Docker rebuilds!

# Start infrastructure only (Postgres, MinIO, Traefik)
up-infra:
    cd deploy && docker compose -f docker-compose.infra.yml up -d

# Stop infrastructure (including OIDC/admin profiles)
down-infra:
    cd deploy && docker compose -f docker-compose.infra.yml --profile oidc --profile admin down

# Fresh infrastructure start (removes volumes)
fresh-infra:
    cd deploy && docker compose -f docker-compose.infra.yml --profile oidc --profile admin down -v
    docker volume rm astradraw_postgres_data astradraw_minio_data 2>/dev/null || true
    cd deploy && docker compose -f docker-compose.infra.yml up -d

# View infrastructure logs
logs-infra:
    cd deploy && docker compose -f docker-compose.infra.yml logs -f

# Start infrastructure with OIDC (Dex)
up-infra-oidc:
    cd deploy && docker compose -f docker-compose.infra.yml --profile oidc up -d

# Start infrastructure with admin tools (pgAdmin)
up-infra-admin:
    cd deploy && docker compose -f docker-compose.infra.yml --profile admin up -d

# Start EVERYTHING for development (infra + all native services)
# Infra: Postgres, MinIO, Traefik, Dex (OIDC)
# Native: Frontend, Backend, Room
dev:
    #!/usr/bin/env bash
    set -e
    
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           AstraDraw Hybrid Development Mode                ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Step 0: Check if draw.local is in /etc/hosts
    if ! grep -q "draw.local" /etc/hosts 2>/dev/null; then
        echo "⚠️  WARNING: 'draw.local' is not in /etc/hosts!"
        echo ""
        echo "   Add it with:"
        echo "   sudo sh -c 'echo \"127.0.0.1 draw.local\" >> /etc/hosts'"
        echo ""
        echo "   Without this, https://draw.local will not work."
        echo ""
        read -p "   Press Enter to continue anyway, or Ctrl+C to abort..."
        echo ""
    fi
    
    # Step 1: Clean up any existing processes
    echo "🧹 Cleaning up existing processes..."
    pkill -f "vite" 2>/dev/null || true
    pkill -f "nest start" 2>/dev/null || true
    pkill -f "ts-node-dev" 2>/dev/null || true
    sleep 1
    
    # Step 2: Start infrastructure
    echo ""
    echo "🐳 Starting Docker infrastructure..."
    just up-infra-oidc
    
    # Step 3: Wait for infrastructure to be healthy
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
    
    # Step 4: Generate frontend env
    echo ""
    echo "📝 Generating frontend env-config.js..."
    just dev-env-frontend
    
    # Step 5: Run migrations
    echo ""
    echo "🗄️  Running database migrations..."
    cd backend && npx prisma migrate deploy 2>&1 | sed 's/^/   /' || echo "   ⚠️  Migration warning (may be OK if already applied)"
    cd ..
    
    # Step 6: Start services with proper logging
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
    
    # Start all services in background and wait
    just dev-frontend &
    FRONTEND_PID=$!
    just dev-backend &
    BACKEND_PID=$!
    just dev-room &
    ROOM_PID=$!
    
    # Trap Ctrl+C to clean up properly
    trap 'echo ""; echo "🛑 Stopping services..."; kill $FRONTEND_PID $BACKEND_PID $ROOM_PID 2>/dev/null; just down-infra; echo "✅ All services stopped."; exit 0' INT TERM
    
    # Wait for any process to exit
    wait

# Generate frontend env-config.js for native development
# Reads from deploy/.env and creates frontend/public/env-config.js
dev-env-frontend:
    #!/usr/bin/env bash
    set -e
    # Source deploy/.env if it exists
    if [ -f deploy/.env ]; then
        set -a
        source deploy/.env
        set +a
    fi
    # Set defaults
    APP_PROTOCOL="${APP_PROTOCOL:-https}"
    APP_DOMAIN="${APP_DOMAIN:-draw.local}"
    GIPHY_API_KEY="${GIPHY_API_KEY:-}"
    DEBUG_NAVIGATION="${DEBUG_NAVIGATION:-false}"
    # Generate env-config.js
    cat > frontend/public/env-config.js << ENVEOF
    // Runtime environment configuration - generated by 'just dev'
    // This file is gitignored and regenerated on each 'just dev' run
    window.__ENV__ = {
      VITE_APP_WS_SERVER_URL: "${APP_PROTOCOL}://${APP_DOMAIN}",
      VITE_APP_BACKEND_V2_GET_URL: "${APP_PROTOCOL}://${APP_DOMAIN}/api/v2/scenes/",
      VITE_APP_BACKEND_V2_POST_URL: "${APP_PROTOCOL}://${APP_DOMAIN}/api/v2/scenes/",
      VITE_APP_STORAGE_BACKEND: "http",
      VITE_APP_HTTP_STORAGE_BACKEND_URL: "${APP_PROTOCOL}://${APP_DOMAIN}/api/v2",
      VITE_APP_FIREBASE_CONFIG: "",
      VITE_APP_DISABLE_TRACKING: "true",
      VITE_APP_GIPHY_API_KEY: "${GIPHY_API_KEY}",
      VITE_DEBUG_NAVIGATION: "${DEBUG_NAVIGATION}"
    };
    ENVEOF
    echo "Created frontend/public/env-config.js"

# Stop all native services and infrastructure
dev-stop:
    #!/usr/bin/env bash
    echo "🛑 Stopping AstraDraw development environment..."
    echo ""
    
    # Stop native services
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
    just down-infra
    
    echo ""
    echo "✅ All services stopped."

# Check status of all dev services
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
    
    # Check Frontend (Vite)
    if pgrep -f "vite" > /dev/null 2>&1; then
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            echo "   ✅ Frontend: running on http://localhost:3000"
        else
            echo "   🟡 Frontend: process running, port not responding"
        fi
    else
        echo "   ❌ Frontend: not running"
    fi
    
    # Check Backend (NestJS)
    if pgrep -f "nest start" > /dev/null 2>&1; then
        if curl -s http://localhost:8080/api/v2/auth/status > /dev/null 2>&1; then
            echo "   ✅ Backend: running on http://localhost:8080"
        else
            echo "   🟡 Backend: process running, port not responding"
        fi
    else
        echo "   ❌ Backend: not running"
    fi
    
    # Check Room Service
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
    echo "🌐 Traefik Routing (https://draw.local):"
    echo "─────────────────────────────────────────"
    if curl -sk https://draw.local > /dev/null 2>&1; then
        echo "   ✅ https://draw.local is accessible"
    else
        echo "   ❌ https://draw.local is not accessible"
    fi

# Show hybrid dev instructions
dev-hybrid:
    @echo "=== Hybrid Development Mode ==="
    @echo ""
    @echo "Quick start (recommended):"
    @echo "   just dev              # Starts everything!"
    @echo ""
    @echo "Or manually:"
    @echo "   just up-infra         # Start Docker infrastructure"
    @echo "   just dev-frontend     # Frontend at :3000 (Vite HMR)"
    @echo "   just dev-backend      # Backend at :8080 (NestJS watch)"
    @echo "   just dev-room         # Room at :3002 (Socket.io)"
    @echo ""
    @echo "Access at: https://draw.local"
    @echo ""
    @echo "Stop everything:"
    @echo "   just dev-stop         # Stops native services + infrastructure"
    @echo ""
    @echo "CSS/React changes apply instantly. No Docker rebuild needed!"

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
# TESTING
# ============================================

# Run interactive scene navigation test
test-navigation:
    @cd deploy && node test-scene-navigation.js

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

# Pull latest from all repos (git pull)
git-pull:
    git pull origin main
    cd frontend && git pull origin main
    cd backend && git pull origin main
    cd room-service && git pull origin main

# ============================================
# API TESTING
# ============================================

# Run backend API tests (requires running services)
test-api url="https://10.100.0.10":
    chmod +x deploy/test-backend-api.sh
    deploy/test-backend-api.sh {{url}}

# Run API tests with custom super admin credentials
test-api-full url="https://10.100.0.10" admin_email="admin@localhost" admin_pass="admin":
    chmod +x deploy/test-backend-api.sh
    SUPERADMIN_EMAIL={{admin_email}} SUPERADMIN_PASSWORD={{admin_pass}} deploy/test-backend-api.sh {{url}}

# Setup test data for manual auto-collaboration testing (does NOT clean up)
setup-collab-test url="https://10.100.0.10":
    chmod +x deploy/setup-collab-test.sh
    deploy/setup-collab-test.sh {{url}}

# ============================================
# SETUP
# ============================================

# Generate self-signed SSL certificate for draw.local
generate-certs:
    #!/usr/bin/env bash
    set -e
    echo "🔐 Generating SSL certificate for draw.local..."
    mkdir -p deploy/certs
    
    # Generate certificate with Subject Alternative Names for both localhost and draw.local
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout deploy/certs/server.key \
        -out deploy/certs/server.crt \
        -subj "/CN=draw.local" \
        -addext "subjectAltName=DNS:draw.local,DNS:localhost,IP:127.0.0.1"
    
    echo "✅ Certificate generated at deploy/certs/"
    echo ""
    echo "📝 Note: Your browser will show a security warning."
    echo "   Click 'Advanced' → 'Proceed to draw.local' to accept it."

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
        just generate-certs
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
