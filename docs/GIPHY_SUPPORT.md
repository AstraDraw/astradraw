# Add GIPHY Sidebar Tab

## Overview

Add a new GIPHY tab to the AstraDraw sidebar that allows users to search for GIFs and stickers, view trending content, and insert them onto the canvas as image elements.

## Architecture

```mermaid
flowchart TB
    subgraph Sidebar
        AppSidebar[AppSidebar.tsx]
        GiphyTab[Sidebar.Tab: giphy]
        GiphyPanel[GiphyPanel.tsx]
    end

    subgraph GiphyComponents
        GiphySearch[Search Input]
        GiphyTabs[Tabs: GIFs/Stickers]
        GiphyGrid[GIF Grid]
        GiphyItem[GIF Item]
    end

    subgraph ExcalidrawAPI
        addFiles[addFiles]
        updateScene[updateScene]
    end

    AppSidebar --> GiphyTab
    GiphyTab --> GiphyPanel
    GiphyPanel --> GiphySearch
    GiphyPanel --> GiphyTabs
    GiphyPanel --> GiphyGrid
    GiphyGrid --> GiphyItem
    GiphyItem -->|onClick| addFiles
    GiphyItem -->|onClick| updateScene
```



## Files to Create/Modify

### 1. New Files

- **`excalidraw-app/components/Giphy/GiphyPanel.tsx`** - Main panel component with search, tabs (GIFs/Stickers), trending, and grid display
- **`excalidraw-app/components/Giphy/GiphyPanel.scss`** - Styles for the GIPHY panel
- **`excalidraw-app/components/Giphy/index.ts`** - Export file
- **`excalidraw-app/components/Giphy/giphyApi.ts`** - API helper functions for GIPHY fetch requests

### 2. Modify Existing Files

- **[`excalidraw-app/components/AppSidebar.tsx`](excalidraw-app/components/AppSidebar.tsx)** - Add new GIPHY tab trigger and tab content
- **[`packages/excalidraw/components/icons.tsx`](packages/excalidraw/components/icons.tsx)** - Add GIPHY/GIF icon
- **[`packages/excalidraw/locales/en.json`](packages/excalidraw/locales/en.json)** - Add English translations for GIPHY tab
- **[`packages/excalidraw/locales/ru-RU.json`](packages/excalidraw/locales/ru-RU.json)** - Add Russian translations for GIPHY tab

## Implementation Details

### GIPHY API Integration

Use the GIPHY Fetch API directly (no SDK needed for basic usage). API Key will be configured via environment variable:

```typescript
// Environment variable: VITE_APP_GIPHY_API_KEY
const GIPHY_API_KEY = import.meta.env.VITE_APP_GIPHY_API_KEY;
```

**To get a GIPHY API key:**

