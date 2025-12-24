# Continue Fork Architecture Refactoring

You are helping continue work on a fork architecture refactoring item from `docs/planning/FORK_ARCHITECTURE_REFACTORING_PLAN.md`.

## Step 1: Review the Refactoring Plan

Read the current state:
```
@docs/planning/FORK_ARCHITECTURE_REFACTORING_PLAN.md
```

## Step 2: Select an Item

Ask the user which item to work on, or suggest based on recommended order:

**Phase 1: Foundation (1 day)**
1. Reduce excalidrawAPI Prop Drilling - Export `useApp`, `useUIAppState` hooks

**Phase 2: Presentation Actions (1-2 days)**
2. Presentation Mode Actions - Create `actionPresentation.ts` in core

**Phase 3: Comment Markers (2-3 days)**
3. Native Comment Markers - Canvas rendering like collaborator cursors

## Step 3: Understand the Refactoring

For each item, the plan provides:
- **Current Implementation** - What exists now and where
- **Problem** - Why it should be refactored
- **Proposed Solution** - Code examples and approach
- **Files to Modify** - Exact files to change
- **Step-by-Step Implementation** - Detailed steps

## Step 4: Implementation

### For Prop Drilling (Item 1)

1. **Export hooks** from `packages/excalidraw/index.tsx`:
   ```typescript
   export { useApp, useAppProps } from "./components/App";
   export { useUIAppState } from "./context/ui-appState";
   ```

2. **Migrate components** in priority order:
   - Priority 1: `ThreadMarkersLayer.tsx`, `CommentsSidebar.tsx`, `NewThreadPopup.tsx`
   - Priority 2: `PenToolbar.tsx`, `StickersPanel.tsx`
   - Priority 3: `usePresentationMode.ts`, `Collab.tsx`

3. **Test each migration** before moving to next component

### For Presentation Actions (Item 2)

1. **Add types** to `packages/excalidraw/types.ts`:
   ```typescript
   export interface PresentationModeState {
     active: boolean;
     currentSlide: number;
     slides: string[];
   }
   ```

2. **Create** `packages/excalidraw/actions/actionPresentation.ts`

3. **Register actions** in `packages/excalidraw/actions/index.ts`

4. **Simplify** `excalidraw-app/components/Presentation/usePresentationMode.ts`

### For Comment Markers (Item 3)

1. **Add types** to `packages/excalidraw/scene/types.ts` and `types.ts`

2. **Add render function** to `packages/excalidraw/clients.ts`

3. **Call from render pipeline** in `packages/excalidraw/renderer/interactiveScene.ts`

4. **Simplify** `ThreadMarkersLayer` to data provider only

5. **Add click detection** in `packages/excalidraw/components/App.tsx`

## Step 5: Verify Changes

1. **Run checks:**
   ```bash
   just check
   ```

2. **Test manually:**
   - For prop drilling: Verify components still work after migration
   - For presentation: Test keyboard shortcuts (Arrow keys, Space, Escape)
   - For comments: Test pan/zoom performance, marker click selection

## Step 6: Finalize

After completing the implementation:

1. **Run all checks:**
   ```bash
   just check
   ```

2. **Update the refactoring plan** - Add completion date to changelog:
   ```markdown
   | 2025-XX-XX | Completed Phase 1: Export hooks from core |
   ```

3. **Update FORK_ARCHITECTURE.md** if new patterns were established

4. **Update TECHNICAL_DEBT_AND_IMPROVEMENTS.md** - Mark related items as resolved

5. **Update `frontend/CHANGELOG.md`** with new version entry:
   ```markdown
   ## [0.18.0-betaX.XX] - YYYY-MM-DD

   ### Changed
   - **Fork Architecture** - [Description of refactoring]
   ```

6. **Provide summary:**
   ```
   ## Fork Refactoring Item Complete

   **Item:** [Name]
   **Phase:** [1/2/3]
   **Status:** ✅ Completed
   **Files Created:** X new files
   **Files Modified:** Y files
   **Components Migrated:** Z components (for prop drilling)
   **Checks:** Passing
   ```

## Key Principles

- **Incremental Migration** - Don't refactor everything at once
- **Test After Each Change** - Verify functionality before moving on
- **Backward Compatibility** - Keep old patterns working during transition
- **Document Patterns** - Update FORK_ARCHITECTURE.md with new patterns

## Reference Files

| Pattern | Reference File |
|---------|----------------|
| Actions | `packages/excalidraw/actions/actionFrame.ts` |
| Canvas Rendering | `packages/excalidraw/clients.ts` (renderRemoteCursors) |
| Hooks Export | `packages/excalidraw/index.tsx` |
| AppState Types | `packages/excalidraw/types.ts` |

