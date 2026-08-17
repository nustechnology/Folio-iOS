# Folio iOS

Native iOS client for Folio — private research, grounded answers. Sources, notes, and citations in one private archive.

**Bundle ID:** `com.nustechnology.Folio`

## Tech Stack

- **Language:** Swift 5.0
- **UI:** SwiftUI + Combine (`@Published`, `ObservableObject`)
- **Architecture:** Clean Architecture + MVVM — dependency flow: **Presentation → Domain ← Data**
- **DI:** Manual `AppDIContainer` in `FolioApp` (no Swinject/Resolver yet)
- **Async:** Swift Concurrency (`async/await`, `@MainActor`)
- **Min Deployment Target:** iOS 26.5 | **Xcode:** 26.6+
- **Dependencies:** Zero external dependencies (Apple frameworks only: SwiftUI, Foundation, Combine)

## Project Structure

```text
Folio/
├── FolioApp.swift              # @main entry point, creates AppDIContainer
├── App/
│   └── AppDIContainer.swift    # Composition root, lazy dependency wiring
├── Configuration/
│   └── AppConfiguration.swift  # Reads API_BASE_URL from Info.plist
├── Domain/
│   ├── Entities/               # Business models (structs)
│   ├── RepositoryProtocols/    # Repository abstractions (protocols)
│   └── UseCases/               # Business logic (protocol + final class)
├── Data/
│   ├── DataSources/
│   │   ├── Local/              # LocalStorageProtocol, UserDefaultsStorage
│   │   └── Remote/             # NetworkServiceProtocol, NetworkService, APIEndpoint
│   ├── DTOs/                   # Codable data transfer objects with toDomain()
│   └── Repositories/           # Repository implementations (conform to domain protocols)
├── Presentation/
│   ├── Common/
│   │   ├── Components/         # ErrorView, LoadingView
│   │   ├── Extensions/         # View+Extensions
│   │   ├── Protocols/          # ViewModelProtocol
│   │   └── ViewState.swift     # Generic ViewState<T> enum
│   └── Scenes/                 # Feature modules (Views + ViewModels per scene)
├── Resources/                  # Localizable.xcstrings, Assets.xcassets
└── Utils/                      # Logger
```

**Dependency flow:** Presentation → Domain ← Data (outer layers depend inward; Domain is the center).

| Layer | May depend on | Must not depend on |
|-------|---------------|-------------------|
| `Presentation` | `Domain` | `Data` |
| `Domain` | nothing in `Data` or `Presentation` | `Data`, `Presentation`, SwiftUI/Combine |
| `Data` | `Domain` | `Presentation` |

Repository **protocols** live in `Domain`; **implementations** live in `Data`.

## Architecture Conventions

### DI

- `FolioApp` creates `AppDIContainer` as a `private let`
- `AppDIContainer` uses `lazy var` for all dependencies
- Dependencies injected via constructor injection in views and view models

```swift
// FolioApp.swift
@main
struct FolioApp: App {
    private let diContainer = AppDIContainer()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: MainViewModel(
                fetchUsersUseCase: diContainer.fetchUsersUseCase,
                localStorage: diContainer.localStorage
            ))
        }
    }
}
```

### ViewModel Pattern

- Conforms to `ViewModelProtocol` (has `State`, `Action`, `handle(_:)`)
- `@MainActor` class + `ObservableObject` + `@Published` state
- `ViewState<T>` enum: `.idle`, `.loading`, `.loaded(T)`, `.error(String)`
- View defines its own `Action` enum; ViewModel exposes `handle(_ action:)` method
- Concurrency via `async/await` (not Combine publishers for async work)

