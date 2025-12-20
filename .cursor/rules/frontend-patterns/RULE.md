---
description: "Frontend development patterns for AstraDraw (React/Excalidraw)"
globs: ["frontend/**/*.ts", "frontend/**/*.tsx", "frontend/**/*.scss"]
alwaysApply: false
---

# Frontend Development Patterns

## Project Location

Frontend code is in `frontend/` (formerly `excalidraw/`). It's a fork of the upstream Excalidraw repository.

## Key Directories

```
frontend/
├── excalidraw-app/           # AstraDraw-specific code
│   ├── auth/                 # Authentication (AuthProvider, workspaceApi)
│   ├── components/           # Custom components
│   │   ├── Workspace/        # Sidebar, SceneCard, LoginDialog, UserProfile
│   │   ├── Talktrack/        # Recording feature
│   │   ├── Presentation/     # Slideshow mode
│   │   ├── Stickers/         # GIPHY integration
│   │   └── AppSidebar.tsx    # Main sidebar with tabs
│   ├── pens/                 # Custom pen presets
│   └── App.tsx               # Main app component
├── packages/excalidraw/      # Core Excalidraw library
│   ├── components/           # Core UI components
│   ├── locales/              # Translation files (en.json, ru-RU.json)
│   └── types.ts              # TypeScript types
```

## State Management

- **Jotai** for global state (atoms)
- **React useState/useEffect** for component state
- **ExcalidrawAPI** for canvas operations

```typescript
// Example: Using Jotai atoms
import { atom, useAtom } from "jotai";
const myAtom = atom<boolean>(false);
const [value, setValue] = useAtom(myAtom);

// Example: Using ExcalidrawAPI
excalidrawAPI.updateScene({ elements, appState });
excalidrawAPI.scrollToContent(element, { animate: true });
```

## Localization

**Always add translation keys** for new UI text:

1. Add to `packages/excalidraw/locales/en.json`
2. Add to `packages/excalidraw/locales/ru-RU.json`
3. Use `t("key.path")` in components

```typescript
import { t } from "@excalidraw/excalidraw/i18n";
<span>{t("workspace.myProfile")}</span>
```

## Input Fields in Dialogs

**Critical:** Stop keyboard event propagation in input fields to prevent canvas shortcuts:

```typescript
<input
  onKeyDown={(e) => e.stopPropagation()}
  onKeyUp={(e) => e.stopPropagation()}
  ...
/>
```

## Styling

- Use SCSS modules (`.scss` files alongside components)
- Support dark mode via CSS variables
- Use `var(--island-bg-color)`, `var(--text-primary-color)`, etc.

```scss
.my-component {
  background: var(--island-bg-color, #fff);
  color: var(--text-primary-color, #1b1b1f);
}

.excalidraw.theme--dark {
  .my-component {
    background: var(--island-bg-color, #232329);
  }
}
```

## API Calls

Use functions from `auth/workspaceApi.ts`:

```typescript
import { listScenes, createScene, getUserProfile } from "../../auth/workspaceApi";

// All API calls use credentials: "include" for JWT cookies
const scenes = await listScenes();
```

## Build & Check Commands

```bash
cd frontend
yarn install              # Install dependencies
yarn start                # Development server
yarn build:app:docker     # Production build for Docker

# Required checks before release:
yarn test:typecheck       # TypeScript type checking
yarn test:other           # Prettier formatting check
yarn test:code            # ESLint code quality
yarn test:all             # Run ALL checks + tests

# Auto-fix commands:
yarn fix:other            # Auto-fix Prettier
yarn fix:code             # Auto-fix ESLint
yarn fix                  # Fix both
```

