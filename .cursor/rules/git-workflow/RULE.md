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

### Step 3: Run Checks & Build

**NEVER push to main without passing all checks!**

**Use `just` commands** (preferred - simpler for AI and user):

```bash
# Run all checks
just check-all

# Or individually:
just check-frontend    # TypeScript + Prettier + ESLint
just check-backend     # Build + Prettier + ESLint  
just check-room        # Build + Prettier + ESLint

# Fix formatting issues
just fix-all
```

#### Alternative: Manual Commands

##### Frontend Checks

```bash
cd frontend

# 1. TypeScript type checking (REQUIRED)
yarn test:typecheck

# 2. Prettier formatting check
yarn test:other
# Or auto-fix: yarn fix:other

# 3. ESLint code quality
yarn test:code
# Or auto-fix: yarn fix:code

# 4. Run all checks at once
yarn test:all

# 5. Unit tests (if applicable)
yarn test:app --watch=false
```

#### Backend Checks

```bash
cd backend

# 1. Build (includes TypeScript compilation) (REQUIRED)
npm run build

# 2. Prettier formatting
npm run format

# 3. ESLint code quality
npm run lint

# 4. Unit tests (if applicable)
npm run test
```

#### Room Service Checks (if modified)

```bash
cd room-service

# 1. TypeScript build (REQUIRED)
yarn build

# 2. All checks (prettier + eslint)
yarn test
# Or auto-fix: yarn fix
```

### Step 4: Test with Docker

After all checks pass, test the full deployment:

```bash
cd deploy
docker compose up -d --build

# Test in browser:
# - Test the new feature
# - Test existing features still work
# - Test in both light and dark mode
# - Test with and without authentication
```

### Step 5: Merge to Main

Only after all checks pass and Docker testing succeeds:

```bash
cd frontend
git checkout main
git merge feature/user-profile
# Resolve conflicts if any

cd ../backend
git checkout main
git merge feature/user-profile
```

### Step 6: Update Changelogs

Add entry to CHANGELOG.md in each affected repo:

```markdown
## [0.5.3] - 2024-12-21

### Added
- User profile management with avatar upload

### Fixed
- Input field keyboard event propagation
```

### Step 7: Tag Releases

```bash
cd frontend
git tag v0.18.0-beta0.36
git push origin main --tags

cd ../backend
git tag v0.5.3
git push origin main --tags
```

### Step 8: Update Docker Compose

Update `deploy/docker-compose.yml` with new image versions:

```yaml
app:
  image: ghcr.io/astrateam-net/astradraw-app:0.18.0-beta0.36
api:
  image: ghcr.io/astrateam-net/astradraw-api:0.5.3
```

### Step 9: Commit Main Repo

```bash
cd /path/to/astradraw
git add deploy/docker-compose.yml
git commit -m "chore: update images to frontend v0.18.0-beta0.36, backend v0.5.3"
git push origin main
```

## Workflow Checklist

Before pushing to main, verify:

- [ ] Feature branches created in all affected repos
- [ ] **Frontend checks passed** (if modified):
  - [ ] `yarn test:typecheck` - TypeScript
  - [ ] `yarn test:other` - Prettier
  - [ ] `yarn test:code` - ESLint
- [ ] **Backend checks passed** (if modified):
  - [ ] `npm run build` - Build/TypeScript
  - [ ] `npm run format` - Prettier
  - [ ] `npm run lint` - ESLint
- [ ] **Room service checks passed** (if modified):
  - [ ] `yarn build` - TypeScript
  - [ ] `yarn test` - Prettier + ESLint
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

### Before Implementation

Remind user to create feature branches:
```
⚠️ **Workflow Check**: Before we start, should I help create feature branches in the affected repos?
```

### After Implementation

Before any release actions, run checks:
```
✅ **Pre-Release Checklist**: Let's verify everything before releasing:

**Frontend** (if modified):
\`\`\`bash
cd frontend && yarn test:typecheck && yarn test:other && yarn test:code
\`\`\`

**Backend** (if modified):
\`\`\`bash
cd backend && npm run build && npm run format && npm run lint
\`\`\`

**Docker test**:
\`\`\`bash
cd deploy && docker compose up -d --build
\`\`\`

Run these and let me know the results. Only after all pass will we update changelogs and create tags.
```

### When User Tries to Skip

If user asks to push/release without testing:
```
⚠️ **Hold on!** We should run checks first:
- TypeScript compilation
- Prettier formatting
- ESLint code quality
- Docker deployment test

Want me to list the commands to run?
```

