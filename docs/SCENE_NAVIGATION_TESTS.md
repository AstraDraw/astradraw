# Scene Navigation Test Scenarios

This document contains test scenarios for the Scene Navigation feature (Excalidraw Plus pattern).

## Interactive Test Script (Recommended)

For easier testing, use the interactive test script:

```bash
# Run from project root
just test-navigation

# Or directly
cd deploy && node test-scene-navigation.js
```

The script will:
- Ask for your domain and configuration
- Guide you through each test step by step
- Provide clickable URLs
- Save results to `deploy/test-results/` folder

---

## Manual Testing Reference

If you prefer manual testing, use the tables below.

**Tester:** _______________  
**Date:** _______________  
**Build Version:** _______________

### How to Use This Document

For each test:
1. Follow the steps exactly
2. Record the result: ✅ Passed / ❌ Failed
3. If failed, describe what happened in the "Notes" column

---

## 1. Login & Dashboard Redirect

| # | Test | Steps | Expected Result | Result | Notes |
|---|------|-------|-----------------|--------|-------|
| 1.1 | Fresh login redirects to dashboard | 1. Clear cookies/use incognito<br>2. Open `https://your-domain/`<br>3. Log in | After login, URL changes to `/workspace/{slug}/dashboard` and dashboard is displayed | | |
| 1.2 | Root URL redirects when logged in | 1. While logged in, navigate to `https://your-domain/`<br>2. Wait for redirect | URL changes to `/workspace/{slug}/dashboard` | | |
| 1.3 | Direct dashboard URL works | 1. Open `https://your-domain/workspace/admin/dashboard` directly | Dashboard is displayed, URL stays the same | | |

---

## 2. Scene Creation

| # | Test | Steps | Expected Result | Result | Notes |
|---|------|-------|-----------------|--------|-------|
| 2.1 | Create scene from dashboard button | 1. Go to dashboard<br>2. Click "+ Начать рисовать" button | New scene created, redirected to canvas with URL `/workspace/{slug}/scene/{id}` | | |
| 2.2 | Create scene from sidebar (canvas mode) | 1. Open any scene (canvas mode)<br>2. In sidebar, click "+" next to collection name | New scene created in that collection, canvas updates, URL changes | | |
| 2.3 | Create scene from collection context menu | 1. Go to dashboard<br>2. Right-click on a collection<br>3. Select "New scene" | New scene created in that collection, redirected to canvas | | |
| 2.4 | Scene appears in correct collection | 1. Create scene from a specific collection<br>2. Go to dashboard<br>3. Click on that collection | New scene is visible in the collection | | |

---

## 3. Scene Navigation (Switching Between Scenes)

| # | Test | Steps | Expected Result | Result | Notes |
|---|------|-------|-----------------|--------|-------|
| 3.1 | Switch scenes from sidebar | 1. Have 2+ scenes in a collection<br>2. Open Scene A<br>3. Click Scene B in sidebar | URL changes to Scene B, canvas shows Scene B content | | |
| 3.2 | Scene content is correct | 1. Create Scene A, draw a rectangle<br>2. Create Scene B, draw a circle<br>3. Switch between them | Each scene shows its own content (rectangle/circle) | | |
| 3.3 | Open scene from dashboard | 1. Go to dashboard<br>2. Click on a scene card | URL changes to scene URL, canvas shows scene content | | |
| 3.4 | Open scene from collection view | 1. Go to dashboard<br>2. Click on a collection<br>3. Click on a scene in that collection | URL changes to scene URL, canvas shows scene content | | |
| 3.5 | Rapid scene switching | 1. Have 3+ scenes<br>2. Quickly click Scene A, then B, then C | Final scene (C) is displayed, no errors in console | | |

---

## 4. Scene Deletion

| # | Test | Steps | Expected Result | Result | Notes |
|---|------|-------|-----------------|--------|-------|
| 4.1 | Delete scene (others remain) | 1. Have 2+ scenes in collection<br>2. Open Scene A<br>3. Delete Scene A from sidebar | Confirmation dialog appears, after confirm: switches to another scene in same collection | | |
| 4.2 | Delete last scene in collection | 1. Have only 1 scene in collection<br>2. Open that scene<br>3. Delete it | After deletion, redirects to dashboard | | |
| 4.3 | URL updates after deletion | 1. Delete current scene<br>2. Check URL | URL shows new scene URL or dashboard URL (not deleted scene URL) | | |
| 4.4 | Back button after deletion | 1. Delete a scene → goes to dashboard/another scene<br>2. Click browser Back button | Does NOT go back to deleted scene URL | | |
| 4.5 | Delete scene from dashboard | 1. Go to dashboard<br>2. Right-click scene card<br>3. Delete scene | Scene removed from list, no navigation issues | | |

---

## 5. Browser Navigation (Back/Forward)

| # | Test | Steps | Expected Result | Result | Notes |
|---|------|-------|-----------------|--------|-------|
| 5.1 | Back from scene to dashboard | 1. Go to dashboard<br>2. Open a scene<br>3. Click browser Back | Returns to dashboard, URL is dashboard URL | | |
| 5.2 | Forward from dashboard to scene | 1. After test 5.1, click browser Forward | Returns to scene, URL is scene URL, content is correct | | |
| 5.3 | Back between scenes | 1. Open Scene A<br>2. Open Scene B<br>3. Click Back | Returns to Scene A with correct content | | |
| 5.4 | Multiple back/forward | 1. Navigate: Dashboard → Scene A → Scene B → Dashboard<br>2. Click Back 3 times<br>3. Click Forward 3 times | Navigation works correctly through all states | | |

