# Continue Technical Debt Item

You are helping continue work on a technical debt item from `docs/planning/TECHNICAL_DEBT_AND_IMPROVEMENTS.md`.

## Step 1: Review the Tech Debt Document

Read the current state:
```
@docs/planning/TECHNICAL_DEBT_AND_IMPROVEMENTS.md
```

## Step 2: Select an Item

Ask the user which item to work on, or suggest based on priority:

**High Priority (Red):**
1. ✅ ~~WorkspaceSidebar.tsx is too large~~ (RESOLVED 2025-12-23)
2. App.tsx is massive (2,436 lines)
3. Inconsistent state management
4. ✅ ~~workspaceApi.ts is too large~~ (RESOLVED 2025-12-23)

**Medium Priority (Yellow):**
5. No data fetching library (React Query)
6. No optimistic updates
7. ✅ ~~Missing error boundaries~~ (RESOLVED 2025-12-23)

**Low Priority (Green):**
- Unit tests
- CSS modules
- Internationalization

## Step 3: Plan the Refactoring

For each item type:

### Splitting Large Files
1. Identify logical boundaries
2. Extract into separate files/hooks
3. Maintain backward compatibility (re-export from original location)
4. Update imports gradually

### Adding New Patterns (React Query, Error Boundaries)
1. Install dependencies if needed
2. Create utility/wrapper components
3. Apply to one component first as proof
4. Expand to other components

## Step 4: Implementation

1. **Ensure dev environment running:**
   ```bash
   just dev-status
   ```

2. **Make incremental changes** - commit frequently

3. **Run checks after each significant change:**
   ```bash
   just check
   ```

## Step 5: Finalize

After completing the implementation:

1. **Run all checks:**
   ```bash
   just check
   ```

2. **Mark as resolved** in `TECHNICAL_DEBT_AND_IMPROVEMENTS.md`:
   ```markdown
   ### X. ✅ RESOLVED: [Item Name]
   
   > **Resolved:** YYYY-MM-DD - [Brief description of fix]
   ```

3. **Update phase checklist** (e.g., "5. ✅ Add error boundaries (done 2025-12-23)")

4. **Add to changelog table** at bottom of tech debt document

5. **Update `frontend/CHANGELOG.md`** with new version entry:
   ```markdown
   ## [0.18.0-betaX.XX] - YYYY-MM-DD

   ### Added/Changed/Fixed
   - **[Item Name]** - Brief description of what was added
   ```

6. **Provide summary:**
   ```
   ## Tech Debt Item Complete

   **Item:** [Name]
   **Status:** ✅ Resolved
   **Files Created:** X new files
   **Files Modified:** Y files
   **Checks:** Passing
   ```

## Key Principles

- **Single Responsibility**: Each file/component does ONE thing
- **Colocate Related Code**: Keep related files together
- **DRY**: Extract common patterns into hooks
- **Fail Gracefully**: Error boundaries, toast notifications
