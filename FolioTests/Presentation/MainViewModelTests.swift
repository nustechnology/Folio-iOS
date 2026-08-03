import XCTest
@testable import Folio

@MainActor
final class MainViewModelTests: XCTestCase {
    func testVisibleSourcesReturnsOnlySourcesInSelectedWorkspace() {
        let viewModel = makeViewModel()

        let sources = viewModel.visibleSources(inWorkspaceID: "dissertation-research")

        XCTAssertFalse(sources.isEmpty)
        XCTAssertTrue(sources.allSatisfy { $0.workspaceID == "dissertation-research" })
    }

    private func makeViewModel() -> MainViewModel {
        MainViewModel(
            fetchUsersUseCase: EmptyFetchUsersUseCase(),
            localStorage: EmptyLocalStorage(),
            signUpUseCase: EmptySignUpUseCase(),
            signInUseCase: EmptySignInUseCase(),
            signOutUseCase: EmptySignOutUseCase(),
            refreshTokenUseCase: EmptyRefreshTokenUseCase(),
            workspaceRepository: EmptyWorkspaceRepository()
        )
    }
}

private struct EmptyFetchUsersUseCase: FetchUsersUseCaseProtocol {
    func execute() async throws -> [User] { [] }
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
    func fetchWorkspaces() async throws -> [Workspace] { [] }
    func createWorkspace(name: String, objective: String) async throws -> Workspace { throw CancellationError() }
    func updateWorkspace(id: String, name: String, objective: String) async throws -> Workspace { throw CancellationError() }
    func deleteWorkspace(id: String) async throws {}
}
