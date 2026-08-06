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

    func testVisibleSourcesReturnsOnlySourcesInSelectedWorkspace() {
        let viewModel = makeViewModel()

        let sources = viewModel.visibleSources(inWorkspaceID: "dissertation-research")

        XCTAssertFalse(sources.isEmpty)
        XCTAssertTrue(sources.allSatisfy { $0.workspaceID == "dissertation-research" })
    }

    private func makeViewModel(
        fetchMeUseCase: any FetchMeUseCaseProtocol = EmptyFetchMeUseCase(),
        localStorage: LocalStorageProtocol = EmptyLocalStorage()
    ) -> MainViewModel {
        MainViewModel(
            fetchUsersUseCase: EmptyFetchUsersUseCase(),
            fetchMeUseCase: fetchMeUseCase,
            localStorage: localStorage,
            signUpUseCase: EmptySignUpUseCase(),
            signInUseCase: EmptySignInUseCase(),
            signOutUseCase: EmptySignOutUseCase(),
            refreshTokenUseCase: EmptyRefreshTokenUseCase(),
            workspaceRepository: EmptyWorkspaceRepository(),
            uploadSourceUseCase: EmptyUploadSourceUseCase(),
            fetchSourcesUseCase: EmptyFetchSourcesUseCase(),
            updateSourceUseCase: EmptyUpdateSourceUseCase(),
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

    func remove(forKey key: String) {}

    func clear() {}
}

private final class EmptyLocalStorage: LocalStorageProtocol {
    func save<T>(_ value: T, forKey key: String) throws where T: Codable {}
    func load<T>(forKey key: String) throws -> T? where T: Codable { nil }
    func remove(forKey key: String) {}
    func clear() {}
}

private struct EmptySignUpUseCase: SignUpUseCaseProtocol {
    func execute(name: String, email: String, password: String) async throws -> AuthToken { throw CancellationError() }
}

private struct EmptySignInUseCase: SignInUseCaseProtocol {
    func execute(email: String, password: String) async throws -> AuthToken { throw CancellationError() }
}

private struct EmptySignOutUseCase: SignOutUseCaseProtocol {
    func execute() {}
}

private struct EmptyRefreshTokenUseCase: RefreshTokenUseCaseProtocol {
    func execute(refreshToken: String) async throws -> AuthToken { throw CancellationError() }
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
