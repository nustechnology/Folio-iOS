# Testing and Validation

## Current test organization

Folio has an XCTest unit-test target, `FolioTests`. Its current organization is boundary-oriented:

```text
FolioTests/
├── Data/          # endpoints, repositories, network resilience/auth behavior
├── Presentation/  # view-model state, pagination, mutation, validation behavior
└── Support/        # URLProtocolStub and reusable test support
```

Existing tests cover more than simple happy paths. Preserve their emphasis on async correctness: cancellation, token refresh, retry/circuit-breaker behavior, pagination, search debounce, stale list responses after mutations, sheet transitions, and validation limits.

## Test patterns to follow

### Domain and data

- Test an endpoint's path, method, authentication, query items, and body for every new API behavior. See `NoteEndpointTests` and `NetworkServiceTests`.
- Give repositories a small `NetworkServiceProtocol` fake/recording implementation and assert DTO-to-Domain mapping. See `NoteRepositoryTests` and `RemoteWorkspaceRepositoryTests`.
- Use `URLProtocol` stubs for real `URLSession` behavior such as headers, retries, status codes, token refresh, and circuit breaker behavior. Reuse `FolioTests/Support/URLProtocolStub.swift` or the local test pattern in `NetworkResilienceTests`.
- Keep remote API behavior behind `NetworkService`; do not make live network calls in unit tests.

### Presentation

- Construct view models with protocol fakes/recording use cases and assert observable state transitions rather than view implementation details.
- Mark asynchronous view-model tests `async` and await the action/state boundary required by the behavior.
- Add a regression test whenever a new mutation can race with refresh, paging, search debounce, or a session transition. The existing workspace/source/note tests demonstrate generation and cancellation behavior to preserve.
- Test validation behavior at the view-model or draft model boundary, including whitespace-only input, length limits, disabled submission, and failure-state preservation.
- Keep fakes narrowly scoped in the test file unless two or more tests need a shared support utility.

Name tests for observable behavior, for example `testStaleListResponseDoesNotOverwriteEdit` and `testAuthenticatedRequestAddsBearerToken`. One test should prove one behavior.

## Required validation after code changes

Run the narrowest relevant check while iterating, then run the complete suite before handoff when environment support permits:

```bash
# Style checks
swiftlint lint --config .swiftlint.yml
swiftlint lint --strict --config .swiftlint.yml

# Complete unit-test target
xcodebuild -project Folio.xcodeproj -scheme Folio -configuration Debug test

# Build when the change affects app compilation, resources, or target wiring
xcodebuild -project Folio.xcodeproj -scheme Folio -configuration Debug build

# Final whitespace and scope review
git diff --check
git diff --stat
git diff -- Folio FolioTests Docs
```

If the environment cannot run Xcode or SwiftLint, run every available check and state exactly what was unavailable and why. Do not replace a failed build/test with a claim that the code is likely correct.

## Agent completion checklist

Before reporting a change as complete, verify:

- The implementation reuses an existing component, token, extension, helper, protocol, or test pattern where one exists.
- Presentation has not imported or directly used Data/DTO types.
- New user-visible copy and accessibility labels/hints are in `Localizable.xcstrings` and were appended per `CLAUDE.md`.
- Errors follow the analogous feature's inline, content, pagination, confirmation, or toast behavior.
- Async work has appropriate cancellation, duplicate-request, and stale-response behavior.
- Tests cover the changed observable behavior and relevant error/race cases.
- The code was formatted; applicable lint, tests, and build commands were executed; their actual results are recorded.
- `git diff --check` is clean and the final diff includes no unrelated changes.

## Documentation-only changes

For changes limited to Markdown, inspect links, scan for incomplete markers, run `git diff --check`, and review the final diff. Do not run unrelated production tests solely to validate a documentation edit, but report whether build/test validation was intentionally not run.
