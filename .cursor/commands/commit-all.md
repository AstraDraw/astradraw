# Commit All Repositories

Commit changes across all AstraDraw repositories (main, frontend, backend, room-service).

## Step 1: Check Status of All Repos

```bash
echo "=== Main Repo ===" && git -C /Volumes/storage/01_Projects/astradraw status --short
echo "=== Frontend ===" && git -C /Volumes/storage/01_Projects/astradraw/frontend status --short
echo "=== Backend ===" && git -C /Volumes/storage/01_Projects/astradraw/backend status --short
echo "=== Room Service ===" && git -C /Volumes/storage/01_Projects/astradraw/room-service status --short
```

## Step 2: Ask User for Commit Context

Ask the user:
1. What feature/fix was implemented?
2. Which repos have relevant changes?

## Step 3: Generate Commit Messages

For each repo with changes, generate an appropriate commit message following conventional commits:

- `feat:` - New feature
- `fix:` - Bug fix
- `refactor:` - Code refactoring
- `docs:` - Documentation only
- `chore:` - Maintenance tasks
- `style:` - Formatting, no code change

## Step 4: Commit Each Repo

For each repo with changes:

### Main Repo (astradraw/)
Usually contains: docs, deploy configs, cursor rules, docker-compose
```bash
cd /Volumes/storage/01_Projects/astradraw && git add -A && git commit -m "MESSAGE"
```

### Frontend (frontend/)
Contains: React app, components, hooks, styles
```bash
cd /Volumes/storage/01_Projects/astradraw/frontend && git add -A && git commit -m "MESSAGE"
```

### Backend (backend/)
Contains: NestJS API, Prisma schema, services
```bash
cd /Volumes/storage/01_Projects/astradraw/backend && git add -A && git commit -m "MESSAGE"
```

### Room Service (room-service/)
Contains: WebSocket server for collaboration
```bash
cd /Volumes/storage/01_Projects/astradraw/room-service && git add -A && git commit -m "MESSAGE"
```

## Step 5: Summary

After committing, show:
```
## Commits Created

| Repo | Commit | Message |
|------|--------|---------|
| main | abc123 | docs: update tech debt documentation |
| frontend | def456 | refactor: split WorkspaceSidebar |
| backend | - | No changes |
| room-service | - | No changes |
```

## Notes

- Each repo is a **separate git repository**
- Commits should be atomic and focused
- Use consistent commit message style across repos
- Always run `just check` before committing

