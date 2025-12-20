# Collaboration Profile Integration

This document explains how authenticated user profiles are integrated with the real-time collaboration feature in AstraDraw.

## Overview

When users collaborate on a shared canvas, their identity is displayed to other participants. This feature ensures that:

- **Authenticated users** appear with their profile name and avatar (instead of random names)
- **Anonymous users** continue to use randomly generated names
- Profile data is transmitted securely via encrypted WebSocket messages

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (React)                         │
│                                                                 │
│  ┌──────────────────┐    ┌──────────────────┐                  │
│  │   AuthContext    │───►│   authUserAtom   │                  │
│  │  (User Profile)  │    │   (Jotai Store)  │                  │
│  └──────────────────┘    └────────┬─────────┘                  │
│                                   │                             │
│                                   ▼                             │
│  ┌──────────────────┐    ┌──────────────────┐                  │
│  │      Collab      │◄───│   appJotaiStore  │                  │
│  │ (Class Component)│    │   .get(atom)     │                  │
│  └────────┬─────────┘    └──────────────────┘                  │
│           │                                                     │
│           ▼                                                     │
│  ┌──────────────────┐                                          │
│  │      Portal      │                                          │
│  │ (WebSocket Msgs) │                                          │
│  └────────┬─────────┘                                          │
└───────────│─────────────────────────────────────────────────────┘
            │ Encrypted WebSocket
            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Room Service (Node.js)                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Broadcasts encrypted payloads to all room participants   │  │
│  │ (does not decrypt - end-to-end encryption)               │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## How It Works

### 1. User Authentication

When a user signs in, their profile is stored in both:
- `AuthContext` state (React context)
- `authUserAtom` (Jotai atom for cross-component access)

```typescript
// AuthContext.tsx
useEffect(() => {
  appJotaiStore.set(authUserAtom, user);
}, [user]);
```

### 2. Starting Collaboration

When a user starts or joins a collaboration session, the `Collab` component:

1. Checks if there's an authenticated user via `authUserAtom`
2. Uses their profile name and avatar URL if available
3. Falls back to localStorage username or generates a random one

```typescript
// Collab.tsx - startCollaboration()
const authUser = appJotaiStore.get(authUserAtom);
if (authUser?.name) {
  this.setUsername(authUser.name);
}
if (authUser?.avatarUrl) {
  this.setAvatarUrl(authUser.avatarUrl);
}
```

### 3. Broadcasting Profile Data

The `Portal` component includes profile data in WebSocket messages:

**Mouse Location Updates:**
```typescript
{
  type: "MOUSE_LOCATION",
  payload: {
    socketId: "...",
    pointer: { x, y },
    button: "up" | "down",
    selectedElementIds: {...},
    username: "John Doe",        // From profile
    avatarUrl: "data:image/..."  // From profile (base64)
  }
}
```

**Idle Status Updates:**
```typescript
{
  type: "IDLE_STATUS",
  payload: {
    socketId: "...",
    userState: "active" | "idle" | "away",
    username: "John Doe",
    avatarUrl: "data:image/..."
  }
}
```

### 4. Receiving Collaborator Data

When messages are received from other collaborators:

1. Messages are decrypted (end-to-end encryption)
2. `username` and `avatarUrl` are extracted from the payload
3. Collaborator state is updated with this data
4. UI displays the collaborator's name and avatar

## Data Flow

```
User Signs In
     │
     ▼
AuthContext updates user state
     │
     ▼
authUserAtom synced via useEffect
     │
     ▼
User clicks "Live collaboration"
     │
     ▼
Collab.startCollaboration() reads authUserAtom
     │
     ├─► Has authenticated user?
     │        │
     │        ├─► Yes: Use profile name & avatar
     │        │
     │        └─► No: Use localStorage or random name
     │
     ▼
Portal broadcasts messages with username & avatarUrl
     │
     ▼
Other clients receive & display collaborator info
```

## UI Display

### Share Dialog

