# Workspace UI Styling Guide

This document describes the CSS architecture for the AstraDraw workspace UI, including the sidebar, dashboard, settings pages, and dark mode implementation.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Theme System](#theme-system)
3. [CSS Variable Reference](#css-variable-reference)
4. [Component Styling Patterns](#component-styling-patterns)
5. [Dark Mode Implementation](#dark-mode-implementation)
6. [Common Issues & Solutions](#common-issues--solutions)

---

## Architecture Overview

### DOM Structure

The AstraDraw app has a specific DOM structure that affects how CSS selectors work:

```
.excalidraw-app                      ← Parent container (theme class added here)
├── .workspace-sidebar               ← Outside .excalidraw container
├── .excalidraw-app__dashboard       ← Outside .excalidraw container
│   └── Various settings pages
└── .excalidraw-app__canvas
    └── .excalidraw.theme--dark      ← Excalidraw's own theme class
```

**Key Insight:** The workspace sidebar and dashboard are **siblings** to the Excalidraw canvas, not children. This means they don't inherit styles from `.excalidraw.theme--dark`.

### CSS Hide/Show Pattern

Both dashboard and canvas are **always mounted** in the DOM. Visibility is controlled via CSS `display: none`:

```tsx
// In App.tsx - both are always rendered
<div style={{ display: appMode === "dashboard" ? "block" : "none" }}>
  <WorkspaceMainContent />
</div>
<div style={{ display: appMode === "canvas" ? "block" : "none" }}>
  <Excalidraw />
</div>
```

This prevents Excalidraw from losing state when switching modes. See `/docs/CRITICAL_CSS_HIDE_SHOW_FIX.md` for details.

---

## Theme System

### How Theme Switching Works

1. **State Management:** Theme is managed in `useHandleAppTheme.ts`
   - `appTheme`: User preference (`"light"`, `"dark"`, or `"system"`)
   - `editorTheme`: Resolved theme after handling system preference

2. **Theme Class Application:** The `theme--dark` class is applied to:
   - `.excalidraw-app` container (for workspace UI)
   - `.excalidraw` container (handled by Excalidraw internally)

3. **Keyboard Shortcut:** `⌥ + ⇧ + D` (Alt+Shift+D) toggles theme globally

4. **Persistence:** Theme preference is stored in localStorage

### Theme Class in App.tsx

```tsx
<div
  className={clsx("excalidraw-app", {
    "theme--dark": editorTheme === THEME.DARK,
    // ... other classes
  })}
>
```

---

## CSS Variable Reference

### Primary Colors

| Variable | Light Mode | Dark Mode | Usage |
|----------|------------|-----------|-------|
| `--text-primary-color` | `#1b1b1f` | `#e1e1e1` | Main text, headings |
| `--text-secondary-color` | `#6b6b6b` | `#9b9b9b` | Secondary text, hints |
| `--island-bg-color` | `#ffffff` | `#232329` | Cards, dialogs, inputs |
| `--default-bg-color` | `#fafafa` | `#1e1e24` | Page backgrounds |
| `--default-border-color` | `#e5e5e5` | `#3d3d3d` | Borders, dividers |
| `--color-primary` | `#6965db` | `#6965db` | Primary actions |
| `--color-primary-light` | `#a5a1ff` | `#a5a1ff` | Primary accents in dark |
| `--icon-fill-color` | `#6b6b6b` | `#9b9b9b` | Icons |

### Button Hover States

| Variable | Light Mode | Dark Mode |
|----------|------------|-----------|
| `--button-hover-bg` | `rgba(0, 0, 0, 0.05)` | `rgba(255, 255, 255, 0.1)` |

### UI Font Stack

All workspace components define this locally since they're outside `.excalidraw`:

```scss
--ui-font: Assistant, system-ui, BlinkMacSystemFont, -apple-system, Segoe UI,
  Roboto, Helvetica, Arial, sans-serif;
```

---

## Component Styling Patterns

### Standard Component Structure

Every workspace component SCSS file follows this pattern:

```scss
.component-name {
  // 1. Define --ui-font locally (required for components outside .excalidraw)
  --ui-font: Assistant, system-ui, BlinkMacSystemFont, -apple-system, Segoe UI,
    Roboto, Helvetica, Arial, sans-serif;
  font-family: var(--ui-font);

  // 2. Base styles with light mode defaults
  background: var(--default-bg-color, #fafafa);
  color: var(--text-primary-color, #1b1b1f);

  // 3. Child element styles
  &__title {
    color: var(--text-primary-color, #1b1b1f);
  }

  &__subtitle {
    color: var(--text-secondary-color, #6b6b6b);
  }

  // ... more styles
}

// 4. Dark mode overrides (MUST include both selectors)
.excalidraw.theme--dark,
.excalidraw-app.theme--dark {
  .component-name {
    background: var(--default-bg-color, #1e1e24);

    &__title {
      color: var(--text-primary-color, #e1e1e1);
    }

    &__subtitle {
      color: var(--text-secondary-color, #9b9b9b);
    }
  }
}
```

### Why Two Selectors for Dark Mode?

```scss
.excalidraw.theme--dark,        // For components inside Excalidraw
.excalidraw-app.theme--dark {   // For workspace components outside Excalidraw
  // styles...
}
```

Components in the workspace (sidebar, dashboard, settings) are outside the `.excalidraw` container, so they need `.excalidraw-app.theme--dark` to match.

---

## Dark Mode Implementation

### Checklist for New Components

When creating a new workspace component, ensure dark mode support:

- [ ] Add `--ui-font` definition at root of component
- [ ] Use CSS variables with fallback values for all colors
- [ ] Add dark mode section with **both** selectors
- [ ] Override all text colors (`--text-primary-color`, `--text-secondary-color`)
- [ ] Override all background colors (`--island-bg-color`, `--default-bg-color`)
- [ ] Override all border colors (`--default-border-color`)
- [ ] Override input/select backgrounds and text colors
- [ ] Override placeholder colors
- [ ] Override hover states

### Elements That Need Dark Mode Overrides

| Element Type | Light Default | Dark Override |
|--------------|---------------|---------------|
| Page background | `#fafafa` | `#1e1e24` |
| Card/dialog background | `#ffffff` | `#232329` |
| Primary text | `#1b1b1f` | `#e1e1e1` |
| Secondary text | `#6b6b6b` | `#9b9b9b` |
| Borders | `#e5e5e5` | `#3d3d3d` |
| Input background | `#ffffff` | `#232329` or `#1e1e24` |
| Input text | `#1b1b1f` | `#e1e1e1` |
| Placeholder text | `#6b6b6b` | `#9b9b9b` |
| Select dropdown bg | `#ffffff` | `#232329` |
| Hover states | `rgba(0,0,0,0.05)` | `rgba(255,255,255,0.1)` |

### Input Fields Pattern

```scss
// Light mode (base styles)
&__input {
  background: var(--island-bg-color, #ffffff);
  border: 1px solid var(--default-border-color, #e5e5e5);
  color: var(--text-primary-color, #1b1b1f);

  &::placeholder {
    color: var(--text-secondary-color, #6b6b6b);
  }

  &:focus {
    border-color: var(--color-primary, #6965db);
  }
}

// Dark mode
.excalidraw-app.theme--dark {
  .component__input {
    background: var(--island-bg-color, #232329);
    border-color: var(--default-border-color, #3d3d3d);
    color: var(--text-primary-color, #e1e1e1);

    &::placeholder {
      color: var(--text-secondary-color, #9b9b9b);
    }
  }
}
```

### Select Dropdowns Pattern

```scss
// Light mode
&__select {
  background: var(--island-bg-color, #ffffff);
  border: 1px solid var(--default-border-color, #e5e5e5);
  color: var(--text-primary-color, #1b1b1f);
}

// Dark mode
.excalidraw-app.theme--dark {
  .component__select {
    background: var(--default-bg-color, #1e1e24);
    border-color: var(--default-border-color, #3d3d3d);
    color: var(--text-primary-color, #e1e1e1);

    option {
      background: var(--island-bg-color, #232329);
      color: var(--text-primary-color, #e1e1e1);
    }
  }
}
```

### Dialog Pattern

```scss
// Light mode
&__dialog {
  background: var(--island-bg-color, #ffffff);
  border-radius: 12px;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2);
}

&__dialog-header {
  border-bottom: 1px solid var(--default-border-color, #e5e5e5);

  h2 {
    color: var(--text-primary-color, #1b1b1f);
  }
}

// Dark mode
.excalidraw-app.theme--dark {
  .component__dialog {
    background: var(--island-bg-color, #232329);
  }

  .component__dialog-header {
    border-color: var(--default-border-color, #3d3d3d);

    h2 {
      color: var(--text-primary-color, #e1e1e1);
    }
  }
}
```

---

## Common Issues & Solutions

### Issue 1: Text Not Visible in Dark Mode

**Symptom:** Text appears as dark gray on dark background.

**Cause:** Missing dark mode override for text color.

**Solution:** Add explicit color override in dark mode section:
```scss
.excalidraw-app.theme--dark {
  .component__text {
    color: var(--text-primary-color, #e1e1e1);
  }
}
```

### Issue 2: Fonts Look Like Times New Roman

**Symptom:** Text appears in serif font instead of Assistant.

**Cause:** Component is outside `.excalidraw` container and doesn't inherit `--ui-font`.

**Solution:** Define `--ui-font` locally in component:
```scss
.my-component {
  --ui-font: Assistant, system-ui, BlinkMacSystemFont, -apple-system, Segoe UI,
    Roboto, Helvetica, Arial, sans-serif;
  font-family: var(--ui-font);
}
```

### Issue 3: Dark Mode Not Applying to Sidebar/Dashboard

**Symptom:** Canvas switches to dark mode but sidebar stays light.

**Cause:** Using only `.excalidraw.theme--dark` selector.

**Solution:** Add `.excalidraw-app.theme--dark` selector:
```scss
.excalidraw.theme--dark,
.excalidraw-app.theme--dark {
  // styles apply to both contexts
}
```

### Issue 4: Select Dropdown Options White in Dark Mode

**Symptom:** Dropdown opens with white background in dark mode.

**Cause:** Missing `option` styling in dark mode.

**Solution:**
```scss
.excalidraw-app.theme--dark {
  .component__select {
    background: var(--default-bg-color, #1e1e24);
    color: var(--text-primary-color, #e1e1e1);

    option {
      background: var(--island-bg-color, #232329);
      color: var(--text-primary-color, #e1e1e1);
    }
  }
}
```

### Issue 5: Input Placeholder Not Visible

**Symptom:** Placeholder text is too dark in dark mode.

**Cause:** Missing `::placeholder` override.

**Solution:**
```scss
.excalidraw-app.theme--dark {
  .component__input::placeholder {
    color: var(--text-secondary-color, #9b9b9b);
  }
}
```

---

## Files Reference

### Workspace Component SCSS Files

| File | Component |
|------|-----------|
| `WorkspaceSidebar.scss` | Left sidebar with collections |
| `DashboardView.scss` | Main dashboard home view |
| `CollectionView.scss` | Collection scenes grid |
| `SceneCard.scss` | Individual scene card |
| `SceneCardGrid.scss` | Grid of scene cards |
| `FullModeNav.scss` | Dashboard navigation menu |
| `BoardModeNav.scss` | Canvas mode navigation |
| `LoginDialog.scss` | Login modal |
| `UserProfileDialog.scss` | Profile dialog |
| `UserMenu.scss` | User dropdown menu |
| `WorkspaceSidebarTrigger.scss` | Sidebar toggle button |
| `CopyMoveDialog.scss` | Copy/move scene dialog |
| `InviteAcceptPage.scss` | Invite acceptance page |

### Settings Component SCSS Files

| File | Component |
|------|-----------|
| `ProfilePage.scss` | User profile settings |
| `WorkspaceSettingsPage.scss` | Workspace configuration |
| `MembersPage.scss` | Team members management |
| `TeamsCollectionsPage.scss` | Teams and collections admin |

### Other Component SCSS Files

| File | Component |
|------|-----------|
| `EmojiPicker.scss` | Emoji picker for icons |
| `SaveStatusIndicator.scss` | Auto-save status display |

---

## Related Documentation

- `/docs/CRITICAL_CSS_HIDE_SHOW_FIX.md` - CSS Hide/Show pattern for mode switching
- `/.cursor/rules/common-issues.mdc` - Issue #5 (fonts), #16 (CSS hide/show)
- `/.cursor/rules/frontend-patterns.mdc` - Frontend development patterns

