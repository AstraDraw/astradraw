---
description: "Git branching and release workflow for feature development"
alwaysApply: true
---

# Git Workflow & Release Process

## Branch Strategy

**Always create feature branches before making changes.**

### Single-Repo Changes

When changes are only in one repo:

```bash
cd frontend  # or backend, room-service
git checkout -b feature/my-feature-name
# ... make changes ...
```

### Multi-Repo Changes (Full-Stack Features)

When a feature requires changes across multiple repos, create branches in ALL affected repos:

```bash
# Create matching branches in all affected repos
cd frontend
git checkout -b feature/user-profile

cd ../backend
git checkout -b feature/user-profile

cd ../room-service  # if needed
git checkout -b feature/user-profile
```

**Use the same branch name** across repos for clarity.

## Development Workflow

### Step 1: Create Branches

Before writing any code:

```bash
# Determine which repos need changes
# Create feature branches in each
```

### Step 2: Implement

1. Make changes following the multi-repo workflow
2. Commit frequently with clear messages
3. Keep branches in sync conceptually

### Step 3: Test Locally

**NEVER push to main without testing!**

```bash
# Build each repo
cd frontend && yarn tsc --noEmit
cd backend && npm run build

# Run local Docker deployment
cd deploy
docker compose up -d --build

# Test in browser
# - Test the new feature
# - Test existing features still work
# - Test in both light and dark mode
# - Test with and without authentication
```

### Step 4: Merge to Main

Only after successful testing:

```bash
cd frontend
git checkout main
git merge feature/user-profile
# Resolve conflicts if any

cd ../backend
git checkout main
git merge feature/user-profile
```

### Step 5: Update Changelogs

Add entry to CHANGELOG.md in each affected repo:

```markdown
## [0.5.3] - 2024-12-21

### Added
- User profile management with avatar upload

### Fixed
- Input field keyboard event propagation
```

### Step 6: Tag Releases

```bash
cd frontend
git tag v0.18.0-beta0.36
git push origin main --tags

cd ../backend
git tag v0.5.3
git push origin main --tags
```

### Step 7: Update Docker Compose

Update `deploy/docker-compose.yml` with new image versions:

```yaml
app:
  image: ghcr.io/astrateam-net/astradraw-app:0.18.0-beta0.36
api:
  image: ghcr.io/astrateam-net/astradraw-storage:0.5.3
```

### Step 8: Commit Main Repo

```bash
cd /path/to/astradraw
git add deploy/docker-compose.yml
git commit -m "chore: update images to frontend v0.18.0-beta0.36, backend v0.5.3"
git push origin main
```

## Workflow Checklist

Before pushing to main, verify:

- [ ] Feature branches created in all affected repos
- [ ] Code compiles without errors (`yarn tsc`, `npm run build`)
- [ ] Local Docker deployment works (`cd deploy && docker compose up -d --build`)
- [ ] Feature tested in browser
- [ ] Existing features still work
- [ ] Branches merged to main in each repo
- [ ] CHANGELOG.md updated in each repo
- [ ] Tags created and pushed
- [ ] `deploy/docker-compose.yml` updated with new versions
- [ ] Main repo committed and pushed

## Commit Message Format

```
type: short description

- Detail 1
- Detail 2
```

Types:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `refactor:` - Code refactoring
- `chore:` - Maintenance tasks

## When AI Should Remind About This

Remind user about this workflow when:
- Starting a new feature implementation
- About to make changes that affect multiple repos
- User asks to "push" or "release" without testing
- User asks to update changelog before testing

Example reminder:
```
⚠️ **Workflow Check**: Before we proceed, let's:
1. Create feature branches in the affected repos
2. After implementation, test with local Docker deployment
3. Only then update changelogs and push tags

Should I help create the branches first?
```

