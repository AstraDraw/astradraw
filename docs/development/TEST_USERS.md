# Test Users & Development Scenarios

This document describes the test users and scenarios created by the seed script for development and testing.

## Quick Start

```bash
# Seed the database with test data
just db-seed

# Or do a fresh start (reset + seed + start dev)
just dev-fresh
```

## Test Users

All test users have the password: **`Test123!`**

| User | Email | Role in Acme Corp | Purpose |
|------|-------|-------------------|---------|
| Alice | `alice@test.local` | ADMIN | Workspace admin, full access |
| Bob | `bob@test.local` | MEMBER | EDIT access to Engineering |
| Carol | `carol@test.local` | MEMBER | EDIT access to Design |
| Dave | `dave@test.local` | VIEWER | Read-only access |
| Eve | `eve@test.local` | (not a member) | External user |

> **Note:** The super admin user (`admin@localhost` / `admin`) is created separately during app startup.

## Workspace Structure

### Acme Corp (Shared Workspace)

```
Acme Corp/
├── Engineering Docs 🔧 (public)
│   ├── API Architecture (by Alice)
│   └── Database Schema (by Bob)
├── Design Assets 🎨 (public)
│   ├── Brand Guidelines (by Alice)
│   └── Logo Concepts (by Carol)
├── Public Demos 📢 (public)
│   └── Product Demo (by Alice)
└── Alice's Private 🔒 (private)
    └── Secret Project (by Alice)
```

### Teams

| Team | Color | Members | Purpose |
|------|-------|---------|---------|
| Engineering | 🔵 #3B82F6 | Alice, Bob | Technical documentation |
| Design | 🩷 #EC4899 | Alice, Carol | Design assets |
| Viewers | ⬜ #6B7280 | Dave | Read-only access |

### Collection Access Matrix

| Collection | Engineering | Design | Viewers |
|------------|-------------|--------|---------|
| Engineering Docs | **EDIT** | VIEW | VIEW |
| Design Assets | VIEW | **EDIT** | VIEW |
| Public Demos | VIEW | VIEW | VIEW |
| Alice's Private | - | - | - |

## Permission Test Scenarios

### Scenario 1: Workspace Admin (Alice)

**Login:** `alice@test.local` / `Test123!`

**Expected behavior:**
- ✅ Can see all collections including "Alice's Private"
- ✅ Can edit all scenes
- ✅ Can create/delete collections
- ✅ Can manage teams and members
- ✅ Can invite new users
- ✅ Can see all comment threads

### Scenario 2: Member with EDIT Access (Bob)

**Login:** `bob@test.local` / `Test123!`

**Expected behavior:**
- ✅ Can see Engineering Docs, Design Assets, Public Demos
- ✅ Can **EDIT** scenes in Engineering Docs
- ✅ Can **VIEW** scenes in Design Assets (no edit)
- ❌ Cannot see "Alice's Private" collection
- ✅ Can add comments on scenes they can view
- ✅ Has 1 unread notification (mentioned by Alice)

### Scenario 3: Member with VIEW Access (Carol)

**Login:** `carol@test.local` / `Test123!`

**Expected behavior:**
- ✅ Can see Engineering Docs, Design Assets, Public Demos
- ✅ Can **VIEW** scenes in Engineering Docs (no edit)
- ✅ Can **EDIT** scenes in Design Assets
- ❌ Cannot see "Alice's Private" collection
- ✅ Can add comments on scenes they can view
- ✅ Has 2 unread notifications (mentioned by Alice and Bob)

### Scenario 4: Workspace Viewer (Dave)

**Login:** `dave@test.local` / `Test123!`

**Expected behavior:**
- ✅ Can see Engineering Docs, Design Assets, Public Demos
- ✅ Can **VIEW** all scenes (no edit anywhere)
- ❌ Cannot see "Alice's Private" collection
- ❌ Cannot add comments (VIEWER role)
- ❌ Cannot create scenes or collections

### Scenario 5: External User (Eve)

**Login:** `eve@test.local` / `Test123!`

**Expected behavior:**
- ❌ Cannot see Acme Corp workspace
- ✅ Can only see her own Personal workspace
- ✅ Can create scenes in her Personal workspace

## Notification Testing

After seeding, the following notifications exist:

| User | Count | Type | From | Scene |
|------|-------|------|------|-------|
| Bob | 1 | MENTION | Alice | API Architecture |
| Carol | 2 | MENTION | Bob, Alice | API Architecture, Brand Guidelines |

### Testing Notifications

1. Login as **Bob** → Should see notification badge with "1"
2. Click notification → Should navigate to "API Architecture" scene
3. Login as **Carol** → Should see notification badge with "2"

## Comment Testing

Scenes with existing comment threads:

| Scene | Threads | Comments |
|-------|---------|----------|
| API Architecture | 2 | Alice→Bob, Bob→Carol |
| Brand Guidelines | 1 | Alice→Carol |

### Testing Comments

1. Login as **Alice**, open "API Architecture"
2. Should see 2 comment markers on the canvas
3. Click marker → Should show thread with mentions

## API Testing with curl

```bash
# Login as Alice
curl -X POST "https://draw.local/api/v2/auth/login/local" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice@test.local","password":"Test123!"}' \
  -k -c /tmp/cookies.txt -s | jq .

# Check workspaces
curl "https://draw.local/api/v2/workspaces" \
  -k -b /tmp/cookies.txt -s | jq .

# Check notifications (login as Bob first)
curl "https://draw.local/api/v2/notifications/unread-count" \
  -k -b /tmp/cookies.txt -s | jq .
```

## Database Queries

```bash
# List all users
docker exec deploy-postgres-1 psql -U excalidraw -d excalidraw \
  -c "SELECT id, email, name FROM users;"

# Check workspace memberships
docker exec deploy-postgres-1 psql -U excalidraw -d excalidraw \
  -c "SELECT u.name, wm.role, w.name as workspace 
      FROM workspace_members wm 
      JOIN users u ON wm.\"userId\" = u.id 
      JOIN workspaces w ON wm.\"workspaceId\" = w.id;"

# Check notifications
docker exec deploy-postgres-1 psql -U excalidraw -d excalidraw \
  -c "SELECT n.type, u.name as recipient, a.name as actor, n.read 
      FROM notifications n 
      JOIN users u ON n.\"userId\" = u.id 
      JOIN users a ON n.\"actorId\" = a.id;"
```

## Resetting Test Data

```bash
# Reset and re-seed
just db-reset    # Prompts for confirmation
just db-seed

# Or fresh start (reset + seed + start dev)
just dev-fresh
```

## Related Documentation

- [Collaboration System](../features/COLLABORATION.md) - Permission model details
- [Roles & Teams](../guides/ROLES_TEAMS_COLLECTIONS.md) - Role hierarchy
- [Development Guide](../getting-started/DEVELOPMENT.md) - Setup instructions

