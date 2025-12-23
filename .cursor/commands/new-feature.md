# New Feature Implementation

You are helping implement a new feature in AstraDraw.

## Step 1: Understand the Feature

Ask clarifying questions if needed:
- What should this feature do?
- Which parts of the system are affected? (frontend/backend/room-service)

## Step 2: Check Git Status (MANDATORY)

**Before ANY code changes, check git status in ALL potentially affected repos:**

```bash
cd frontend && git status
cd ../backend && git status
cd ../room-service && git status
```

**If there are uncommitted changes:**
```
⚠️ You have uncommitted changes in [repo]. 
Please commit or stash them before we create a feature branch:

```bash
git add . && git commit -m "wip: [description]"
# OR
git stash
```
```

**Only proceed after all repos are clean or changes are committed.**

## Step 3: Create Feature Branches (MANDATORY)

**Branch naming convention** - use descriptive kebab-case:
- `feature/user-profile-avatars` - for user profile feature
- `feature/scene-thumbnails` - for thumbnail generation
- `feature/team-permissions` - for team permission system
- `fix/jwt-cookie-refresh` - for bug fixes
- `refactor/storage-abstraction` - for refactoring

**Create branches in ALL affected repos with the SAME name:**

```bash
# Always create in frontend if UI changes
cd frontend && git checkout -b feature/<descriptive-name>

# Create in backend if API/database changes
cd ../backend && git checkout -b feature/<descriptive-name>

# Create in room-service if collaboration/websocket changes
cd ../room-service && git checkout -b feature/<descriptive-name>
```

**Confirm branches created:**
```bash
echo "Frontend:" && cd frontend && git branch --show-current
echo "Backend:" && cd ../backend && git branch --show-current
echo "Room:" && cd ../room-service && git branch --show-current
```

## Step 4: Plan the Implementation

Determine what's needed:
- [ ] Database schema changes? → `backend/prisma/schema.prisma`
- [ ] Backend API endpoints? → `backend/src/`
- [ ] Frontend components? → `frontend/excalidraw-app/components/`
- [ ] State management? → Request `@frontend-state`
- [ ] Collaboration changes? → `room-service/src/`

**Propose a plan before coding:**
```
I'll need to make changes in:

**Backend:**
- Add endpoint X
- Update schema Y

**Frontend:**
- Create component Z
- Add translations

**Room Service:** (if applicable)
- Update handler for X

Should I proceed?
```

## Step 5: Request Relevant Rules

Only request rules you need:
- `@frontend-patterns` - Frontend UI/components
- `@backend-patterns` - Backend API
- `@frontend-state` - Jotai state management
- `@collaboration-system` - Collaboration features

## Step 6: Implement in Order

1. **Database schema** (if needed) - run `npx prisma migrate dev`
2. **Backend API** - controllers, services, guards
3. **Frontend API client** - add to `auth/workspaceApi.ts`
4. **Frontend UI** - components, styles
5. **Translations** - add to `en.json` AND `ru-RU.json`

## Step 7: Ensure Dev Environment Running

```bash
just dev          # Start with hot-reload
just dev-status   # Verify everything is running
```

## Step 8: Run Checks

```bash
just check-all    # All checks (frontend + backend + room)
```

## Step 9: Test in Browser

- Test at `https://draw.local`
- Test in light AND dark mode
- Test with and without authentication
- Test keyboard shortcuts don't interfere

## Step 10: Commit Changes

Use conventional commit format: `type(scope): description`

```bash
# In each affected repo
git add .
git commit -m "feat(workspace): add scene auto-save

- Added debounced save on canvas changes
- Shows save indicator in toolbar"
```

**Types:** `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`

**Scopes (optional):** `workspace`, `auth`, `collab`, `ui`, `api`, `storage`

**Note:** Write detailed commit messages - they'll be summarized into CHANGELOG.md at release time.

## Key Patterns to Follow

- **Input fields**: Add `onKeyDown={(e) => e.stopPropagation()}`
- **API calls**: Always `credentials: "include"`
- **Dark mode**: Use both `.excalidraw.theme--dark, .excalidraw-app.theme--dark`
- **Loading states**: Use skeleton components from `components/Skeletons/`

## After Implementation

Run `/post-implementation` command to update docs and rules.

When ready to merge and release, use `@git-workflow` rule for release process.
