# Murmur Component Theme System

## Goal

Replace the current cover-only board styles with a theme system that changes the
entire expanded Murmur component: its frame, material, spacing, typography, and
to-do presentation. The current clean magazine layout remains available.

## Scope

The settings interface replaces the existing cover-style selector with a theme
selector. Cover content remains independent: users can still choose a text or
image cover, while the selected theme determines the surrounding component
presentation.

The first release includes five themes:

| Theme | Visual direction | Custom background |
| --- | --- | --- |
| Magazine | Current clean, editorial layout with generous whitespace and thin rules | Allowed |
| Kraft | Fixed warm brown paper texture with typewriter-inspired type and heavier checks | Not allowed |
| Polaroid | White photo frame, large image area, and lower caption space | Allowed |
| Collage | Light paper canvas with tape and note-like content zones | Allowed |
| Corkboard | Cork texture with photo and note-inspired content blocks | Allowed |

The previous white-paper and newspaper styles are removed. The former glass
style is presented to users as Magazine.

## Behavior

1. A user chooses a theme in Settings under a clear "Theme" section.
2. The widget immediately previews the selected theme in Settings, but the
   saved widget state changes only when the user chooses Save.
3. Themes that support a custom background expose "Change theme background" and
   "Clear theme background" controls. The chosen image fills the theme's
   background area using an aspect-fill crop.
4. Kraft does not expose background replacement controls. Its explanatory copy
   says that it uses a fixed paper texture.
5. Cover text/image, main text, note, and to-do visibility controls continue
   to work as they do today. Theme selection must not alter or delete this
   content.

## Component Layout

Each theme owns a small appearance definition: background rendering, corner
style, padding, primary/secondary text treatment, divider treatment, and to-do
row treatment. The shared content layout remains a single component so all
themes have the same interaction behavior and accessibility hit areas.

The expanded widget width remains 500 points. Themes adapt the content image
area to the available width rather than constraining uploaded images to a small
center square. Polaroid gives the cover image the largest visual area.

## Error Handling

- A missing or unreadable uploaded background falls back to the theme's native
  background without losing the rest of the component.
- Previously saved white-paper or newspaper selections migrate to Magazine.
- Previously saved glass selections migrate to Magazine.

## Verification

For each theme, verify that:

- The selected theme applies to the full expanded component.
- Text, images, to-do toggles, pet position, and settings access still work.
- Custom-background controls appear only for Magazine, Polaroid, Collage, and
  Corkboard.
- Kraft always renders its fixed texture.
- Saving persists the choice after restarting the app; closing Settings without
  saving leaves the widget unchanged.
