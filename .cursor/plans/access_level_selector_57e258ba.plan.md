---
name: Access Level Selector
overview: Add a VIEW/EDIT access level dropdown for team-collection assignments, replacing the current checkbox toggle with a three-state selector (None/VIEW/EDIT).
todos:
  - id: update-handler
    content: Update handleToggleCollectionTeamAccess to handle VIEW/EDIT/NONE selection
    status: completed
  - id: replace-checkbox
    content: Replace checkbox with access level dropdown in team assignment dialog
    status: completed
  - id: show-access-level
    content: Show access level badge in team chips display
    status: completed
  - id: add-styles
    content: Add SCSS styles for access-select and access-badge
    status: completed
  - id: add-translations
    content: Add translation keys to en.json and ru-RU.json
    status: completed
---

# Add VIEW/EDIT Access Level Selector for Team-Collection Assignment

## Problem

When assigning a team to a collection in [TeamsCollectionsPage.tsx](frontend/excalidraw-app/components/Settings/TeamsCollectionsPage.tsx), the access level is hardcoded to "EDIT" (line 376). The backend API already supports both VIEW and EDIT access levels.

## Solution

Replace the checkbox toggle with a dropdown selector that allows choosing between three states:

- **None** - No access (removes team from collection)
- **VIEW** - Team can view scenes but not edit
- **EDIT** - Team can view and edit scenes

## Changes

### 1. Update Team Assignment Dialog (TeamsCollectionsPage.tsx)

Replace the checkbox (lines 1070-1081) with a `<select>` dropdown similar to the role selector in MembersPage:

```tsx
<select
  value={hasAccess ? currentAccessLevel : "NONE"}
  onChange={(e) => handleAccessLevelChange(collectionId, teamId, e.target.value)}
  className="teams-collections-page__access-select"
>
  <option value="NONE">{t("settings.accessNone")}</option>
  <option value="VIEW">{t("settings.accessView")}</option>
  <option value="EDIT">{t("settings.accessEdit")}</option>
</select>
```



### 2. Update Handler Function

Modify `handleToggleCollectionTeamAccess` to `handleAccessLevelChange` that:

- Removes access when "NONE" is selected
- Calls `setCollectionTeamAccess` with the selected level for VIEW/EDIT

### 3. Show Access Level in Team Chips

Update the team chips display (lines 704-711) to show the access level badge:

```tsx
<span className="teams-collections-page__team-chip" style={{ backgroundColor: ta.teamColor }}>
  {ta.teamName}
  <span className="teams-collections-page__access-badge">
    {ta.accessLevel === "VIEW" ? t("settings.accessView") : t("settings.accessEdit")}
  </span>
</span>
```



### 4. Add SCSS Styles

Add to [TeamsCollectionsPage.scss](frontend/excalidraw-app/components/Settings/TeamsCollectionsPage.scss):

- `&__access-select` - Styled dropdown (reuse pattern from MembersPage `&__role-select`)
- `&__access-badge` - Small badge inside team chips showing VIEW/EDIT

### 5. Add Translation Keys

Add to both `en.json` and `ru-RU.json`:

- `settings.accessNone`: "No access" / "Нет доступа"
- `settings.accessView`: "View" / "Просмотр"  
- `settings.accessEdit`: "Edit" / "Редактирование"

## Files to Modify