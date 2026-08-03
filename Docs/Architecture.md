# Folio iOS Architecture

Folio uses Clean Architecture with MVVM and manual dependency injection.

```text
Presentation → Domain ← Data
```

## Responsibilities

- `Domain`: entities, repository protocols, and use cases. It must not import
  SwiftUI, Combine, Data, or Presentation.
- `Data`: DTOs, network/local data sources, and repository implementations.
- `Presentation`: SwiftUI views, view models, shared components, and design
  system code.
- `App`: composition root. `AppDIContainer` wires Data implementations into
  Domain use cases and Presentation view models.

## Feature boundaries

Keep feature-specific views, view models, and presentation models together
under `Folio/Presentation/Scenes/<Feature>`. Shared UI belongs in
`Folio/Presentation/Common`.

Repository protocols live in `Domain/RepositoryProtocols`; implementations
live in `Data/Repositories`. Views and view models consume use cases, never
`NetworkService` or DTOs directly.

## Dependency injection

Use constructor injection. Register dependencies as lazy properties in
`AppDIContainer`. Do not introduce a third-party DI framework without an
explicit architecture decision.

## Async and state

View models are `@MainActor`, expose an immutable published state, and perform
async work with Swift Concurrency. User-facing copy belongs in
`Folio/Resources/Localizable.xcstrings`.
