import XCTest
@testable import Folio

@MainActor
final class MainViewModelTests: XCTestCase {
    func testProfileResponseAfterSignOutDoesNotRestoreIdentity() async {
        let fetchMe = DeferredFetchMeUseCase()
        let viewModel = makeViewModel(
            fetchMeUseCase: fetchMe,
            localStorage: SessionLocalStorage(session: validSession())
        )

        viewModel.handle(.onAppear)
        for _ in 0..<10 where !(await fetchMe.hasStarted()) {
            await Task.yield()
        }
        let didStart = await fetchMe.hasStarted()
        XCTAssertTrue(didStart)

        viewModel.handle(.signOut)
        await fetchMe.succeed(with: UserIdentity(name: "Previous User", email: "previous@example.com"))
        await Task.yield()

        XCTAssertFalse(viewModel.state.isAuthenticated)
        XCTAssertNil(viewModel.state.userDisplayName)
        XCTAssertNil(viewModel.state.userEmail)
    }

    func testAuthenticationLoadingStartsBeforeWaitingForRefreshCancellation() async {
        let refreshToken = BlockingRefreshTokenUseCase()
        let viewModel = makeViewModel(
            localStorage: SessionLocalStorage(session: expiredSession()),
            refreshTokenUseCase: refreshToken
        )

        viewModel.handle(.onAppear)
        for _ in 0..<10 where !(await refreshToken.hasStarted()) {
            await Task.yield()
        }

        viewModel.handle(.signIn(email: "test@example.com", password: "password"))
        viewModel.handle(.signIn(email: "test@example.com", password: "password"))
        await waitForAuthLoading(viewModel, toBe: true)

        XCTAssertTrue(viewModel.state.authLoading)

        for _ in 0..<10 where !(await refreshToken.wasCancelled()) {
            await Task.yield()
        }
        let wasCancelled = await refreshToken.wasCancelled()
        XCTAssertTrue(wasCancelled)

        await refreshToken.fail()

        await waitForAuthLoading(viewModel, toBe: false)

        XCTAssertFalse(viewModel.state.authLoading)
    }

    func testSignOutWhileRefreshIsBlockedDoesNotRestoreAuthenticatedState() async {
        let refreshToken = BlockingRefreshTokenUseCase()
        let viewModel = makeViewModel(
            localStorage: SessionLocalStorage(session: expiredSession()),
            refreshTokenUseCase: refreshToken
        )

        viewModel.handle(.onAppear)
        for _ in 0..<10 where !(await refreshToken.hasStarted()) {
            await Task.yield()
        }
        viewModel.handle(.signOut)
        await refreshToken.succeed(with: AuthToken(
            accessToken: "refreshed-access-token",
            refreshToken: "refreshed-refresh-token",
            expiresAt: .distantFuture
        ))

        for _ in 0..<10 {
            await Task.yield()
        }

        XCTAssertFalse(viewModel.state.isAuthenticated)
    }

    func testSignOutFailureKeepsAuthenticatedState() async {
        let viewModel = makeViewModel(
            localStorage: SessionLocalStorage(session: validSession()),
            signOutUseCase: FailingSignOutUseCase()
        )

        viewModel.handle(.onAppear)
        XCTAssertTrue(viewModel.state.isAuthenticated)

        viewModel.handle(.signOut)
        for _ in 0..<10 { await Task.yield() }

        XCTAssertTrue(viewModel.state.isAuthenticated)
        XCTAssertEqual(viewModel.toastMessage, .error(AuthError.sessionRemovalFailed.errorDescription!))
    }

    func testRepeatedSessionChecksStartOnlyOneRefresh() async {
        let refreshToken = BlockingRefreshTokenUseCase()
        let viewModel = makeViewModel(
            localStorage: SessionLocalStorage(session: expiredSession()),
            refreshTokenUseCase: refreshToken
        )

        viewModel.handle(.onAppear)
        for _ in 0..<10 where !(await refreshToken.hasStarted()) {
            await Task.yield()
        }
        viewModel.handle(.onAppear)

        let refreshStartCount = await refreshToken.startCount()
        XCTAssertEqual(refreshStartCount, 1)
        await refreshToken.fail()
    }

