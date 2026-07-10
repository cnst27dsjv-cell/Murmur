# Murmur V1 PRD / Design Spec

## 1. Product Positioning

Murmur V1 is a macOS desktop app that creates a private mood corner on the desktop. It lets users place mood, lightweight tasks, and self-reminders into a polished, personalized, privacy-aware desktop widget.

The product is not a heavy task manager and not only a desktop pet app. The core experience is a translucent frosted-glass widget that feels like a private magazine page on the desktop. By default, the widget content is protected behind a personalized blur cover. Clicking the widget reveals the internal content. A desktop pet or personal character stays attached to the widget edge and remains visible at all times.

Core value proposition:

> Put mood, to-dos, and self-reminders on your desktop.

## 2. V1 Scope

V1 ships one main desktop widget as an edge-attached drawer. It should be stable enough for daily personal use and polished enough to support future App Store or commercial exploration.

### In Scope

- macOS-first desktop app.
- One main desktop widget, with architecture that does not block future multi-widget support.
- Edge-attached drawer behavior: collapsed pet-only state plus expanded full widget state.
- Frosted-glass transparent visual style.
- Default blurred cover state.
- Click-to-toggle between blurred cover and clear content.
- Default fade transition for cover reveal/hide, with an animation structure that can support future reveal effects.
- Cover personalization with one of:
  - user-selected image,
  - meme/sticker image,
  - motto or favorite sentence.
- Always-clear desktop pet/personal character attached to the widget edge.
- Built-in static pets/characters.
- User-uploaded pet/character image.
- Main phrase for mood/self-reminder.
- Expandable or editable private note.
- Lightweight to-do list:
  - create task,
  - edit task,
  - mark complete,
  - delete task.
- Quick inline editing for simple content.
- Settings panel for deeper personalization.
- Fully local storage for text, tasks, widget state, positions, and uploaded assets.
- Restore widget content, position, blur state, and selected assets after app restart.

### Out of Scope for V1

- Multiple widgets on the desktop.
- User account, login, or cloud sync.
- Task due dates, reminders, recurring tasks, project grouping, or heavy prioritization.
- Animated or interactive desktop pets.
- Template marketplace, paid themes, community sharing, or monetization.
- Windows or cross-platform release.
- Heavy rich-text editor inside the widget.

## 3. Target Experience

Murmur should feel like a calm, polished desktop companion. The user should want to leave it visible all day. The product should feel more refined than a sticky note and lighter than a productivity suite.

The ideal V1 emotional tone is:

- calm,
- private,
- personal,
- lightly expressive,
- visually polished,
- not childish,
- not noisy.

Visual direction:

> Cool, refined base + cute personal accent.

## 4. Core Interaction Flow

### First Launch

The user launches the app and sees one default frosted-glass widget on the desktop. It includes a default cover, sample content, and a built-in static pet attached to the widget edge.

The user can start using the default widget immediately or open settings to customize it.

### Default Desktop State

The widget defaults to a collapsed edge-attached pet state. The pet stays visible near the left or right screen edge. Clicking the pet expands the full widget.

When expanded, the widget defaults to the blurred cover state. The cover hides internal text and tasks while showing a personalized center element: image, sticker/meme, or text.

The desktop pet remains outside or on the edge of the widget and stays clear. It is never blurred by the privacy cover.

### Reveal Content

The user clicks the pet to expand the full widget from the screen edge. The user clicks the widget body to reveal content. The cover fades out and the internal content becomes clear. The user can see:

- main phrase,
- private note summary or editable private note,
- lightweight to-do list.

The pet remains clear and attached to the edge.

Clicking the widget body again returns the internal content to the blurred cover state. The pet remains clear.

Dragging the pet or widget moves the drawer. Releasing it snaps the drawer to the closer screen edge.

V1 uses a fade transition by default. The implementation should avoid hard-coding the transition as the only possible reveal style, so future versions can support effects such as soft slide, fog clearing, page turn, curtain reveal, or focus development.

### Quick Editing

In clear mode, the user can quickly:

- check or uncheck a task,
- add a task,
- edit a task,
- edit the main phrase.

The widget should not become visually cluttered. Deep customization stays in settings.

### Settings and Personalization

The user can open a settings panel from a light widget control or menu bar entry.

Settings manage:

