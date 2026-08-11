# My Spaces Shimmer Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the initial My Spaces spinner with five animated workspace-card skeletons using a reusable SwiftUI shimmer modifier.

**Architecture:** Add a small reusable `View` extension for the animated gradient shimmer. Keep the workspace skeleton feature-specific beside `WorkspaceListView`, and render it only when the existing ViewModel reports initial loading with no data. No ViewModel or networking changes are needed.

**Tech Stack:** Swift 5, SwiftUI, iOS 26.5+, Xcode 26.6+, Apple frameworks only.

## Global Constraints

- Apply the change only to My Spaces (`WorkspaceListView`).
- Sources and Notes loading behavior remains unchanged.
- Use existing `FolioTheme`, `FolioRadius`, `FolioSpacing`, and `FolioSize` tokens.
- Add no external dependencies.
- Keep real workspace cards visible during refresh when data already exists.
- Do not commit unless explicitly requested.

---

### Task 1: Add Shimmer Modifier and Workspace Skeleton

**Files:**
- Create: `Folio/Presentation/Common/Extensions/View+Shimmer.swift`
- Modify: `Folio/Presentation/Scenes/Main/Views/Workspace/WorkspaceListView.swift:125-174`

**Interfaces:**
- Consumes: Existing `WorkspaceListView.content`, Folio design tokens, and SwiftUI animation APIs.
- Produces: `View.shimmer()` and a `WorkspaceCardSkeleton` used for five initial-loading placeholders.

- [ ] **Step 1: Add the reusable shimmer modifier**

Create a `View` extension with an animated overlay. The overlay should use a repeating `LinearGradient` that starts offscreen, moves across the view, and does not intercept touches:

```swift
extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
```

Keep the animation self-contained with `@State` and `.onAppear`; use existing color tokens for the base and highlight colors.

- [ ] **Step 2: Add the workspace skeleton card**

Add a private `WorkspaceCardSkeleton` view in `WorkspaceListView.swift` with the same outer padding, background, border, corner radius, and approximate vertical structure as `WorkspaceCard`. Use rounded rectangles for the 36-point initial, title, timestamp, objective lines, divider, and count line. Apply `.shimmer()` to the card content.

- [ ] **Step 3: Replace only the initial spinner**

Change the `.loading` branch from `ProgressView()` to a `ScrollView` containing five `WorkspaceCardSkeleton` instances with the same 12-point vertical spacing and 18-point padding used by the loaded workspace list. Leave `.error`, `.empty`, `.noSearchResults`, and `.loaded` unchanged.

- [ ] **Step 4: Build without signing**

Run:

```bash
xcodebuild -project Folio.xcodeproj -scheme Folio -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Run the full simulator test suite**

Run:

```bash
xcodebuild -project Folio.xcodeproj -scheme Folio -configuration Debug test CODE_SIGNING_ALLOWED=NO -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Check the focused diff**

Run:

```bash
git diff --check
git diff -- Folio/Presentation/Common/Extensions/View+Shimmer.swift Folio/Presentation/Scenes/Main/Views/Workspace/WorkspaceListView.swift
```

Verify only the shimmer extension and My Spaces initial loading UI changed; do not revert unrelated worktree modifications.
