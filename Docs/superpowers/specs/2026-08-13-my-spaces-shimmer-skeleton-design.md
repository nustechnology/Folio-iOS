# My Spaces Shimmer Skeleton

## Scope

Replace the initial loading spinner in My Spaces with five animated skeleton cards. This applies only to `WorkspaceListView`; Sources and Notes loading behavior remains unchanged.

## User Experience

While the first workspace request is loading and no workspace data is available, show five placeholder cards shaped like `WorkspaceCard`. Each card includes placeholder shapes for the initial, name, updated date, objective, divider, and source/note count areas. A light gradient highlight moves horizontally across each card to communicate loading.

When existing workspaces are present during refresh or pagination, keep showing the real content and existing progress indicators. Errors still use the existing error state.

## Implementation

Add a reusable SwiftUI `shimmer` view modifier in `Presentation/Common/Extensions`, implemented with a repeating linear-gradient animation and no external dependencies. Add a feature-specific `WorkspaceCardSkeleton` beside the workspace list view. Render a scrollable vertical stack of five skeleton cards when `contentState` is `.loading`.

Use existing `FolioTheme`, `FolioRadius`, `FolioSpacing`, and `FolioSize` tokens. Preserve the existing workspace card spacing, padding, border, and warm color palette.

## Verification

- Build the Folio Debug scheme with code signing disabled.
- Run the complete iOS Simulator test suite with code signing disabled.
- Confirm the skeleton appears only during initial My Spaces loading and that real cards replace it after the request completes.