---

## 6. Page Refresh

| # | Test | Steps | Expected Result | Result | Notes |
|---|------|-------|-----------------|--------|-------|
| 6.1 | Refresh on scene | 1. Open a scene with content<br>2. Press F5/Cmd+R | Same scene loads with same content | | |
| 6.2 | Refresh on dashboard | 1. Go to dashboard<br>2. Press F5/Cmd+R | Dashboard reloads, stays on dashboard | | |
| 6.3 | Refresh on collection view | 1. Go to a collection view<br>2. Press F5/Cmd+R | Collection view reloads correctly | | |

---

## 7. Direct URL Access (Bookmarks)

| # | Test | Steps | Expected Result | Result | Notes |
|---|------|-------|-----------------|--------|-------|
| 7.1 | Bookmark scene URL | 1. Copy scene URL<br>2. Close browser<br>3. Open URL in new browser/tab | Scene loads with correct content (after login if needed) | | |
| 7.2 | Bookmark dashboard URL | 1. Copy dashboard URL<br>2. Open in new tab | Dashboard loads correctly | | |
| 7.3 | Bookmark collection URL | 1. Copy collection URL `/workspace/{slug}/collection/{id}`<br>2. Open in new tab | Collection view loads correctly | | |
| 7.4 | Invalid scene URL | 1. Open URL with non-existent scene ID<br>2. Wait for load | Error handled, redirects to dashboard | | |

---

## 8. Collections

| # | Test | Steps | Expected Result | Result | Notes |
|---|------|-------|-----------------|--------|-------|
| 8.1 | Create new collection | 1. In sidebar, click "+" next to "КОЛЛЕКЦИИ"<br>2. Enter name and icon<br>3. Save | New collection appears in sidebar | | |
| 8.2 | Create scene in new collection | 1. Create a new collection<br>2. Create scene in that collection | Scene is created and visible in that collection | | |
| 8.3 | Switch between collections | 1. Have scenes in 2+ collections<br>2. Switch between collections in sidebar | Correct scenes shown for each collection | | |
| 8.4 | Delete collection with scenes | 1. Have a collection with scenes<br>2. Delete the collection | Confirmation dialog, collection and scenes deleted | | |
| 8.5 | Private collection always exists | 1. Check sidebar | "Приватное" collection is always present | | |

---

## 9. Multiple Workspaces

| # | Test | Steps | Expected Result | Result | Notes |
|---|------|-------|-----------------|--------|-------|
| 9.1 | Create new workspace | 1. Click workspace dropdown in sidebar<br>2. Create new workspace | New workspace created with private collection | | |
| 9.2 | Switch workspaces | 1. Have 2+ workspaces<br>2. Switch between them | Dashboard shows correct workspace, URL updates | | |
| 9.3 | Scenes isolated per workspace | 1. Create scene in Workspace A<br>2. Switch to Workspace B | Scene from A is not visible in B | | |
| 9.4 | URL reflects workspace | 1. Switch workspaces<br>2. Check URL | URL contains correct workspace slug | | |

---

## 10. Anonymous Mode

| # | Test | Steps | Expected Result | Result | Notes |
|---|------|-------|-----------------|--------|-------|
| 10.1 | Anonymous mode works | 1. Open `https://your-domain/?mode=anonymous` | Canvas is displayed (not dashboard), no login required | | |
| 10.2 | Anonymous mode is separate | 1. Draw something in anonymous mode<br>2. Log in<br>3. Go to dashboard | Anonymous drawing is not in workspace scenes | | |
| 10.3 | "Создать анонимную доску" button | 1. While logged in, click "Создать анонимную доску" in sidebar | Opens anonymous canvas | | |

---

## 11. Auto-save

| # | Test | Steps | Expected Result | Result | Notes |
|---|------|-------|-----------------|--------|-------|
| 11.1 | Changes auto-save | 1. Open a scene<br>2. Draw something<br>3. Wait 5 seconds<br>4. Refresh page | Drawing is preserved | | |
| 11.2 | Changes persist across sessions | 1. Draw in a scene<br>2. Log out<br>3. Log back in<br>4. Open same scene | Drawing is preserved | | |

---

## 12. Error Handling

| # | Test | Steps | Expected Result | Result | Notes |
|---|------|-------|-----------------|--------|-------|
| 12.1 | Network error on scene load | 1. Open DevTools → Network<br>2. Block scene API<br>3. Try to open a scene | Error message shown, redirects to dashboard | | |
| 12.2 | Deleted scene URL access | 1. Copy scene URL<br>2. Delete that scene<br>3. Paste URL and navigate | Error handled, redirects to dashboard | | |

---

## Summary

| Section | Total Tests | Passed | Failed |
|---------|-------------|--------|--------|
| 1. Login & Dashboard | 3 | | |
| 2. Scene Creation | 4 | | |
| 3. Scene Navigation | 5 | | |
| 4. Scene Deletion | 5 | | |
| 5. Browser Navigation | 4 | | |
| 6. Page Refresh | 3 | | |
| 7. Direct URL Access | 4 | | |
| 8. Collections | 5 | | |
| 9. Multiple Workspaces | 4 | | |
| 10. Anonymous Mode | 3 | | |
| 11. Auto-save | 2 | | |
| 12. Error Handling | 2 | | |
| **TOTAL** | **44** | | |

---

## Issues Found

| Test # | Issue Description | Severity | Status |
|--------|-------------------|----------|--------|
| | | | |
| | | | |
| | | | |

**Severity:** Critical / High / Medium / Low

---

## Notes

_Add any additional observations here_

