# Coding Conventions, Naming, and File Placement

## General Swift conventions

- Use four-space indentation and organize imports at the beginning of each file. `Docs/CodeStyle.md` specifies sorted imports and a 120-character target line length (160 is an error threshold).
- Use `UpperCamelCase` for types and protocols, `lowerCamelCase` for functions, properties, enum cases, and parameters.
- Name booleans as predicates (`isLoading`, `hasAppeared`, `canSubmit`) and include units or meaning in constants (`maximumPageSize`, `requestTimeout`).
- Prefer `struct` for value models and SwiftUI views; use `final class` for view models, repositories, and use cases that need identity or observation.
- Mark concurrent Domain transport/value types `Sendable` when their current neighboring models do so. Do not add conformance blindly if stored properties cannot support it.
- Keep functions narrow: separate validation, state mutation, request construction, and presentation decisions when they become difficult to read together.

## File and feature placement

| Responsibility | Location | Existing examples |
| --- | --- | --- |
| Business model, query, pagination result, domain error | `Folio/Domain/Entities/` | `Workspace.swift`, `Note.swift` |
| Repository contract | `Folio/Domain/RepositoryProtocols/` | `NoteRepositoryProtocol.swift` |
| Use-case protocol and implementation | `Folio/Domain/UseCases/` | `FetchSourcesUseCase.swift`, `WorkspaceUseCases.swift` |
| Codable transport model and domain mapper | `Folio/Data/DTOs/` | `SourceDTO.swift`, `NoteDTO.swift` |
| HTTP/SSE endpoint or remote service | `Folio/Data/DataSources/Remote/` | `SourceEndpoint.swift` |
| Repository implementation | `Folio/Data/Repositories/` | `NoteRepository.swift` |
| Shared component/token/extension | `Folio/Presentation/Common/` | `FolioControls.swift`, `FolioTheme.swift` |
| Feature-specific presentation code | `Folio/Presentation/Scenes/<Scene>/` | `Views/FolioNote/`, `ViewModels/` |
| Cross-feature utility | `Folio/Utils/` | `Logger.swift`, `Validator.swift` |
| Unit-test support | `FolioTests/Support/` | `URLProtocolStub.swift` |

Use an established, responsibility-based filename: `WorkspaceEndpoint`, `NoteRepository`, `NoteListViewModel`, `WorkspaceCard`. Do not introduce generic names such as `Manager`, `Helper`, `Utils`, or `Service` when the responsibility can be named directly.

## View-model and async patterns

- Make UI-facing view models `@MainActor` and `ObservableObject`.
- Keep mutable view state in a nested `State` type, expose it with `@Published private(set)`, and communicate user events through the feature's existing action/intent entry point.
- Inject use-case protocols into new view models. Existing `WorkspaceListViewModel` has a convenience initializer from a repository; preserve it when editing that feature rather than broadening a one-off pattern.
- Use `async`/`await`, `Task`, cancellation checks, and `defer` to reset loading/mutation flags. Do not add Combine publisher chains for new asynchronous work.
- Debounce search and protect stale loads with cancellation and request-generation checks, as the list view models do. Prevent duplicate load-more and mutation requests with guards.
- Start initial data work through the existing `.task`/view-model action pattern. Use `.refreshable` for existing list refresh behavior.

## Domain, data, and validation conventions

- Make repository contracts protocol-first in Domain; concrete repositories conform in Data.
- Use `async throws` for remote/storage operations. Make use cases small delegators unless a real business rule belongs there.
- DTOs are `Codable` and map at the Data boundary. Endpoint types own request path/method/query/body details, not views or repositories.
- Keep API strings, storage keys, validation limits, MIME types, and timing constants in named endpoint/feature/constants scopes instead of scattering duplicates.
- Reuse `Validator` for the existing email/password checks. Keep feature-specific form limits next to their view model or editor draft, as source upload and workspace editing do.
- Trim submitted text where its analogous flow trims it; do not silently alter unrelated input behavior.

## Errors and logging

- Use typed Domain errors where a feature already has them (`AuthError`, `WorkspaceRepositoryError`). Otherwise retain `error.localizedDescription` when it accurately reaches the user.
- Write user-visible fallback errors through `String(localized:)` and show them in the feature's existing inline/state/toast mechanism.
- Log operational failures with `Logger.error`; use `Logger.debug` for debug diagnostics. Never log secrets or use raw `print` for app behavior.
- Treat cancellation as normal control flow. Do not show a failure toast for a cancelled request or a stale response.

## Localization

All user-facing copy—buttons, field prompts, errors, confirmation text, accessibility labels/hints, and dynamic messages—belongs in `Folio/Resources/Localizable.xcstrings` and is read with `String(localized:)` or the matching localized SwiftUI API.

## Current inconsistencies: do not copy

These are audit findings, not justification for unrelated refactors:

- View-model conformance and command naming are mixed: `ViewModelProtocol.handle(_:)` and list-model `send(_:)` both exist. Follow the feature you change; new view models must follow `CLAUDE.md`.
- `FolioTheme` and `FolioDuration` tokens must be used for colors and animation timings; never introduce raw hex values or hardcoded durations.
- Most UI copy is localized, but some `Text("...")` values remain. New user-facing text must be localized; do not use legacy literals as precedent.
- `ErrorView` includes a preview-style `print("Retry tapped")`. Production behavior should accept a retry closure and use `Logger` only for diagnostics.
- Some files are already large and hold several visual/state responsibilities. Keep new code focused and extract a cohesive responsibility when it would otherwise expand a large file; do not split unrelated code merely for cleanup.
