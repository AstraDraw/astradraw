# Post-Implementation Checklist

You are helping update documentation and rules after a feature or refactoring is complete.

## Prerequisites

Before running this command:
- [ ] All code changes are committed
- [ ] `just check-all` passes
- [ ] Feature tested in browser at `https://draw.local`
- [ ] User confirms feature works

## Step 1: Update Feature Documentation

### For New Features
Create doc in appropriate category:
- `/docs/features/` - Feature documentation
- `/docs/guides/` - How-to guides  
- `/docs/architecture/` - System design changes

### For Bug Fixes / Refactoring
Update existing docs to reflect changes.

### For Tech Debt Items
Mark as resolved in `docs/planning/TECHNICAL_DEBT_AND_IMPROVEMENTS.md`:
```markdown
### X. ✅ RESOLVED: [Item Name]

> **Resolved:** YYYY-MM-DD - [Brief description]
```

## Step 2: Update Changelogs

Add entry to CHANGELOG.md in affected repos:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New feature description

### Fixed
- Bug fix description

### Changed
- Refactoring description
```

## Step 3: Consider Rule Updates

### Rule Hygiene Constraints

**BEFORE creating or modifying rules, check these constraints:**

1. **Keep always-applied rules minimal** - Only `ai-navigation.mdc` and `project-overview.mdc` should be `alwaysApply: true`

2. **Keep rules under ~120 lines** - If longer, split or trim

3. **Prefer globs over alwaysApply** - Use `globs: ["frontend/**/*.ts"]` to auto-apply only when relevant

4. **Prefer requestable rules** - Just add `description:` without `alwaysApply` or `globs` for rules that should be manually requested

5. **Avoid creating many new rules** - Reuse/merge existing rules when possible

6. **Current rule count:** ~15 rules is healthy; avoid going above 20

### When to Update Rules

**DO update rules when:**
- A pattern is confirmed to work after testing
- A common issue is discovered and solved
- A new workflow is established and verified

**DO NOT add to rules:**
- Speculative patterns
- Untested workarounds
- One-time fixes

### If Rule Update Needed

1. Check if existing rule covers the topic
2. If yes, update that rule (keep it concise)
3. If no, consider if it's truly needed for future AI sessions
4. Use `globs` to scope to relevant files
5. Keep the rule under ~120 lines

## Step 4: Verify Documentation Index

If you created a new doc, ensure it's listed in `/docs/README.md`.

## Step 5: Summary

Provide a summary of what was updated:

```
## Post-Implementation Summary

### Documentation Updated
- [List of docs created/modified]

### Rules Updated
- [List of rules modified, or "None"]

### Changelogs Updated
- [List of repos with changelog entries]
```
