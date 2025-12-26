# AstraDraw Libraries System Documentation

This document describes how the Excalidraw library system works, including how libraries are stored, loaded, published, and shared. This knowledge is essential for customizing the library experience in AstraDraw.

## Table of Contents

1. [Overview](#overview)
2. [Library Data Structure](#library-data-structure)
3. [Library Storage](#library-storage)
4. [Loading Libraries](#loading-libraries)
5. [Publishing Libraries](#publishing-libraries)
6. [Library URL Sharing](#library-url-sharing)
7. [excalidraw-libraries Repository](#excalidraw-libraries-repository)
8. [AstraDraw Customization Points](#astradraw-customization-points)

---

## Overview

The Excalidraw library system allows users to:
- Save reusable drawing elements (shapes, icons, diagrams) to their personal library
- Share libraries via URL links
- Publish libraries to a public repository for community use
- Import libraries from external sources

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| Library Class | `packages/excalidraw/data/library.ts` | Core library management |
| LibraryMenu | `packages/excalidraw/components/LibraryMenu.tsx` | UI for browsing libraries |
| PublishLibrary | `packages/excalidraw/components/PublishLibrary.tsx` | Publishing dialog |
| LibraryIndexedDBAdapter | `frontend/excalidraw-app/data/LocalData.ts` | Browser storage |
| useHandleLibrary | `packages/excalidraw/data/library.ts` | React hook for library operations |

---

## Library Data Structure

### `.excalidrawlib` File Format

Library files use the `.excalidrawlib` extension and contain JSON data:

```json
{
  "type": "excalidrawlib",
  "version": 2,
  "source": "https://excalidraw.com",
  "name": "My Library",
  "names": {
    "ru-RU": "Моя библиотека",
    "de-DE": "Meine Bibliothek"
  },
  "libraryItems": [
    {
      "id": "unique-id-123",
      "status": "published",
      "created": 1634567890123,
      "name": "My Shape",
      "elements": [
        {
          "type": "rectangle",
          "x": 0,
          "y": 0,
          "width": 100,
          "height": 100,
          // ... other element properties
        }
      ]
    }
  ]
}
```

#### AstraDraw Library Metadata (Root Level)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `"excalidrawlib"` |
| `version` | number | Yes | File format version (currently `2`) |
| `source` | string | No | URL of the source application (informational only) |
| `name` | string | No | **AstraDraw**: Library display name (fallback). If not provided, filename is humanized (e.g., `software-architecture.excalidrawlib` → "Software Architecture") |
| `names` | object | No | **AstraDraw**: Localized library names map. Keys are language codes (e.g., `"ru-RU"`, `"de-DE"`, `"en"`). Takes priority over `name` when the user's UI language matches. |
| `library` or `libraryItems` | array | Yes | Array of library items |

> **Note**: The `name` and `names` fields are AstraDraw extensions. They are used for the collapsible section headers in the library sidebar. The `source` field is purely informational and not processed by AstraDraw.

### LibraryItem Interface

```typescript
interface LibraryItem {
  id: string;                           // Unique identifier
  status: "published" | "unpublished";  // Publication status
  created: number;                      // Unix timestamp
  name?: string;                        // Display name (required for publishing)
  elements: ExcalidrawElement[];        // The actual drawing elements
  error?: string;                       // Validation error (UI only)
  libraryName?: string;                 // AstraDraw: Library section name (fallback)
  libraryNames?: Record<string, string>; // AstraDraw: Localized library names
}
```

### Status Meanings

- **`unpublished`**: User's personal items, editable, shown in "Your library" section
- **`published`**: Items from external sources or published items, shown in "Library" section, typically read-only in UI

---

## Library Storage

### Where User Libraries Are Stored

**User libraries are stored locally in the browser's IndexedDB** - they do NOT use the excalidraw-storage-backend.

```
Location: IndexedDB
Database: "excalidraw-library-db"
Store: "excalidraw-library-store"
Key: "libraryData"
```

### Storage Flow

```
User adds item to library
        ↓
Library.setLibrary() called
        ↓
libraryItemsAtom updated (Jotai state)
        ↓
onLibraryChange callback triggered
        ↓
useHandleLibrary hook detects change
        ↓
LibraryIndexedDBAdapter.save() persists to IndexedDB
```

### LibraryIndexedDBAdapter Implementation

Located in `frontend/excalidraw-app/data/LocalData.ts`:

```typescript
export class LibraryIndexedDBAdapter {
  private static idb_name = "excalidraw-library";
  private static key = "libraryData";
  
  static async load() {
    // Returns { libraryItems: [...] } or null
  }
  
  static save(data: LibraryPersistedData) {
    // Persists to IndexedDB
  }
}
```

### Important Implications

1. **Libraries are per-browser** - Not synced across devices
2. **Clearing browser data deletes libraries** - No cloud backup
3. **Storage backend is NOT used** - Only scenes, rooms, and files use the backend
4. **No user authentication required** - Libraries work offline

---

## Loading Libraries

### Initial Load on App Start

The `useHandleLibrary` hook handles loading:

```typescript
// In App.tsx
useHandleLibrary({
  excalidrawAPI,
  adapter: LibraryIndexedDBAdapter,
  migrationAdapter: LibraryLocalStorageMigrationAdapter,
});
```

### Load Sequence

1. Hook initializes when `excalidrawAPI` becomes available
2. Checks for migration data (legacy localStorage → IndexedDB)
3. Loads from `LibraryIndexedDBAdapter`
4. Calls `excalidrawAPI.updateLibrary({ libraryItems, merge: true })`
5. Checks URL for `#addLibrary` parameter

### Loading from initialData

Libraries can also be provided via `initialData` prop:

```typescript
<Excalidraw
  initialData={{
    libraryItems: [...],  // Will be merged with stored items
  }}
/>
```

This is processed in `packages/excalidraw/components/App.tsx`:

```typescript
if (initialData?.libraryItems) {
  this.library.updateLibrary({
    libraryItems: initialData.libraryItems,
    merge: true,
  });
}
```

---

## Publishing Libraries

### Publishing Flow

```
User selects library items → Clicks "Publish" → Fills form → Submit
        ↓
PublishLibrary.tsx generates preview image
        ↓
Creates FormData with:
  - excalidrawLib (JSON blob)
  - previewImage (JPEG)
  - metadata (name, author, description, etc.)
        ↓
POST to VITE_APP_LIBRARY_BACKEND/submit
        ↓
Backend creates GitHub Pull Request
        ↓
Returns { url: "PR URL" }
        ↓
User sees success dialog with PR link
```

### Backend Endpoint

The publish feature requires a backend service:

```typescript
// PublishLibrary.tsx line 302
fetch(`${import.meta.env.VITE_APP_LIBRARY_BACKEND}/submit`, {
  method: "post",
  body: formData,
})
```

**Environment Variables:**
```bash
# .env.development
VITE_APP_LIBRARY_BACKEND=https://us-central1-excalidraw-room-persistence.cloudfunctions.net/libraries

# This is Excalidraw's Google Cloud Function - NOT open source
```

### FormData Contents

| Field | Type | Description |
|-------|------|-------------|
| `excalidrawLib` | Blob (JSON) | The library file content |
| `previewImage` | Blob (JPEG) | Auto-generated preview |
| `previewImageType` | String | MIME type of preview |
| `title` | String | Library name |
| `authorName` | String | Author's display name |
| `githubHandle` | String | GitHub username (optional) |
| `name` | String | Library name |
| `description` | String | Library description |
| `twitterHandle` | String | Twitter username (optional) |
| `website` | String | Author's website (optional) |

### Hardcoded URLs in PublishLibrary.tsx

These need to be changed for AstraDraw:

```typescript
// Line 389-394 - Link to library website
<a href="https://libraries.excalidraw.com" ...>

// Line 403-410 - Link to guidelines
<a href="https://github.com/excalidraw/excalidraw-libraries#guidelines" ...>

// Line 507-510 - Link to license
<a href="https://github.com/excalidraw/excalidraw-libraries/blob/main/LICENSE" ...>
```

---

## Library URL Sharing

### The #addLibrary Feature

Users can share libraries via special URLs:

```
https://excalidraw.com/#addLibrary=https://example.com/my-library.excalidrawlib&token=abc123
```

### URL Parameters

| Parameter | Description |
|-----------|-------------|
| `addLibrary` | URL-encoded link to the `.excalidrawlib` file |
| `token` | Optional token to skip confirmation prompt (matches excalidraw instance ID) |

### URL Processing Flow

```typescript
// library.ts - parseLibraryTokensFromUrl()
const libraryUrl = new URLSearchParams(window.location.hash.slice(1))
  .get(URL_HASH_KEYS.addLibrary);
const idToken = new URLSearchParams(window.location.hash.slice(1))
  .get("token");
```

### URL Validation (Security)

**Important:** Not all URLs are allowed. There's a whitelist:

```typescript
// library.ts lines 54-58
const ALLOWED_LIBRARY_URLS = [
  "excalidraw.com",
  "raw.githubusercontent.com/excalidraw/excalidraw-libraries",
];
```

### Custom URL Validator

The `useHandleLibrary` hook accepts a custom validator:

```typescript
useHandleLibrary({
  excalidrawAPI,
  adapter: LibraryIndexedDBAdapter,
  // Custom validator to allow your domains
  validateLibraryUrl: (url) => {
    const allowed = [
      "libraries.astradraw.com",
      "raw.githubusercontent.com/your-org/your-libraries",
    ];
    return allowed.some(domain => url.includes(domain));
  },
});
```

### Import Flow

1. `parseLibraryTokensFromUrl()` extracts URL from hash
2. `validateLibraryUrl()` checks against whitelist
3. Fetches the `.excalidrawlib` file
4. If `token` doesn't match app ID, prompts user for confirmation
5. Calls `excalidrawAPI.updateLibrary({ libraryItems, merge: true })`
6. Cleans up URL hash

---

## excalidraw-libraries Repository

### Repository Structure

```
excalidraw-libraries/
├── libraries/
│   ├── {author-name}/
│   │   ├── {library-name}.excalidrawlib
│   │   └── {library-name}.png (or .jpg)
│   └── ...
├── libraries.json          # Index of all libraries
├── authors.json            # Author information
├── index.html              # Browse UI (hosted at libraries.excalidraw.com)
├── script.js               # Browse UI logic
├── style.css               # Browse UI styles
├── .github/
│   └── workflows/
│       ├── process-libraries.yml   # Processes PRs
│       └── validate-libraries.yml  # Validates submissions
└── scripts/
    ├── gen-item-names.mjs          # Generates item names
    └── validate-libraries.js       # Validation logic
```

### libraries.json Format

```json
[
  {
    "name": "Library Display Name",
    "description": "Description of the library",
    "authors": [
      {
        "name": "Author Name",
        "url": "https://author-website.com",
        "github": "github-username"
      }
    ],
    "source": "author-folder/library-name.excalidrawlib",
    "preview": "author-folder/library-name.png",
    "created": "2024-01-15",
    "updated": "2024-01-15",
    "version": 1,
    "id": "unique-id-abc"
  }
]
```

### GitHub Actions Workflows

**validate-libraries.yml:**
- Runs on PRs
- Validates JSON syntax
- Checks file structure
- Ensures preview images exist

**process-libraries.yml:**
- Runs on PRs to main
- Regenerates `itemNames` in libraries.json
- Auto-commits changes

---

## AstraDraw Customization Points

### 1. Add Pre-bundled Libraries (Docker Volume Mount)

Modify `docker-entrypoint.sh` to load libraries from a mounted folder:

```bash
# Scan /app/libraries/*.excalidrawlib
# Generate libraries-config.js
# Inject into index.html
```

### 2. Change Library Backend URL

Add to `.env.production` and `docker-entrypoint.sh`:

```bash
VITE_APP_LIBRARY_BACKEND=https://your-library-backend.com/api
```

### 3. Update URL Whitelist

In `App.tsx`, add custom validator:

```typescript
useHandleLibrary({
  excalidrawAPI,
  adapter: LibraryIndexedDBAdapter,
  validateLibraryUrl: (url) => {
    return url.includes("libraries.astradraw.com") ||
           url.includes("raw.githubusercontent.com/your-org");
  },
});
```

### 4. Update PublishLibrary Links

In `packages/excalidraw/components/PublishLibrary.tsx`, change:
- Libraries website URL
- Guidelines URL  
- License URL

### 5. Create astradraw-libraries Repository

Fork `excalidraw-libraries` and:
- Update `index.html` branding
- Update GitHub Actions for your repo
- Update README with your guidelines

### 6. Build Library Submission Backend

Options:
- **Cloudflare Worker** - Free, serverless, creates GitHub PRs
- **GitHub Issue Template** - No backend, users attach files manually
- **Docker Service** - Self-hosted, full control

---

## Environment Variables Summary

| Variable | Purpose | Default |
|----------|---------|---------|
| `VITE_APP_LIBRARY_URL` | URL to browse libraries | `https://libraries.excalidraw.com` |
| `VITE_APP_LIBRARY_BACKEND` | Backend for publishing | Google Cloud Function |

---

## API Reference

### ExcalidrawAPI.updateLibrary()

```typescript
updateLibrary(opts: {
  libraryItems: LibraryItemsSource;
  merge?: boolean;           // Default: false
  prompt?: boolean;          // Default: false (ask user confirmation)
  openLibraryMenu?: boolean; // Default: false
  defaultStatus?: "unpublished" | "published"; // Default: "unpublished"
}): Promise<LibraryItems>
```

### Library.setLibrary()

```typescript
setLibrary(
  libraryItems: LibraryItems | Promise<LibraryItems> | 
    ((latestItems: LibraryItems) => LibraryItems | Promise<LibraryItems>)
): Promise<LibraryItems>
```

### useHandleLibrary Hook

```typescript
useHandleLibrary({
  excalidrawAPI: ExcalidrawImperativeAPI | null;
  validateLibraryUrl?: (url: string) => boolean;
  adapter: LibraryPersistenceAdapter;
  migrationAdapter?: LibraryMigrationAdapter;
})
```

---

## Further Reading

- [Excalidraw Libraries Repository](https://github.com/excalidraw/excalidraw-libraries)
- [Excalidraw API Documentation](https://docs.excalidraw.com)
- Original source files in `packages/excalidraw/data/library.ts`
