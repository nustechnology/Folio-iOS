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
- iOS 17.0+
- Zero external dependencies

## Configuration

Build configurations are managed via `.xcconfig` files:

| Config | API Base URL | Bundle ID |
|--------|-------------|-----------|
| Debug | jsonplaceholder.typicode.com | `com.nustechnology.Folio` |
| Release | jsonplaceholder.typicode.com | `com.nustechnology.Folio` |

## Localization

Supported languages: English (`en`), Vietnamese (`vi`)

String catalog: `Folio/Resources/Localizable.xcstrings`

## Getting Started

1. Open `Folio.xcodeproj` in Xcode 16+
2. Select scheme **Folio**
3. Build & Run (`⌘R`)

## Code style

Formatting and import-order rules are defined in `.swiftlint.yml`. See
[`Docs/CodeStyle.md`](Docs/CodeStyle.md) for installation and lint commands.