```swift
@MainActor
final class MainViewModel: ViewModelProtocol {
    struct State: Equatable {
        var isAuthenticated = false
        var selectedTab: FolioTab = .sources
        var sourcesMode: FolioSourcesMode = .spaces
        // ... additional state fields
    }

    @Published private(set) var state: State = .init()
    private let fetchUsersUseCase: any FetchUsersUseCaseProtocol
    private let localStorage: LocalStorageProtocol

    init(fetchUsersUseCase: any FetchUsersUseCaseProtocol, localStorage: LocalStorageProtocol) { ... }

    func handle(_ action: Action) {
        switch action {
        case .onAppear: checkSession(); if state.isAuthenticated { Task { await loadUsers() } }
        case .signIn(let credential): /* authenticate, save session, navigate */
        case .signOut: /* clear session, reset state */
        // ... additional actions
        }
    }
}
```

### Use Cases

- Each use case has a **protocol** and a `final class` implementation
- Single responsibility, uses `async throws` return
- Registered in `AppDIContainer` as `lazy var` properties
- Typed as `any Protocol` (existential) when injected

### Views

- `struct MainView: View` with internal `enum Action`
- `@StateObject var viewModel` to own the ViewModel
- Switches on `viewModel.state` to render `.idle` / `.loading` / `.loaded` / `.error`
- `.task { viewModel.handle(.onAppear) }` for initial load
- `.refreshable { viewModel.handle(.refresh) }` for pull-to-refresh
- Previews construct real dependencies inline (no mocks required since using JSONPlaceholder)

### Networking

- `NetworkServiceProtocol.request(_ endpoint: APIEndpoint) -> T` (async throws, generic)
- `APIEndpoint` protocol: `path`, `method` (GET/POST/PUT/DELETE/PATCH), `queryItems`, `body`
- `NetworkError` enum: `invalidURL`, `invalidResponse`, `httpError(statusCode:)`, `decodingError(Error)`
- `JSONDecoder` with `keyDecodingStrategy = .convertFromSnakeCase`
- Environment-specific base URL from `.xcconfig` → `Info.plist` → `AppConfiguration`

### Local Storage

- `LocalStorageProtocol`: generic `save`, `load`, `remove`, `clear`
- `UserDefaultsStorage` uses `JSONEncoder`/`JSONDecoder` with `UserDefaults`
- Repository caches data after successful fetch

### Localization

- String catalog: `Folio/Resources/Localizable.xcstrings`
- Supported: English (`en`), Vietnamese (`vi`)
- User-facing strings must go in `.xcstrings`, never hardcoded
- When adding new strings manually, append them at the end of the `strings` object instead of inserting alphabetically — this keeps additions conflict-free when two branches add strings at the same time

## Build Configuration

| Config | API Base URL | Display Name | Bundle ID |
|--------|-------------|-------------|-----------|
| Debug | shale-crowd-satin.ngrok-free.dev | Folio Dev | `com.nustechnology.Folio` |
| Release | shale-crowd-satin.ngrok-free.dev | Folio | `com.nustechnology.Folio` |

Config files in `Configuration/`:
- `Shared.xcconfig` — deployment target
- `Debug.xcconfig` / `Release.xcconfig` — `INFOPLIST_KEY_*` values

## Build, Test & Run

```bash
# Build
xcodebuild -project Folio.xcodeproj -scheme Folio -configuration Debug build

# Unit tests
xcodebuild -project Folio.xcodeproj -scheme Folio -configuration Debug test

# Or: open Folio.xcodeproj → ⌘R to run, ⌘U to test
```

## Guidelines

- Minimize scope — match existing patterns, no unrelated changes
- No over-engineering — avoid abstractions for one-off use
- No new dependencies without discussion (currently zero external deps)
- Respect dependency flow: Presentation → Domain ← Data; never import `Data` from `Presentation` or `Presentation` from `Data`
- Do not add Swinject/Resolver/Any DI framework without explicit request
- Do not hardcode user-facing strings in SwiftUI views — use `Localizable.xcstrings`
- Do not commit `.xcuserdata` or secrets
- Only create git commits when explicitly asked

## Coding Rules

### ViewModel Protocol Conformance