    func testVisibleSourcesReturnsOnlySourcesInSelectedWorkspace() {
        let viewModel = makeViewModel()

        let sources = viewModel.visibleSources(inWorkspaceID: "dissertation-research")

        XCTAssertFalse(sources.isEmpty)
        XCTAssertTrue(sources.allSatisfy { $0.workspaceID == "dissertation-research" })
    }

    private func makeViewModel(
        fetchMeUseCase: any FetchMeUseCaseProtocol = EmptyFetchMeUseCase(),
        localStorage: LocalStorageProtocol = EmptyLocalStorage(),
        refreshTokenUseCase: any RefreshTokenUseCaseProtocol = EmptyRefreshTokenUseCase(),
        signOutUseCase: any SignOutUseCaseProtocol = EmptySignOutUseCase()
    ) -> MainViewModel {
        MainViewModel(
            fetchUsersUseCase: EmptyFetchUsersUseCase(),
            fetchMeUseCase: fetchMeUseCase,
            localStorage: localStorage,
            signUpUseCase: EmptySignUpUseCase(),
            signInUseCase: EmptySignInUseCase(),
            signOutUseCase: signOutUseCase,
            refreshTokenUseCase: refreshTokenUseCase,
            fetchWorkspacesUseCase: FetchWorkspacesUseCase(repository: EmptyWorkspaceRepository()),
            createWorkspaceUseCase: CreateWorkspaceUseCase(repository: EmptyWorkspaceRepository()),
            updateWorkspaceUseCase: UpdateWorkspaceUseCase(repository: EmptyWorkspaceRepository()),
            deleteWorkspaceUseCase: DeleteWorkspaceUseCase(repository: EmptyWorkspaceRepository()),
            uploadSourceUseCase: EmptyUploadSourceUseCase(),
            fetchSourcesUseCase: EmptyFetchSourcesUseCase(),
            updateSourceUseCase: EmptyUpdateSourceUseCase(),
            fetchSourceDetailUseCase: EmptyFetchSourceDetailUseCase(),
            fetchSourcePreviewUseCase: EmptyFetchSourcePreviewUseCase(),
            initialSources: [
                source(id: "turing", workspaceID: "dissertation-research"),
                source(id: "arendt", workspaceID: "dissertation-research"),
                source(id: "weapons", workspaceID: "public-policy-insights")
            ]
        )
    }

    private func validSession() -> AuthTokenDTO {
        AuthTokenDTO(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresAt: .distantFuture
        )
    }

    private func expiredSession() -> AuthTokenDTO {
        AuthTokenDTO(
            accessToken: "expired-access-token",
            refreshToken: "refresh-token",
            expiresAt: .distantPast
        )
    }

    private func source(id: String, workspaceID: String) -> FolioSource {
        FolioSource(
            id: id,
            workspaceID: workspaceID,
            kind: .file,
            title: id,
            subtitle: "",
            addedText: "Added just now",
            status: .ready,
            chapterTitle: "",
            chapterText: "",
            calloutText: "",
            citationTitle: "",
            citationDetail: "",
            citationText: "",
            pageLabel: "1 of 1"
        )
    }

