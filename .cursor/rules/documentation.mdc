---
description: "Keep documentation relevant and fresh - document changes, track issues, update after testing"
alwaysApply: true
---

# Documentation Standards

Documentation must stay in sync with the codebase. Follow these rules to keep docs relevant and fresh.

## When to Update Documentation

### 1. New Feature Implementation

When implementing a new feature:

1. **Create documentation** in `/docs/` folder with:
   - Feature overview
   - How it works
   - API endpoints (if any)
   - Frontend components (if any)
   - Configuration/environment variables
   - Known issues (if any)

2. **Add to feature table** in `README.md`

3. **Update `ARCHITECTURE.md`** if the feature affects system architecture

### 2. Modifying Existing Features

When changing existing functionality:

1. **Update the relevant doc** in `/docs/`
2. **Add a "Last Updated" section** at the bottom:

```markdown
---

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-20 | Fixed duplicate API prefix bug in users routes |
| 2025-12-15 | Added avatar upload functionality |
| 2025-12-10 | Initial implementation |
```

### 3. Bug Fixes

When fixing bugs that affect documented behavior:
- Update the doc to reflect the fix
- Remove any "Known Issues" entries that were resolved

## Documentation Format

### Feature Documentation Template

```markdown
# Feature Name

Brief description of what the feature does.

## Overview

More detailed explanation.

## How It Works

Technical explanation of the implementation.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v2/...` | Description |
| POST | `/api/v2/...` | Description |

## Frontend Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `ComponentName` | `frontend/excalidraw-app/...` | Description |

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `VAR_NAME` | Description | `value` |

## Known Issues

> ⚠️ **Issue**: Description of the problem
> 
> **Workaround**: How to work around it (if any)
> 
> **Status**: Investigating / Will fix in next release / Low priority

## Changelog

| Date | Changes |
|------|---------|
| YYYY-MM-DD | Description of changes |
```

## When NOT to Update Documentation

**Do NOT update docs until:**

1. ✅ Code changes are committed
2. ✅ `just check-all` passes
3. ✅ Docker deployment tested (`just up-dev` or `just fresh`)
4. ✅ User confirms feature works in real environment

**Ask the user**: "The feature is implemented. Should I update the documentation now, or do you want to test it first?"

## Known Issues Section

Use this format for documenting incomplete or problematic features:

```markdown
## Known Issues

### Issue: Users API has duplicate prefix

> ⚠️ **Problem**: The users routes are mapped to `/api/v2/api/v2/users/me` instead of `/api/v2/users/me`
> 
> **Impact**: User profile features may not work correctly
> 
> **Cause**: Duplicate `@Controller` prefix in `users.controller.ts`
> 
> **Status**: 🔴 Needs fix
> 
> **Added**: 2025-12-20

### Issue: Example resolved issue

> ✅ **Resolved** (2025-12-20)
> 
> **Was**: Description of what was wrong
> 
> **Fix**: What was done to fix it
```

### Issue Status Labels

| Status | Meaning |
|--------|---------|
| 🔴 Needs fix | Critical, blocks functionality |
| 🟡 Low priority | Works but not ideal |
| 🟢 Investigating | Looking into it |
| ✅ Resolved | Fixed, kept for history |

## Cursor Rules Updates

**Only update `.cursor/rules/` when:**

1. A pattern is confirmed to work after testing
2. A common issue is discovered and solved
3. A new workflow is established and verified

**Do NOT add to rules:**
- Speculative patterns
- Untested workarounds
- One-time fixes

## AI Workflow

### After Implementing a Feature

```
1. Implement the feature
2. Run `just check-all`
3. Test with `just up-dev` or `just fresh`
4. Ask user: "Please test [feature]. Let me know if it works."
5. IF user confirms it works:
   - Update/create documentation
   - Add changelog entry with today's date
   - Update README if needed
6. IF user reports issues:
   - Fix the issues first
   - Add to "Known Issues" if can't fix now
   - Document workarounds
```

### Updating Existing Documentation

```
1. Read the existing doc first
2. Make changes to reflect new behavior
3. Add changelog entry at the bottom
4. If removing a "Known Issue", mark it as ✅ Resolved
```

## Example: Documenting a Bug Discovery

When you discover a bug during implementation:

```markdown
## Known Issues

### Issue: Duplicate API prefix in users routes

> ⚠️ **Problem**: Routes are mapped to `/api/v2/api/v2/users/me`
> 
> **Impact**: User profile API calls fail with 404
> 
> **Cause**: `UsersController` has `@Controller('api/v2/users')` but global prefix is already `/api/v2`
> 
> **Fix needed**: Change to `@Controller('users')`
> 
> **Status**: 🔴 Needs fix
> 
> **Added**: 2025-12-20
```

Then tell the user about the bug and ask if they want to fix it now or later.