- Every ViewModel must conform to `ViewModelProtocol`.
- ViewModelProtocol defines `State`, `Action`, and `handle(_:)` — every ViewModel implements these.
- Do not create a ViewModel that does not conform to ViewModelProtocol.

### Reuse and Component Design

- Reuse existing shared components, extensions, design tokens, and modifiers before creating a new implementation.
- Search `Presentation/Common` and the current feature module before adding a new view, control, validation helper, or formatting utility.
- Extract a component when a UI pattern is repeated, has a clear responsibility, or needs isolated testing; do not extract one-off markup only to make a file shorter.
- Keep reusable components generic enough for their known use cases, but do not add speculative configuration or abstractions.
- Prefer composition of small views over deeply nested, duplicated SwiftUI markup.
- Put feature-specific UI in the feature scene. Promote it to `Presentation/Common` only when it is genuinely shared by multiple features.

### Localization and Design System

- Every user-facing string, including validation and error text, belongs in Folio/Resources/Localizable.xcstrings
- Never ship debug or placeholder production UI text such as "TODO" — even if it is localized — without a ticket; keep all user-facing strings in `Folio/Resources/Localizable.xcstrings`
- Reuse `FolioTheme` and shared components before adding feature-specific colors, typography, spacing, or controls.

### Naming, Constants, and Readability

- Use descriptive names that communicate intent and units. Prefer `maximumNameLength`, `pageSize`, and `requestTimeout` over `max`, `size`, or unexplained numeric literals.
- Define reusable constants in a clearly named scope, such as a private `Constants` namespace/type or a feature-specific constants structure.
- Do not scatter magic numbers, repeated user-facing strings, API paths, storage keys, or animation durations through implementation code.
- Name constants according to what they represent, not how they are currently used. For example, use `maximumPageSize` rather than `value1` or `defaultValue`.
- Keep constants close to the feature that owns them. Promote a constant to a shared location only when multiple features use the same concept.
- Use Swift naming conventions: types and protocols in `UpperCamelCase`, properties/functions/actions in `lowerCamelCase`, and Boolean names that read naturally such as `isLoading`, `hasMorePages`, or `canSubmit`.
- Avoid vague names such as `data`, `result`, `item`, `manager`, `helper`, or `process` when a domain-specific name is available.
- Prefer small, intention-revealing functions. Split a function when it mixes validation, state mutation, networking, navigation, or formatting responsibilities.
- Keep conditionals readable. Extract a named computed property or helper when a condition needs more than one line to understand.

## Adding a New Feature

Follow dependency direction: define contracts in `Domain` first, implement in `Data`, consume from `Presentation`.

1. **Domain:** Entity → Repository protocol → Use case (protocol + class)
2. **Data:** DTO (with `toDomain()`) → DataSource or Endpoint → Repository impl
3. **DI:** Wire in `AppDIContainer` (data impl → use case protocol → view model)
4. **Presentation:** ViewModel (+ Action handling) → View (with ViewState switching)
5. Wire the new View + ViewModel in `FolioApp`

## Reference Files

| Purpose | File |
|---------|------|
| Entry point + DI setup | `FolioApp.swift`, `App/AppDIContainer.swift` |
| View + ViewModel | `Presentation/Scenes/Main/Views/MainView.swift`, `ViewModels/MainViewModel.swift` |
| Use case | `Domain/UseCases/FetchUsersUseCase.swift` |
| Repository protocol | `Domain/RepositoryProtocols/` |
| Repository impl | `Data/Repositories/` |
| Network layer | `Data/DataSources/Remote/NetworkService.swift` |
| Design tokens | `FolioTheme` (`Presentation/Common/DesignSystem/FolioTheme.swift`) for colors, `FolioDuration` for animation timings |
| Strings | `Resources/Localizable.xcstrings` |
| Common patterns | `Presentation/Common/` (ViewState, ViewModelProtocol) |
