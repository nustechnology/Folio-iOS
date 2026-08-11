# UI Design System and Reusable Components

## Visual language

The current app uses a warm paper/canvas background, deep olive ink and navigation surfaces, muted brown text, gold accents, and restrained success/warning/danger states. The primary visual reference is `Folio/Presentation/Common/DesignSystem/FolioTheme.swift`.

Use these existing token families before adding a value:

| Need | Token family | Examples |
| --- | --- | --- |
| Color | `FolioTheme` or `Color.folio…` aliases | `canvas`, `surface`, `ink`, `olive`, `gold`, `danger`, feature-specific `home…` / `login…` values |
| Corner radius | `FolioRadius` | `xs` (4), `sm` (8), `lg` (12), `chip` (20), `tabBar` (28) |
| Spacing | `FolioSpacing` | `xs` (4) through `xl6` (32) |
| Sizes / touch targets | `FolioSize` | icons, fields, cards, `tapTarget` (44) |
| Type scale | `FolioFontSize` | caption through display sizes |
| Animation / transient timing | `FolioDuration` | `fast`, `normal`, toast dismissal |

Use the bundled Cormorant Garamond font where the established screens use their serif brand treatment; follow the adjacent component's font weight and role. Do not introduce a font, palette, shadow system, spacing scale, or icon library without an explicit design decision.

`FolioBackdrop` is the shared application background. Keep a scene on the established background unless the feature explicitly needs a different surface.

## Shared components: reuse first

Search `Folio/Presentation/Common/Components` before writing SwiftUI controls.

| Component | Use it for |
| --- | --- |
| `FolioCard` | Bordered, rounded surface content such as cards and grouped panels |
| `FolioPrimaryButton` | Main affirmative/submit action |
| `FolioSecondaryButton` | Secondary or neutral action |
| `FolioDangerButton` | Destructive confirmation/action |
| `FolioTextField` | Labeled field, optional validation error, character cap, and matching field chrome |
| `FolioSearchField` / `FolioSearchHeader` | Search input and screen header/search/sort chrome |
| `FolioPill` | Compact selectable filter/chip UI |
| `FolioStatusBadge` / `FolioKindBadge` | Source status/type presentation |
| `FolioCheckboxRow` | Checkbox-style selection/control rows |
| `FolioEmptyStateView` | Empty-state illustration/message/action layout |
| `FolioBackButton` | Standard back affordance |
| `FolioTopBar` / `FolioBottomTabBar` / `FolioLogoMark` | Shared app chrome and navigation |
| `FolioDynamicSheet` | Sheets that measure their content and use the project’s presentation behavior |
| `ToastView` / `.folioToast` | Success/error transient feedback using `ToastMessage` |
| `LoadingView` / `ErrorView` | Generic loading/error display where their simple shape suits the feature |
| `AccountBottomSheet`, `SortOptionsSheet` | Their specific account/sort presentation flows |

Use feature-specific components such as `WorkspaceCard`, `NoteRow`, and source processing views inside their feature. Promote a feature view to Common only after it has two or more real consumers with the same responsibility.

## SwiftUI composition rules

- Prefer small private `@ViewBuilder` sections and focused subviews over repeated nested markup.
- Bind controls to published state and route mutations through the owning view model. Do not perform a network call in a view closure.
- Use `.sheet`, `.fullScreenCover`, alerts, and confirmation dialogs with explicit presentation state, as the Workspace, Source, and Note flows do.
- Use `FolioDynamicSheet` when the new sheet needs its current dynamic-height behavior; otherwise match the closest existing sheet's presentation detents.
- For icon-only controls, use the established SF Symbol approach and add a localized accessibility label; add a hint when the action is not obvious.
- Preserve the standard 44-point `FolioSize.tapTarget` for interactive controls when the shared component does not already provide it.

## Design-system guardrails

- Never add a raw hex color or duration value. Always use the applicable Folio token (`FolioTheme` / `Color.folio…`, `FolioDuration`).
- When no token covers a repeated, established visual need, add the token to the correct family in `FolioTheme.swift` only as part of the scoped design change. Do not add a token for a single accidental value.
- Use semantic colors (`danger`, `success`, `inkMuted`) rather than selecting values by appearance alone.
- Reuse `FolioControls` before duplicating borders, fills, labels, character counters, disabled states, or button styles.
- Keep user-visible text localized, including accessibility strings.

## Known legacy deviations

Several older views contain literal `.font(.system(size: …))`, `.padding(...)`, and hard-coded text or colors. They are not design-system precedent. New code must use `FolioTheme` for colors, `FolioDuration` for timings, and prefer components from `FolioControls` where available, while leaving unrelated legacy code unchanged.