When starting collaboration, the username field shows:
- **Authenticated users**: Their profile display name
- **Anonymous users**: Random generated name (editable)

### Collaborator Avatars

The top-right corner shows connected collaborators:
- **With avatar**: Profile picture in a circle
- **Without avatar**: Colored circle with initials
- **Hover**: Shows username tooltip

## State Management

### Why Jotai Atom?

The `Collab` component is a **class component** (not a functional component), so it cannot use React hooks like `useAuth()`. To access the authenticated user:

1. `AuthProvider` (functional) syncs user to `authUserAtom`
2. `Collab` (class) reads via `appJotaiStore.get(authUserAtom)`

```typescript
// app-jotai.ts
export interface AuthUser {
  id: string;
  email: string;
  name: string | null;
  avatarUrl: string | null;
}

export const authUserAtom = atom<AuthUser | null>(null);
```

### Priority Order

When determining the username for collaboration:

1. **Authenticated user name** (highest priority)
2. **localStorage saved name** (from previous sessions)
3. **Random generated name** (fallback)

This ensures authenticated users always see their profile name, even if they previously used a random name.

## WebSocket Message Types

### Modified Types (`data/index.ts`)

```typescript
export type SocketUpdateDataSource = {
  MOUSE_LOCATION: {
    type: "MOUSE_LOCATION";
    payload: {
      socketId: SocketId;
      pointer: { x: number; y: number };
      button: "down" | "up";
      selectedElementIds: AppState["selectedElementIds"];
      username: string;
      avatarUrl?: string | null;  // NEW
    };
  };
  IDLE_STATUS: {
    type: "IDLE_STATUS";
    payload: {
      socketId: SocketId;
      userState: UserIdleState;
      username: string;
      avatarUrl?: string | null;  // NEW
    };
  };
  // ... other types unchanged
};
```

## Security Considerations

1. **End-to-End Encryption**
   - All WebSocket messages are encrypted
   - Room service cannot read profile data
   - Only room participants can decrypt

2. **Avatar Data**
   - Stored as base64 data URLs
   - Transmitted within encrypted payloads
   - No external image loading (prevents tracking)

3. **No Backend Changes**
   - Profile data flows through existing encrypted channels
   - Room service remains a simple relay

## Related Files

### Frontend (`frontend/`)

| File | Purpose |
|------|---------|
| `excalidraw-app/app-jotai.ts` | `authUserAtom` definition |
| `excalidraw-app/auth/AuthContext.tsx` | Syncs user to atom |
| `excalidraw-app/collab/Collab.tsx` | Reads atom, manages state |
| `excalidraw-app/collab/Portal.tsx` | Broadcasts profile in messages |
| `excalidraw-app/data/index.ts` | WebSocket message types |

### No Backend Changes Required

The collaboration profile feature is entirely frontend-based. Profile data is:
- Already stored in the database (see `USER_PROFILE.md`)
- Already available via `AuthContext`
- Transmitted through existing encrypted WebSocket channels

## Testing

### Manual Testing Checklist

1. **Authenticated User Starts Collaboration**
   - [ ] Username field shows profile name (not random)
   - [ ] Avatar appears in collaborator list (if set)

2. **Anonymous User Joins**
   - [ ] Random name is generated
   - [ ] Can edit username manually

3. **Multiple Authenticated Users**
   - [ ] Each sees their own profile name
   - [ ] Each sees others' profile names and avatars

4. **Profile Changes During Session**
   - [ ] Changing profile name updates collaboration display
   - [ ] Changing avatar updates collaborator view

5. **Mixed Authentication**
   - [ ] Authenticated and anonymous users can collaborate
   - [ ] Each displays appropriately

## Known Limitations

1. **Avatar Size**
   - Avatars are base64 encoded (can be large)
   - Transmitted with every position update
   - Consider caching optimization in future

2. **Real-time Profile Updates**
   - Profile changes during active collaboration require reconnection
   - Future: Could implement profile update broadcasts

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-21 | Initial implementation of collaboration profile integration |

