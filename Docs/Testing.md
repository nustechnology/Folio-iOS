# Testing Guide

The project uses XCTest through the `FolioTests` unit-test target.

## Test layout

```text
FolioTests/
├── Domain/        # use cases and domain rules
├── Data/          # DTOs, endpoints, network, repositories
├── Presentation/  # view model state transitions
└── Support/       # fakes, URLProtocol stubs, and fixtures
```

Tests should verify behavior at architectural boundaries:

- Domain tests use fake repository protocols.
- Data tests use `URLProtocol` stubs or recording network services.
- Presentation tests use fake use cases and assert state transitions.
- UI tests are reserved for critical user journeys and belong in a separate
  `FolioUITests` target when those flows are introduced.

## Naming and scope

Name tests after observable behavior, for example
`testAuthenticatedRequestAddsBearerToken`. Keep each test focused on one
behavior and keep test-only helpers under `FolioTests/Support`.

## Running tests

```bash
xcodebuild -project Folio.xcodeproj -scheme Folio -configuration Debug test
```

Run a focused class from Xcode when iterating, then run the complete scheme
before opening a pull request.