1. Go to [developers.giphy.com](https://developers.giphy.com/)
2. Create an account or sign in
3. Click "Create an App"
4. Select "API" (not SDK)
5. Copy your API key

### GiphyPanel Component Features

1. **Search bar** - Search for GIFs/stickers by keyword
2. **Content type toggle** - Switch between GIFs and Stickers
3. **Trending section** - Show trending GIFs when no search query
4. **Responsive grid** - Display GIFs in a masonry-style grid
5. **Loading states** - Show skeleton/spinner while loading
6. **Error handling** - Display error message if API fails or key missing

### Adding GIF to Canvas

When a user clicks a GIF:

1. Fetch the GIF image as a data URL (using the `fixed_width` rendition for performance)
2. Create a unique `FileId` for the image
3. Call `excalidrawAPI.addFiles()` to register the binary file
4. Call `excalidrawAPI.updateScene()` to add an image element positioned at the center of the viewport
```typescript
// Key snippet for inserting GIF
const fileId = nanoid() as FileId;
const response = await fetch(gifUrl);
const blob = await response.blob();
const dataURL = await blobToDataURL(blob);

excalidrawAPI.addFiles([{
  id: fileId,
  dataURL,
  mimeType: "image/gif",
}]);

excalidrawAPI.updateScene({
  elements: [...elements, newImageElement],
});
```




### Translations

**English (en.json):**

```json
"giphy": {
  "title": "GIPHY",
  "search": "Search GIFs...",
  "searchStickers": "Search stickers...",
  "gifs": "GIFs",
  "stickers": "Stickers",
  "trending": "Trending",
  "noResults": "No results found",
  "loading": "Loading...",
  "error": "Failed to load GIFs",
  "apiKeyMissing": "GIPHY API key is not configured",
  "poweredBy": "Powered by GIPHY"
}
```

**Russian (ru-RU.json):**

```json
"giphy": {
  "title": "GIPHY",
  "search": "Поиск GIF...",
  "searchStickers": "Поиск стикеров...",
  "gifs": "GIF",
  "stickers": "Стикеры",
  "trending": "Популярное",
  "noResults": "Ничего не найдено",
  "loading": "Загрузка...",
  "error": "Не удалось загрузить GIF",
  "apiKeyMissing": "API ключ GIPHY не настроен",
  "poweredBy": "При поддержке GIPHY"
}
```



### Icon

Add a GIF icon to `icons.tsx` using the Tabler icons style:

```typescript
export const gifIcon = createIcon(
  <g strokeWidth="1.25">
    <path stroke="none" d="M0 0h24v24H0z" fill="none" />
    <rect x="3" y="5" width="18" height="14" rx="2" />
    <path d="M7 15v-4a2 2 0 0 1 4 0v4" />
    <path d="M7 13h4" />
    <path d="M15 15v-6h2a2 2 0 1 1 0 4h-2" />
  </g>,
  tablerIconProps,
);
```



## Environment Setup

Add to `.env.development` or `.env.production`:

```javascript
VITE_APP_GIPHY_API_KEY=your_api_key_here
```



## Dependencies

No new npm packages needed - we'll use the native Fetch API to call GIPHY endpoints directly:

- Trending: `https://api.giphy.com/v1/gifs/trending`
- Search: `https://api.giphy.com/v1/gifs/search`
- Stickers trending: `https://api.giphy.com/v1/stickers/trending`



Implementation Complete
I've successfully implemented the Stickers & GIFs sidebar tab for AstraDraw. Here's what was created/modified:
New Files Created
excalidraw-app/components/Stickers/giphyApi.ts - API helper functions for GIPHY endpoints:
fetchTrending() - Fetch trending content by type
searchContent() - Search GIFs/Stickers/Emojis
imageUrlToDataUrl() - Convert image URL to data URL for canvas insertion
Support for all content types: GIFs, Stickers, Emojis, All
excalidraw-app/components/Stickers/StickersPanel.tsx - Main panel component with:
Search bar with debounced search
Sub-tabs: All, Stickers, Emojis, GIFs
Masonry grid layout
Click-to-insert functionality
Loading/error/empty states
"Powered by GIPHY" attribution footer
excalidraw-app/components/Stickers/StickersPanel.scss - Styles matching the GIPHY UI design
excalidraw-app/components/Stickers/index.ts - Export file
Modified Files
packages/excalidraw/components/icons.tsx - Added stickerIcon
packages/excalidraw/locales/en.json - Added English translations for the stickers tab
packages/excalidraw/locales/ru-RU.json - Added Russian translations
excalidraw-app/components/AppSidebar.tsx - Added the new Stickers tab trigger and content
docker-compose.yml - Added VITE_APP_GIPHY_API_KEY environment variable
env.example - Documented the GIPHY API key configuration
To Use
Add your GIPHY API key to your .env file:
   GIPHY_API_KEY=your_api_key_here
   GIPHY_API_KEY=your_api_key_here
Rebuild and restart Docker:
   docker compose up -d --build
   docker compose up -d --build
The new Stickers & GIFs tab will appear in the sidebar (alongside Search, Libraries, Comments, Presentation). Users can browse trending content, search for GIFs/Stickers/Emojis, and click to insert them directly onto the canvas.