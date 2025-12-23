# Finish Technical Debt Item

You are helping finalize a technical debt item after implementation is complete.

## Step 1: Run Checks

Verify all checks pass:
```bash
just check
```

If checks fail, fix the issues before proceeding.

## Step 2: Verify Tech Debt Document Updated

Confirm the item is marked as resolved in `docs/planning/TECHNICAL_DEBT_AND_IMPROVEMENTS.md`:

```markdown
### X. ✅ RESOLVED: [Item Name]

> **Resolved:** YYYY-MM-DD - [Brief description]

**Was:** [Original problem]

**Fix:** [What was implemented]
```

Also verify:
- Phase checklist updated (e.g., "5. ✅ Add error boundaries (done 2025-12-23)")
- Changelog table at bottom has new entry

## Step 3: Update Frontend Changelog

Add entry to `frontend/CHANGELOG.md` with new version:

```markdown
## [0.18.0-betaX.XX] - YYYY-MM-DD

### Added/Changed/Fixed
- **[Item Name]** - Brief description of what was added
  - Key feature 1
  - Key feature 2
```

## Step 4: Summary

Provide brief summary:

```
## Tech Debt Item Complete

**Item:** [Name]
**Status:** ✅ Resolved
**Files Created:** X new files
**Files Modified:** Y files
**Checks:** Passing
```

## Notes

- No rule updates needed for standard refactoring
- No new documentation files needed (tech debt doc is sufficient)
- Keep changelog entries concise

