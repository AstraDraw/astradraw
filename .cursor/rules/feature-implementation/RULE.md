---
description: "Guidelines for implementing new features in AstraDraw"
alwaysApply: false
---

# Feature Implementation Guidelines

## Before Starting

1. **Read existing documentation** in `/docs` folder
2. **Check existing patterns** in similar features
3. **Plan the full stack** - frontend, backend, database changes

## Implementation Checklist

### Backend Changes

- [ ] Update Prisma schema if needed (`backend/prisma/schema.prisma`)
- [ ] Create/update service (`backend/src/<feature>/<feature>.service.ts`)
- [ ] Create/update controller (`backend/src/<feature>/<feature>.controller.ts`)
- [ ] Register in module (`backend/src/<feature>/<feature>.module.ts`)
- [ ] Import module in `app.module.ts` if new
- [ ] Add JWT guard for protected endpoints
- [ ] Run `npm run build` to verify

### Frontend Changes

- [ ] Create component(s) in `frontend/excalidraw-app/components/<Feature>/`
- [ ] Add SCSS styles with dark mode support
- [ ] Add translation keys to `en.json` and `ru-RU.json`
- [ ] Add API functions to `auth/workspaceApi.ts`
- [ ] Export from component index
- [ ] Integrate into App.tsx or AppSidebar.tsx
- [ ] Run `yarn tsc --noEmit` and `yarn prettier --write`

### Documentation

- [ ] Create/update doc in `/docs/<FEATURE>.md`
- [ ] Update CHANGELOG.md in both repos
- [ ] Update README if major feature

## API Endpoint Patterns

### RESTful Naming

```
GET    /api/v2/workspace/scenes           # List
POST   /api/v2/workspace/scenes           # Create
GET    /api/v2/workspace/scenes/:id       # Get one
PUT    /api/v2/workspace/scenes/:id       # Update
DELETE /api/v2/workspace/scenes/:id       # Delete
```

### Nested Resources

```
GET    /api/v2/workspace/scenes/:sceneId/talktracks
POST   /api/v2/workspace/scenes/:sceneId/talktracks
DELETE /api/v2/workspace/scenes/:sceneId/talktracks/:id
```

### User-Specific Endpoints

```
GET    /api/v2/users/me                   # Current user profile
PUT    /api/v2/users/me                   # Update profile
POST   /api/v2/users/me/avatar            # Upload avatar
```

## Component Patterns

### Dialog Component

```typescript
interface MyDialogProps {
  isOpen: boolean;
  onClose: () => void;
}

export const MyDialog: React.FC<MyDialogProps> = ({ isOpen, onClose }) => {
  if (!isOpen) return null;

  return (
    <div className="my-dialog__overlay" onClick={onClose}>
      <div className="my-dialog" onClick={(e) => e.stopPropagation()}>
        {/* Content */}
      </div>
    </div>
  );
};
```

### Sidebar Panel

```typescript
// Add to AppSidebar.tsx
<Sidebar.Tab name="myfeature">
  <Sidebar.TabTrigger name="myfeature" icon={myIcon}>
    {t("myfeature.title")}
  </Sidebar.TabTrigger>
</Sidebar.Tab>

<Sidebar.TabContent name="myfeature">
  <MyFeaturePanel excalidrawAPI={excalidrawAPI} />
</Sidebar.TabContent>
```

## State Management

### When to Use What

| State Type | Use Case |
|------------|----------|
| `useState` | Component-local state |
| `useRef` | Values that don't trigger re-render |
| Jotai atom | Shared state across components |
| Context | Auth state, theme |

### Jotai Pattern

```typescript
// atoms.ts
export const myFeatureAtom = atom<boolean>(false);

// Component
import { useAtom } from "jotai";
const [value, setValue] = useAtom(myFeatureAtom);
```

## Testing New Features

1. **Local build test:**
   ```bash
   cd frontend && yarn tsc --noEmit
   cd backend && npm run build
   ```

2. **Docker test:**
   ```bash
   docker compose up -d --build
   ```

3. **Browser test:**
   - Test in both light and dark mode
   - Test with and without authentication
   - Test keyboard shortcuts don't interfere

## Release Process

1. Update CHANGELOGs
2. Commit and push to respective repos
3. Tag new versions
4. Update `docker-compose.yml` with new image versions
5. Push main repo changes

