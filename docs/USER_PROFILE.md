# User Profile Management

This document explains the user profile feature in AstraDraw, including architecture, implementation details, and integration with authentication systems.

## Overview

The user profile feature allows authenticated users to:
- View and edit their display name
- Upload and manage their profile picture (avatar)
- View their email address
- Sign out of the application

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (React)                         │
│  ┌──────────────────┐    ┌──────────────────┐                  │
│  │ UserProfileDialog │◄───│ WorkspaceSidebar │                  │
│  │   - Avatar upload │    │   - User menu    │                  │
│  │   - Name editing  │    │   - Profile link │                  │
│  │   - Sign out      │    └──────────────────┘                  │
│  └────────┬─────────┘                                           │
│           │                                                      │
│           ▼                                                      │
│  ┌──────────────────┐                                           │
│  │   workspaceApi   │                                           │
│  │ - getUserProfile │                                           │
│  │ - updateProfile  │                                           │
│  │ - uploadAvatar   │                                           │
│  │ - deleteAvatar   │                                           │
│  └────────┬─────────┘                                           │
└───────────│─────────────────────────────────────────────────────┘
            │ HTTP (JWT Cookie)
            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Backend (NestJS)                            │
│  ┌──────────────────┐    ┌──────────────────┐                  │
│  │ UsersController  │───►│  UsersService    │                  │
│  │ /api/v2/users/*  │    │ - updateProfile  │                  │
│  └──────────────────┘    │ - getProfile     │                  │
│           │              └────────┬─────────┘                  │
│           │                       │                             │
│           ▼                       ▼                             │
│  ┌──────────────────┐    ┌──────────────────┐                  │
│  │   JwtAuthGuard   │    │  PrismaService   │                  │
│  │ (Authentication) │    │   (Database)     │                  │
│  └──────────────────┘    └──────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     PostgreSQL Database                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ users table                                               │  │
│  │ - id (cuid)                                               │  │
│  │ - email (unique)                                          │  │
│  │ - name (nullable)                                         │  │
│  │ - avatarUrl (nullable, base64 data URL)                   │  │
│  │ - oidcId (nullable, for SSO users)                        │  │
│  │ - passwordHash (nullable, for local auth users)           │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## API Endpoints

### GET /api/v2/users/me

Get the current user's profile.

**Authentication:** Required (JWT cookie)

**Response:**
```json
{
  "id": "clxxxxxxxxxxxxxxxxx",
  "email": "user@example.com",
  "name": "John Doe",
  "avatarUrl": "data:image/jpeg;base64,/9j/4AAQ...",
  "createdAt": "2025-01-01T00:00:00.000Z",
  "updatedAt": "2025-01-15T12:30:00.000Z"
}
```

**Note:** The `passwordHash` field is never included in the response.

### PUT /api/v2/users/me

Update the current user's profile.

**Authentication:** Required (JWT cookie)

**Request Body:**
```json
{
  "name": "New Name"
}
```

**Response:** Updated user profile (same format as GET)

### POST /api/v2/users/me/avatar

Upload a new avatar image.

**Authentication:** Required (JWT cookie)

**Request:** `multipart/form-data` with `avatar` field

**Constraints:**
- Max file size: 2MB
- Allowed types: JPEG, PNG, GIF, WebP

**Response:** Updated user profile with new `avatarUrl`

### PUT /api/v2/users/me/avatar/delete

Remove the current avatar (reset to default).

**Authentication:** Required (JWT cookie)

**Response:** Updated user profile with `avatarUrl: null`

## Authentication Integration

### SSO (OIDC) Users

When a user authenticates via SSO (OIDC), their profile information is initially populated from the identity provider:

1. User clicks "Sign in with SSO"
2. Redirected to OIDC provider (e.g., Authentik, Dex)
3. After authentication, callback receives user claims
4. `UsersService.upsertFromOidc()` creates/updates user:
   - `oidcId` - OIDC subject ID
   - `email` - From OIDC claims
   - `name` - From OIDC claims (if available)
   - `avatarUrl` - From OIDC claims (if available)

After initial SSO login, users can update their name and avatar locally. These local changes persist and are not overwritten by subsequent SSO logins (only email is synced).

### Local Authentication Users

Users who register with email/password start with:
- `email` - From registration form
- `name` - From registration form (optional)
- `passwordHash` - bcrypt hash of password
- `oidcId` - null
- `avatarUrl` - null

They can then upload an avatar and update their name through the profile dialog.

### Hybrid Users

A user can be linked to both local auth and SSO:
- First registers locally (has `passwordHash`)
- Later signs in with SSO using same email (gets `oidcId`)
- Can sign in with either method

## Frontend Components

### UserProfileDialog

Location: `frontend/excalidraw-app/components/Workspace/UserProfileDialog.tsx`

A modal dialog that displays:
1. **Avatar Section**
   - Current avatar or initials placeholder
   - Click to upload new image
   - "Change Photo" and "Remove" buttons

2. **Name Section**
   - Display name with edit button
   - Inline editing with save/cancel

3. **Email Section**
   - Read-only email display

4. **Sign Out Button**
   - Logs out user and closes dialog

**Props:**
```typescript
interface UserProfileDialogProps {
  isOpen: boolean;
  onClose: () => void;
}
```

### Integration with WorkspaceSidebar

The profile dialog is accessed via the user menu in the workspace sidebar:

1. User clicks on their avatar/name in sidebar header
2. Dropdown menu appears with:
   - User email (info)
   - "My Profile" option
   - "Sign out" option
3. Clicking "My Profile" opens `UserProfileDialog`

## Avatar Storage

Avatars are stored as base64 data URLs directly in the database. This approach:

**Advantages:**
- Simple implementation
- No additional storage service needed
- Works with any database

**Limitations:**
- Increases database size
- 2MB file size limit
- Not ideal for large-scale deployments

**Future Enhancement:** For production deployments with many users, consider:
- Storing avatars in S3/MinIO
- Using signed URLs for access
- Implementing image resizing/optimization

## Localization

The profile feature supports internationalization:

**English (`en.json`):**
```json
{
  "workspace": {
    "myProfile": "My Profile",
    "profilePicture": "Profile Picture",
    "profileName": "Profile Name",
    "changePhoto": "Change Photo",
    "removePhoto": "Remove"
  }
}
```

**Russian (`ru-RU.json`):**
```json
{
  "workspace": {
    "myProfile": "Мой профиль",
    "profilePicture": "Фото профиля",
    "profileName": "Имя",
    "changePhoto": "Изменить фото",
    "removePhoto": "Удалить"
  }
}
```

## Security Considerations

1. **Authentication Required**
   - All profile endpoints require valid JWT
   - JWT stored in HTTP-only cookie

2. **User Isolation**
   - Users can only access/modify their own profile
   - User ID extracted from JWT, not from request

3. **Password Protection**
   - `passwordHash` never exposed in API responses
   - Separate endpoint for password changes (future)

4. **File Validation**
   - MIME type validation for uploads
   - File size limits enforced
   - Only image types accepted

## Error Handling

The frontend handles various error states:

- **Loading:** Shows spinner while fetching profile
- **Network Error:** Shows retry button
- **Upload Error:** Shows error message (e.g., "File too large")
- **Save Error:** Shows inline error message

## Dark Mode

The profile dialog fully supports dark mode through CSS variables:
- Background colors adapt to theme
- Text colors maintain readability
- Success/error messages use appropriate colors

## Testing

### Manual Testing Checklist

1. **View Profile**
   - [ ] Profile loads correctly after login
   - [ ] Avatar displays (or initials if none)
   - [ ] Name and email display correctly

2. **Edit Name**
   - [ ] Edit button opens input field
   - [ ] Save updates name
   - [ ] Cancel reverts changes
   - [ ] Empty name saves as null

3. **Avatar Upload**
   - [ ] Click avatar opens file picker
   - [ ] Valid image uploads successfully
   - [ ] Invalid file type shows error
   - [ ] Large file (>2MB) shows error

4. **Remove Avatar**
   - [ ] Remove button appears when avatar exists
   - [ ] Clicking removes avatar
   - [ ] Initials display after removal

5. **Sign Out**
   - [ ] Sign out button works
   - [ ] User redirected to login state

6. **Dark Mode**
   - [ ] Dialog renders correctly in dark mode
   - [ ] All text is readable
   - [ ] Colors are appropriate

## Related Files

### Backend (`backend/`)
- `src/users/users.controller.ts` - API endpoints
- `src/users/users.service.ts` - Business logic
- `src/users/users.module.ts` - Module definition
- `prisma/schema.prisma` - Database schema

### Frontend (`frontend/`)
- `excalidraw-app/components/Workspace/UserProfileDialog.tsx` - Dialog component
- `excalidraw-app/components/Workspace/UserProfileDialog.scss` - Styles
- `excalidraw-app/components/Workspace/WorkspaceSidebar.tsx` - Integration
- `excalidraw-app/auth/workspaceApi.ts` - API functions
- `packages/excalidraw/locales/*.json` - Translations

