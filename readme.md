# Astradraw - Self-hosted Excalidraw with Collaboration

A fully self-hosted Excalidraw deployment with real-time collaboration support.

## Features

- **Real-time Collaboration**: Multiple users can draw together in the same canvas
- **Self-hosted Storage**: No Firebase dependency - uses HTTP storage backend with PostgreSQL/MongoDB/S3
- **Single Domain**: All services accessible via one domain with path-based routing
- **Traefik Integration**: Ready-to-use reverse proxy configuration with HTTPS
- **End-to-End Encryption**: All scene data encrypted client-side
- **Docker Secrets Support**: `_FILE` suffix pattern for production deployments

## Quick Start

```bash
# 1. Clone this repository
git clone <repo-url>
cd astradraw

# 2. Copy environment template
cp env.example .env

# 3. Edit .env with your configuration
nano .env

# 4. Generate self-signed certs for local testing (optional)
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/key.pem -out certs/cert.pem \
  -subj "/CN=localhost"

# 5. Build and start all services
docker compose up -d --build

# 6. Access Excalidraw at https://localhost (accept cert warning)
```

## Architecture

See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed technical documentation.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Traefik Proxy (HTTPS)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐   │
│  │ /            │  │ /socket.io/  │  │ /api/v2/                 │   │
│  │ Frontend     │  │ Room Server  │  │ Storage Backend          │   │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Repository Structure

| Folder | Description |
|--------|-------------|
| `excalidraw/` | Modified Excalidraw frontend with HTTP storage support |
| `excalidraw-room/` | WebSocket server for real-time collaboration (upstream) |
| `excalidraw-storage-backend/` | HTTP API for scene/file persistence with `_FILE` secrets |

## Configuration

### Environment Variables

Copy `env.example` to `.env` and configure:

| Variable | Description |
|----------|-------------|
| `APP_DOMAIN` | Your domain (e.g., `draw.example.com`) |
| `APP_PROTOCOL` | `http` or `https` |
| `POSTGRES_USER` | PostgreSQL username |
| `POSTGRES_PASSWORD` | PostgreSQL password |
| `POSTGRES_DB` | PostgreSQL database name |

### Docker Secrets Support (`_FILE` suffix)

All sensitive environment variables in `excalidraw-storage-backend` support reading values from files via the `_FILE` suffix. This is useful for Docker Swarm secrets or Kubernetes secrets.

**Supported variables:** `STORAGE_URI`, `PORT`, `LOG_LEVEL`, `GLOBAL_PREFIX`

```yaml
# Example: docker-compose.yml
services:
  storage:
    environment:
      - STORAGE_URI_FILE=/run/secrets/storage_uri
    volumes:
      - ./secrets:/run/secrets:ro
```

### Supported Databases

Via Keyv connection strings:
- **PostgreSQL**: `postgres://user:pass@host:5432/db` (recommended)
- **MongoDB**: `mongodb://user:pass@host:27017/db`
- **Redis**: `redis://user:pass@host:6379`
- **MySQL**: `mysql://user:pass@host:3306/db`

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) for all modifications made to upstream repos.

### Frontend Development

```bash
cd excalidraw
yarn install
yarn start
```

### Storage Backend Development

```bash
cd excalidraw-storage-backend
npm install
npm run start:dev
```

## Credits

- [Excalidraw](https://github.com/excalidraw/excalidraw) - The amazing whiteboard app
- [excalidraw-room](https://github.com/excalidraw/excalidraw-room) - Official collaboration server
- [alswl/excalidraw-collaboration](https://github.com/alswl/excalidraw-collaboration) - HTTP storage backend inspiration
- [alswl/excalidraw-storage-backend](https://github.com/alswl/excalidraw-storage-backend) - Storage backend implementation

## License

MIT