    private func waitForAuthLoading(_ viewModel: MainViewModel, toBe expected: Bool) async {
        let deadline = ContinuousClock.now + .seconds(1)
        while viewModel.state.authLoading != expected {
            guard ContinuousClock.now < deadline else {
                XCTFail("Timed out waiting for authLoading to become \(expected)")
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

private struct EmptyFetchUsersUseCase: FetchUsersUseCaseProtocol {
    func execute() async throws -> [User] { [] }
}

private struct EmptyFetchMeUseCase: FetchMeUseCaseProtocol {
    func execute() async throws -> UserIdentity {
        UserIdentity(name: "Test User", email: "test@example.com")
    }
}

private actor DeferredFetchMeUseCase: FetchMeUseCaseProtocol {
    private var continuation: CheckedContinuation<UserIdentity, Error>?
    private var started = false

    func execute() async throws -> UserIdentity {
        started = true
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func hasStarted() -> Bool {
        started
    }

    func succeed(with identity: UserIdentity) {
        continuation?.resume(returning: identity)
        continuation = nil
    }
}

private final class SessionLocalStorage: LocalStorageProtocol {
    private let session: AuthTokenDTO

    init(session: AuthTokenDTO) {
        self.session = session
    }

    func save<T>(_ value: T, forKey key: String) throws where T: Codable {}

    func load<T>(forKey key: String) throws -> T? where T: Codable {
        session as? T
    }

    func remove(forKey key: String) throws {}

}

private final class EmptyLocalStorage: LocalStorageProtocol {
    func save<T>(_ value: T, forKey key: String) throws where T: Codable {}
    func load<T>(forKey key: String) throws -> T? where T: Codable { nil }
    func remove(forKey key: String) throws {}
}

private struct EmptySignUpUseCase: SignUpUseCaseProtocol {
    func execute(name: String, email: String, password: String) async throws -> AuthToken { throw CancellationError() }
}

private struct EmptySignInUseCase: SignInUseCaseProtocol {
    func execute(email: String, password: String) async throws -> AuthToken { throw CancellationError() }
}

private struct EmptySignOutUseCase: SignOutUseCaseProtocol {
    func execute() throws {}
}

private struct FailingSignOutUseCase: SignOutUseCaseProtocol {
    func execute() throws { throw AuthError.sessionRemovalFailed }
}

private struct EmptyRefreshTokenUseCase: RefreshTokenUseCaseProtocol {
    func execute(refreshToken: String) async throws -> AuthToken { throw CancellationError() }
}

private actor BlockingRefreshTokenUseCase: RefreshTokenUseCaseProtocol {
    private var continuations: [CheckedContinuation<AuthToken, Error>] = []
    private var started = false
    private var count = 0
    private var cancelled = false

    func execute(refreshToken: String) async throws -> AuthToken {
        started = true
        count += 1
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                continuations.append(continuation)
            }
        } onCancel: {
            Task { await self.recordCancellation() }
        }
    }

    func hasStarted() -> Bool {
        started
    }

    func startCount() -> Int {
        count
    }

    func wasCancelled() -> Bool {
        cancelled
    }

    private func recordCancellation() {
        cancelled = true
    }

    func fail() {
        let pendingContinuations = continuations
        continuations.removeAll()
        pendingContinuations.forEach { $0.resume(throwing: CancellationError()) }
    }

    func succeed(with token: AuthToken) {
        let pendingContinuations = continuations
        continuations.removeAll()
        pendingContinuations.forEach { $0.resume(returning: token) }
    }
}

private final class EmptyWorkspaceRepository: WorkspaceRepositoryProtocol {
    func createWorkspace(name: String, objective: String) async throws -> Workspace { throw CancellationError() }
    func updateWorkspace(id: String, name: String, objective: String) async throws -> Workspace { throw CancellationError() }
    func deleteWorkspace(id: String) async throws {}
        func fetchWorkspaces(query: WorkspaceListQuery) async throws -> WorkspaceListResult {
        WorkspaceListResult(workspaces: [], pagination: nil)
    }
}

private struct EmptyUploadSourceUseCase: UploadSourceUseCaseProtocol {
    func uploadFile(spaceId: String, fileURL: URL, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func uploadWeb(spaceId: String, url: String, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func uploadManual(spaceId: String, content: String, title: String?, author: String?) async throws -> Source { throw CancellationError() }
    func deleteSource(id: String) async throws {}
    func retrySource(id: String) async throws -> Source { throw CancellationError() }
    func sourceStatusStream() -> AsyncThrowingStream<SourceStatusEvent, Error> { AsyncThrowingStream { $0.finish() } }
}

private struct EmptyFetchSourcesUseCase: FetchSourcesUseCaseProtocol {
    func execute(query: SourceListQuery) async throws -> SourceListResult { throw CancellationError() }
}

private struct EmptyUpdateSourceUseCase: UpdateSourceUseCaseProtocol {
    func execute(id: String, title: String, author: String) async throws -> Source { throw CancellationError() }
}

private struct EmptyFetchSourceDetailUseCase: FetchSourceDetailUseCaseProtocol {
    func execute(id: String) async throws -> Source { throw CancellationError() }
}

private struct EmptyFetchSourcePreviewUseCase: FetchSourcePreviewUseCaseProtocol {
    func execute(source: Source) async throws -> SourcePreview { throw CancellationError() }
}