- cover mode: image, sticker/meme, or text,
- uploaded cover asset,
- cover text,
- selected built-in pet,
- uploaded pet image,
- pet position on the widget edge,
- widget transparency,
- blur strength,
- theme/accent choices,
- main phrase,
- private note,
- task list content if needed.

### Restart Restore

When the app closes, relaunches, or the Mac restarts, the app restores:

- widget position,
- blurred/clear state,
- main phrase,
- private note,
- tasks,
- completed task states,
- selected cover,
- selected pet,
- uploaded assets,
- visual settings.

## 5. Visual and Personalization Design

### Widget Body

- Transparent frosted-glass material.
- Subtle border.
- Light shadow.
- Moderate rounded corners.
- Calm neutral palette.
- Not a heavy opaque card.

### Color Direction

Base colors should lean toward mist white, silver gray, pale blue-gray, and soft warm gray. Accent colors can exist but should stay restrained and low-saturation.

### Typography

- Main phrase can feel more editorial and expressive.
- To-do text should stay practical and readable.
- Private note should feel softer and more intimate.

### Blur Cover

The blur cover is a personalized display layer, not only a privacy mask. It supports a centered visual or text element and should look intentional when content is hidden.

### Desktop Pet / Personal Character

The pet or character is always clear. It should attach to the widget edge, such as the top edge, top-right corner, or bottom edge. V1 pets are static. Future versions can add animation, idle states, and interactions.

## 6. Product Structure

### Desktop Widget Window

Responsibilities:

- render the main widget,
- render blurred cover and clear content states,
- keep pet clear and attached to the edge,
- handle click-to-toggle,
- support lightweight inline editing,
- preserve a calm desktop presentation.

### Settings Panel

Responsibilities:

- manage cover settings,
- manage pet selection and uploads,
- manage visual settings,
- manage deeper text and task edits,
- avoid cluttering the desktop widget.

### Local Data and Asset Storage

Responsibilities:

- store task data,
- store phrase and note data,
- store widget state and position,
- store selected theme values,
- store uploaded cover and pet assets locally.

All V1 data stays on the user's Mac. No account or network sync is required.

### Theme / Style System

Responsibilities:

- manage blur strength,
- manage transparency,
- manage radius, border, shadow, and accent values,
- support future templates without hard-coding every visual choice into one component.

## 7. Data Model Requirements

The V1 data model should include:

- widget state:
  - id,
  - position,
  - size,
  - isBlurred,
  - theme settings,
  - cover settings,
  - pet settings.
- content:
  - main phrase,
  - private note,
  - task list.
- task:
  - id,
  - text,
  - completed,
  - createdAt,
  - updatedAt.
- assets:
  - id,
  - type,
  - local path,
  - display metadata.

Even though V1 only ships one widget, the data should not assume there can only ever be one widget.

## 8. Error Handling

V1 should handle these cases gracefully:

- Uploaded image is too large or unsupported.
- Uploaded asset is missing after being moved or deleted.
- Local storage read/write fails.
- Saved widget position is outside the visible screen after monitor changes.
- User deletes all tasks.
- User leaves main phrase or private note empty.

Expected behavior:

- Use a default fallback asset when user assets are missing.
- Clamp widget position back into the visible screen.
- Show calm empty states instead of errors in the widget.
- Keep technical error details out of the main desktop experience.

## 9. Testing and Acceptance

V1 acceptance criteria:

1. The user can see one low-distraction frosted-glass widget on the macOS desktop.
2. The widget defaults to blurred cover mode.
3. The cover can show a configured image, sticker/meme, or text.
4. Clicking the widget body reveals internal content.
5. Clicking the widget body again returns to blurred cover mode.
6. The desktop pet remains clear in both blurred and clear states.
7. The user can create, edit, complete, and delete tasks.
8. The user can edit the main phrase and private note.
9. The user can choose a built-in pet or upload a custom character image.
10. The user can upload or configure cover content.
11. The app restores content, position, blur state, and assets after restart.
12. All data remains local.
13. The visual result matches “cool refined base + cute personal accent.”

## 10. Future Directions

Potential future versions may include:

- multiple desktop widgets,
- animated desktop pets,
- pet idle states and interactions,
- automatic privacy modes for screen sharing,
- additional cover reveal and hide animation styles,
- import/export,
- iCloud or account-based sync,
- template packs,
- paid themes,
- App Store packaging and distribution,
- Windows support.
