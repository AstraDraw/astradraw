# Web Embeds

AstraDraw supports embedding external content directly into your canvas using the **Web Embed** tool. This allows you to include live documents, videos, dashboards, and other web content alongside your drawings.

## How to Use

1. Select the **Web Embed** tool from the toolbar (or press the shortcut)
2. Draw a rectangle on the canvas where you want the embed to appear
3. Paste the URL of the content you want to embed
4. Click to interact with the embedded content

## Supported Services

### Video Platforms

| Service | Example URL | Notes |
|---------|-------------|-------|
| **YouTube** | `youtube.com/watch?v=...` | Videos, shorts, playlists |
| **Vimeo** | `vimeo.com/...` | Videos |

### Design & Development

| Service | Example URL | Notes |
|---------|-------------|-------|
| **Figma** | `figma.com/file/...` | Designs, prototypes |
| **GitHub Gist** | `gist.github.com/user/...` | Code snippets |
| **StackBlitz** | `stackblitz.com/...` | Code playgrounds |
| **Val Town** | `val.town/v/...` | Code vals |

### Microsoft 365

| Service | Example URL | Notes |
|---------|-------------|-------|
| **SharePoint** | `{tenant}.sharepoint.com/:x:/...` | Documents, spreadsheets |
| **OneDrive** | `onedrive.live.com/...` or `1drv.ms/...` | Files |
| **Power BI** | `app.powerbi.com/reportEmbed?...` | Dashboards, reports |
| **Microsoft Forms** | `forms.microsoft.com/...` | Forms, surveys |

**SharePoint/OneDrive File Types:**
- `:x:` - Excel spreadsheets
- `:w:` - Word documents
- `:p:` - PowerPoint presentations
- `:o:` - OneNote notebooks
- `:b:` - PDF files
- `:v:` - Videos
- `:i:` - Images

### Google Workspace

| Service | Example URL | Notes |
|---------|-------------|-------|
| **Google Docs** | `docs.google.com/document/d/...` | Documents |
| **Google Sheets** | `docs.google.com/spreadsheets/d/...` | Spreadsheets |
| **Google Slides** | `docs.google.com/presentation/d/...` | Presentations |
| **Google Drive** | `drive.google.com/file/d/...` | Files (PDFs, etc.) |

### Social Media

| Service | Example URL | Notes |
|---------|-------------|-------|
| **Twitter/X** | `twitter.com/.../status/...` | Tweets |
| **Reddit** | `reddit.com/r/.../comments/...` | Posts |
| **Giphy** | `giphy.com/gifs/...` | GIFs |

### Other

| Service | Example URL | Notes |
|---------|-------------|-------|
| **Kinescope** | `kinescope.io/...` | Video hosting |

## Authentication Requirements

Some embedded content requires authentication:

### Microsoft 365 (SharePoint, OneDrive, Power BI)
- **Private content**: You must be logged into your Microsoft 365 account in the same browser
- **Public content**: Share with "Anyone with the link" (no sign-in required) for unauthenticated access

### Google Workspace
- **Private content**: You must be logged into your Google account in the same browser
- **Public content**: Share with "Anyone with the link" for unauthenticated access

### Power BI Specific
- Use the **reportEmbed** URL format with `autoAuth=true` for better authentication flow
- Example: `https://app.powerbi.com/reportEmbed?reportId=...&autoAuth=true&ctid=...`

## Default Aspect Ratios

Embeds are created with optimal aspect ratios based on content type:

| Content Type | Aspect Ratio | Size |
|--------------|--------------|------|
| YouTube (landscape) | 16:9 | 560×315 |
| YouTube Shorts | 9:16 | 315×560 |
| Vimeo | 16:9 | 560×315 |
| Figma | 1:1 | 550×550 |
| Excel/Sheets | Wide | 900×600 |
| Word/Docs | Portrait | 700×900 |
| PowerPoint/Slides | 16:9 | 960×540/569 |
| Power BI | 16:9 | 1140×541 |
| Twitter | 1:1 | 480×480 |
| Reddit | 1:1 | 480×480 |
| GitHub Gist | Portrait | 550×720 |

## Troubleshooting

### Embed shows login prompt
- Open a new tab and log into the service (Microsoft 365, Google, etc.)
- Return to AstraDraw - the embed should now display content
- For permanent public access, change sharing settings to "Anyone with the link"

### Embed shows blank/error
- Verify the URL is a valid sharing link
- Check that the content hasn't been deleted or moved
- Ensure you have permission to view the content

### Content doesn't update after login
- Click on the embed to interact with it
- The iframe should refresh and show the authenticated content

## Technical Details

Web embeds use iframes with appropriate sandbox permissions:
- `allow-same-origin` - Required for authentication
- `allow-scripts` - Required for interactive content
- `allow-forms` - Required for forms and inputs
- `allow-popups` - Required for authentication flows
- `allow-popups-to-escape-sandbox` - Required for OAuth redirects
- `allow-presentation` - Required for fullscreen
- `allow-downloads` - Required for file downloads
- `allow-top-navigation-by-user-activation` - Required for auth redirects

## Adding Custom Embed Sources

The embed validation can be customized via the `validateEmbeddable` prop on the Excalidraw component. See the [Excalidraw documentation](https://docs.excalidraw.com/docs/@excalidraw/excalidraw/api/props#validateembeddable) for details.
