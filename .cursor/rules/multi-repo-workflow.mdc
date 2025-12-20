---
description: "How AI should handle features that span multiple repositories (frontend, backend, room-service)"
alwaysApply: true
---

# Multi-Repo Workflow for AI

This project has code in multiple folders that work together. When implementing features, follow this workflow.

## Project Structure

```
astradraw/           # You are here (main workspace)
├── frontend/        # React/Excalidraw app (UI, components)
├── backend/         # NestJS API (auth, database, storage)
├── room-service/    # WebSocket server (collaboration)
└── docs/            # Feature documentation
```

## When User Requests a Feature

### Step 1: Understand Scope

Before coding, determine what's needed:

| If feature involves... | Check these locations |
|------------------------|----------------------|
| UI/components | `frontend/excalidraw-app/components/` |
| API endpoints | `backend/src/` |
| Database changes | `backend/prisma/schema.prisma` |
| Real-time collab | `room-service/src/` |
| Existing patterns | `docs/` folder first |

### Step 2: Read Documentation First

**Always check `/docs` before implementing.** Look for:
- Similar features already documented
- Established patterns to follow
- Known issues and solutions

### Step 3: Propose Before Implementing

For features that need changes in multiple repos, propose a plan:

```
I'll need to make changes in:

**Backend:**
- Add endpoint X
- Update schema Y

**Frontend:**
- Create component Z
- Add to sidebar

Should I proceed with this plan?
```

### Step 4: Implement in Order

1. **Database schema** (if needed) - `backend/prisma/schema.prisma`
2. **Backend API** - controllers, services
3. **Frontend API client** - `frontend/excalidraw-app/auth/workspaceApi.ts`
4. **Frontend UI** - components, styles
5. **Translations** - both `en.json` and `ru-RU.json`

## Cross-Repo Patterns

### API Integration Pattern

```typescript
// Backend: backend/src/feature/feature.controller.ts
@Get('api/v2/feature')
@UseGuards(JwtAuthGuard)
async getFeature() { ... }

// Frontend: frontend/excalidraw-app/auth/workspaceApi.ts
export async function getFeature() {
  const response = await fetch(`${getApiBaseUrl()}/feature`, {
    credentials: "include",
  });
  return response.json();
}

// Frontend: Use in component
import { getFeature } from "../../auth/workspaceApi";
```

### When Backend Doesn't Support Something

If user asks for a feature and backend doesn't have the API:

1. Tell the user: "This needs a new backend endpoint. I'll implement both."
2. Create the backend endpoint first
3. Then create the frontend that uses it

## What NOT to Do

- ❌ Don't implement frontend that calls non-existent API
- ❌ Don't skip reading docs for "simple" features
- ❌ Don't make changes without understanding existing patterns
- ❌ Don't forget translations in both locale files

## Quick Checks Before Implementing

- [ ] Read relevant doc in `/docs` if exists
- [ ] Check if similar feature exists (reuse patterns)
- [ ] Verify backend has required endpoints
- [ ] Plan database changes if needed
- [ ] Consider both light and dark mode for UI

