# Folio

iOS application built with **Clean Architecture + MVVM** using SwiftUI.

## Architecture

```
Folio/
├── App/                    # DI Container (composition root)
├── Domain/
│   ├── Entities/           # Business models
│   ├── RepositoryProtocols/# Repository abstractions
│   └── UseCases/           # Business logic
├── Data/
│   ├── DataSources/        # Remote (API) & Local (UserDefaults)
│   ├── DTOs/               # Data Transfer Objects
│   └── Repositories/       # Repository implementations
├── Presentation/
│   ├── Common/             # Shared UI components & utilities
│   └── Scenes/             # Feature modules (Views + ViewModels)
├── Configuration/          # Environment config
├── Resources/              # Assets, localization
└── Utils/                  # Helpers (Logger)
```

## Tech Stack

- **Swift 5.0** / **SwiftUI** / **Combine**
- iOS 26.5+
- Zero external dependencies

## Configuration

Build configurations are managed via `.xcconfig` files:

| Config | API Base URL | Bundle ID |
|--------|-------------|-----------|
| Debug | folio.nustechnology.com | `com.nustechnology.Folio` |
| Release | folio.nustechnology.com | `com.nustechnology.Folio` |

## Localization

Supported languages: English (`en`), Vietnamese (`vi`)

String catalog: `Folio/Resources/Localizable.xcstrings`

## Getting Started

1. Open `Folio.xcodeproj` in Xcode 26.5+
2. Select scheme **Folio**
3. Build & Run (`⌘R`)

## Code style

Formatting and import-order rules are defined in `.swiftlint.yml`.

`API_BASE_URL` must be an explicit HTTPS URL in the active `.xcconfig` file.
The application fails fast when the value is missing or invalid; it never falls
back to an embedded development endpoint.
