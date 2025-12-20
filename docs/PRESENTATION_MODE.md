# Presentation Mode Implementation

This document describes the implementation of the Presentation Mode feature in AstraDraw, inspired by the Obsidian Excalidraw plugin's slideshow functionality.

## Overview

Presentation Mode allows users to create presentations using Excalidraw frames as slides. Each frame becomes a slide that can be navigated through in fullscreen mode with smooth animations.

## Features

### Sidebar Panel (Presentation Tab)

- **Header**: "Presentation" with a "+ Create slide" button that activates the Frame tool
- **Slide List**: Scrollable list of slide thumbnails with frame names
- **Reordering**: ↑/↓ buttons on each slide card to change presentation order
- **Start Button**: "Start presentation" button at the bottom
- **Empty State**: When no frames exist, shows instructions: "Create presentations with AstraDraw"

### Presentation Mode Controls (Bottom Bar)

- **Navigation**: Left/Right arrow buttons
- **Slide Indicator**: "Slide X/Y" counter
- **Laser Pointer**: Toggle laser drawing tool (wand icon)
- **Dark Mode**: Toggle dark/light theme (moon/sun icon)
- **Fullscreen**: Toggle fullscreen mode
- **End Presentation**: Red button to exit presentation mode

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `→` / `↓` / `Space` | Next slide |
| `←` / `↑` | Previous slide |
| `Escape` | End presentation |
| `F` | Toggle fullscreen |
| `L` | Toggle laser pointer |

## Architecture

### File Structure

```
frontend/excalidraw-app/components/Presentation/
├── index.ts                    # Exports
├── usePresentationMode.ts      # Core logic hook (Jotai state)
├── PresentationPanel.tsx       # Sidebar panel component
├── PresentationPanel.scss      # Sidebar panel styles
├── PresentationMode.tsx        # Portal wrapper for controls
├── PresentationControls.tsx    # Bottom control bar component
└── PresentationControls.scss   # Control bar styles
```

### State Management (Jotai Atoms)

```typescript
// Core presentation state atoms
isPresentationModeAtom   // boolean - is presentation active
currentSlideAtom         // number - current slide index
slidesAtom               // ExcalidrawFrameLikeElement[] - ordered frames
isLaserActiveAtom        // boolean - laser tool state
originalThemeAtom        // Theme | null - theme before presentation
```

### Key Components

#### `usePresentationMode` Hook

Main logic hook that provides:
- `isPresentationMode` - current mode state
- `currentSlide` / `slides` - navigation state
- `isLaserActive` - laser tool state
- `getFrames()` - get all frame elements from canvas
- `startPresentation()` - enter presentation mode
- `endPresentation()` - exit presentation mode
- `nextSlide()` / `prevSlide()` / `goToSlide()` - navigation
- `toggleLaser()` / `toggleTheme()` / `toggleFullscreen()` - toggles
- `setSlides()` - set custom slide order

#### `PresentationPanel` Component

Sidebar panel that:
- Fetches frames using `excalidrawAPI.getSceneElements()`
- Maintains local `orderedFrames` state for reordering
- Syncs with canvas (adds new frames, removes deleted ones)
- Renders `SlideThumb` components with move up/down buttons
- Calls `setSlides(orderedFrames)` before starting presentation

#### `PresentationControls` Component

Bottom control bar that:
- Renders navigation, laser, theme, fullscreen, and end buttons
- Auto-fades after 3 seconds of inactivity
- Shows on mouse movement
- Uses localized strings via `t()` function

#### `PresentationMode` Component

Portal wrapper that:
- Renders `PresentationControls` into `document.body`
- Only renders when `isPresentationMode` is true

## Behavior Details

### Entering Presentation Mode

1. Sidebar closes automatically
2. View mode and Zen mode are enabled (hides UI)
3. Pen toolbar is hidden
4. Laser tool is activated by default
5. First slide is displayed with smooth animation (800ms)
6. Keyboard listeners are attached

### Slide Navigation

- Uses `excalidrawAPI.scrollToContent()` with:
  - `fitToContent: true` - frame fills viewport
  - `animate: true` - smooth transition
  - `duration: 800` - animation duration in ms

### Laser Pointer

- Uses Excalidraw's built-in laser tool
- Activated via `excalidrawAPI.setActiveTool({ type: "laser" })`
- Drawings fade out automatically (laser behavior)

### Exiting Presentation Mode

1. Original theme is restored
2. View mode and Zen mode are disabled
3. Laser tool is deactivated
4. Fullscreen is exited (if active)
5. Keyboard listeners are removed
6. UI elements become visible again

## Styling

### Control Bar

- Fixed position at bottom center
- Rounded corners with shadow
- Dark mode support via CSS variables
- Fade animation on inactivity:
  - Fade out: 0.8s ease-out to 0.1 opacity
  - Fade in: 0.2s ease-in on hover

### Sidebar Panel

- Slide thumbnails with frame names
- Reorder buttons (↑/↓) on hover
- Empty state with instructions
- Dark mode support

## Localization

All UI strings are localized. Keys added to `locales/en.json` and `locales/ru-RU.json`:

```json
{
  "presentation.title": "Presentation",
  "presentation.createSlide": "+ Create slide",
  "presentation.startPresentation": "Start presentation",
  "presentation.endPresentation": "End presentation",
  "presentation.slideCounter": "Slide {{current}}/{{total}}",
  "presentation.previousSlide": "Previous slide",
  "presentation.nextSlide": "Next slide",
  "presentation.toggleLaser": "Toggle laser pointer",
  "presentation.toggleTheme": "Toggle dark mode",
  "presentation.toggleFullscreen": "Toggle fullscreen",
  "presentation.emptyStateTitle": "Create presentations with AstraDraw",
  "presentation.emptyStateDescription": "Use the Frame tool to create slides for your presentation",
  "presentation.moveUp": "Move up",
  "presentation.moveDown": "Move down"
}
```

## Integration Points

### Modified Files

| File | Changes |
|------|---------|
| `frontend/excalidraw-app/App.tsx` | Import and render `PresentationMode` component |
| `frontend/excalidraw-app/components/AppSidebar.tsx` | Import and render `PresentationPanel`, pass `excalidrawAPI` |
| `frontend/excalidraw-app/pens/PenToolbar.tsx` | Hide when `zenModeEnabled` or `viewModeEnabled` |
| `frontend/packages/excalidraw/locales/en.json` | Add presentation translation keys |
| `frontend/packages/excalidraw/locales/ru-RU.json` | Add Russian translations |

### Excalidraw API Usage

```typescript
// Navigation
excalidrawAPI.scrollToContent(frame, { fitToContent: true, animate: true, duration: 800 })

// Tool switching
excalidrawAPI.setActiveTool({ type: "laser" })
excalidrawAPI.setActiveTool({ type: "selection" })

// Scene access
excalidrawAPI.getSceneElements()
excalidrawAPI.getAppState()

// UI control
excalidrawAPI.updateScene({ appState: { viewModeEnabled, zenModeEnabled } })
excalidrawAPI.toggleSidebar({ name: "default", force: false })
```

## Future Improvements

- [ ] Drag-and-drop slide reordering (currently uses ↑/↓ buttons)
- [ ] Slide preview on hover
- [ ] Presenter notes
- [ ] Slide timing/auto-advance
- [ ] Export to PDF/images
- [ ] Remote control support
