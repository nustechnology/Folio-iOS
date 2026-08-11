# Architecture and Feature Organization

## Project shape

Folio is a native SwiftUI application using Swift 5, Combine observation, Swift Concurrency, manual dependency injection, and no external dependencies. The current code is arranged as follows:

```text
Folio/
├── FolioApp.swift                         # app entry point and root composition
├── App/AppDIContainer.swift               # lazy dependency graph
├── Configuration/                         # API configuration from build settings
├── Domain/
│   ├── Entities/                          # app business models and queries
│   ├── RepositoryProtocols/               # data contracts
│   └── UseCases/                          # use-case protocols and implementations
├── Data/
│   ├── DTOs/                              # Codable transport types and mappers
│   ├── DataSources/{Local,Remote}/        # storage, endpoints, network/SSE services
│   └── Repositories/                      # protocol implementations
├── Presentation/
│   ├── Common/                            # shared UI, tokens, extensions, protocols
│   └── Scenes/Main/                       # app shell and current feature UI
├── Resources/                             # string catalog and bundled fonts
└── Utils/                                 # Logger, Validator, JWT, storage keys
```

The project currently groups all active product features beneath `Presentation/Scenes/Main`, with focused subfolders for Workspace and FolioNote views. Keep feature-only views, models, and view models with their scene. Promote code to `Presentation/Common` only after it is demonstrably shared by multiple features.

## Dependency direction

```text
Presentation  →  Domain  ←  Data
                   ↑
              AppDIContainer wires implementations
```

- `Domain` defines entities, query/result models, repository protocols, and use cases. It does not depend on `Data`, `Presentation`, or SwiftUI.
- `Data` implements Domain repository protocols. DTOs convert between transport payloads and Domain models through explicit mapping methods; endpoints define request details.
- `Presentation` consumes Domain use cases or repository protocols already supplied by composition. Views must not use DTOs or network services directly.
- `AppDIContainer` owns lazy, concrete wiring. Add a new dependency there only when the feature needs it from the composition root. Use constructor injection and inject protocol-typed values (`any SomeUseCaseProtocol`) at boundaries.

Follow the existing feature flow for new server-backed work:

1. Add or extend a Domain entity/query/result and repository protocol.
2. Add a focused use-case protocol plus `final` implementation unless the existing feature deliberately uses its repository directly.
3. Add DTOs and a remote endpoint/data source in `Data`; map to Domain models in the repository.
4. Register the concrete repository/use case in `AppDIContainer`.
5. Inject it into the relevant view model and bind it from the SwiftUI view.
6. Add boundary-level tests using the patterns in [testing-validation.md](testing-validation.md).

Do not create a new dependency-injection framework, a generic repository layer, or a parallel architecture for one feature.

## State and navigation

`MainView` is the root SwiftUI coordinator. Authentication gates the application shell, while root navigation is represented by `MainViewModel.State` (`selectedTab`, source mode, and active reader) plus view-owned presentation state such as sheets and the selected workspace.

Current feature view models keep a nested `State` type and publish it with `@Published private(set)`. They are `@MainActor` and run asynchronous operations in `Task` blocks. The codebase has two public-command styles:

- `ViewModelProtocol` view models expose an `Action` enum and `handle(_:)` (`MainViewModel`, `FolioAddSourceViewModel`).
- List view models expose an intent enum and `send(_:)` (`WorkspaceListViewModel`, `SourceListViewModel`, `NoteListViewModel`).

For a change to an existing feature, retain that feature's established command style. For a genuinely new view model, `CLAUDE.md` requires `ViewModelProtocol`; do not use the mixed style as a reason to refactor existing view models.

State models explicitly track loading, empty/error content states, sheets/confirmations, mutation errors, pagination, and toasts. Preserve this approach rather than adding an unstructured collection of view booleans. Use request generations, task cancellation, and in-flight guards when user actions can overlap with search, refresh, pagination, sign-out, or mutations.

`ViewState<T>` exists for `.idle`, `.loading`, `.loaded`, and `.error` flows, but current list features instead use feature-specific `ContentState` types. Match the analogous feature rather than forcing either representation everywhere.

## Networking, storage, and errors

- `APIEndpoint` defines path, method, query, body, headers, authentication, content type, cache policy, and retry behavior. Define feature endpoints close to their API type (`WorkspaceEndpoint`, `SourceEndpoint`, `NoteEndpoint`).
- `NetworkService` owns URL construction, HTTPS enforcement, auth headers, response decoding, retry policy, redirect restrictions, token refresh, and circuit breaking. Do not duplicate this behavior in a repository or view model.
- GET endpoints retry transient failures by default. Mutations do not retry automatically unless an endpoint explicitly opts in.
- Authenticated endpoints set `requiresAuthentication`; `NetworkService` adds the bearer token and refreshes it once after a qualifying 401.
- Source processing uses `SourceStatusSSEClient` and `AsyncThrowingStream`. Cancel the stream task on dismissal, deletion, or completion.
- `UserDefaultsStorage` is the local storage implementation. Use `LocalStorageProtocol` and `StorageKey` for durable app state. Do not access `UserDefaults` directly from a view.
- Repositories convert DTOs at the Data boundary and return Domain entities. Never leak DTOs to Presentation.

Surface failures in feature state: inline field/mutation errors where the user can correct input, content error states for initial loads, pagination errors for load-more failures, and `ToastMessage` for transient feedback. Preserve the source error when it is appropriate; use an existing localized fallback for user-facing network failures.

## Logging and configuration

Use `Logger.debug` for diagnostic events and `Logger.error` for failures. It records source location and keeps debug logs behind `#if DEBUG`; do not add ad-hoc `print` calls. Avoid logging credentials, refresh/access tokens, or sensitive source content.

`AppConfiguration.apiBaseURL` reads `API_BASE_URL` from the built Info.plist configuration. API URLs must use HTTPS. Do not hard-code environment URLs in features or commit secrets.
